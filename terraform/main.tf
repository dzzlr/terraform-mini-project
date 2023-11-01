terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket = "mycomponents-tfstate"
  #   key = "state/terraform.tfstate"
  #   region = "ap-southeast-1"
  #   encrypt = true
  #   dynamodb_table = "mycomponents_tf_lockid"
  # }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_vpc" "landing_zone_vpc" {
  cidr_block = "10.100.0.0/16"
  tags = {
    Name = "landing-zone-vpc"
  }
}

resource "aws_subnet" "landing_zone_private_subnet" {
  vpc_id = aws_vpc.landing_zone_vpc.id
  cidr_block = "10.100.1.0/24"
  tags = {
    Name = "landing-zone-private-subnet"
  }
}

resource "aws_route_table" "landing_zone_private_subnet" {
  vpc_id = aws_vpc.landing_zone_vpc.id
  tags = {
    "Name" = "landing-zone-private-rt"
  }
}

resource "aws_route_table_association" "landing_zone_private_subnet_association" {
  subnet_id      = aws_subnet.landing_zone_private_subnet.id
  route_table_id = aws_route_table.landing_zone_private_subnet.id
}

resource "aws_route" "landing_zone_tgw_route" {
  route_table_id         = aws_route_table.landing_zone_private_subnet.id
  destination_cidr_block = "10.200.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.vpc_tgw.id
  depends_on = [
    aws_ec2_transit_gateway.vpc_tgw
  ]
}


resource "aws_vpc" "application_vpc" {
  cidr_block = "10.200.0.0/16"
  tags = {
    Name = "application-vpc"
  }
}

resource "aws_subnet" "application_private_subnet" {
  vpc_id = aws_vpc.application_vpc.id
  cidr_block = "10.200.1.0/24"
  tags = {
    Name = "application-private-subnet"
  }
}

resource "aws_route_table" "application_private_subnet" {
  vpc_id = aws_vpc.application_vpc.id
  tags = {
    "Name" = "application-private-rt"
  }
}

resource "aws_route_table_association" "application_private_subnet_association" {
  subnet_id      = aws_subnet.application_private_subnet.id
  route_table_id = aws_route_table.application_private_subnet.id
}

resource "aws_route" "application_tgw_route" {
  route_table_id         = aws_route_table.application_private_subnet.id
  destination_cidr_block = "10.100.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.vpc_tgw.id
  depends_on = [
    aws_ec2_transit_gateway.vpc_tgw
  ]
}


# Create tgw in AWS Network Account 
resource "aws_ec2_transit_gateway" "vpc_tgw" {
  description                     = "Transit Gateway testing scenario with 2 VPCs, subnets each"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = {
    Name        = "vpc-tgw"
  }
}

# Attachement of Landing Zone VPC from AWS production Account
resource "aws_ec2_transit_gateway_vpc_attachment" "landing_zone_vpc_attachment" {
  subnet_ids         = [aws_subnet.landing_zone_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.vpc_tgw.id
  vpc_id             = aws_vpc.landing_zone_vpc.id
  tags = {
    "Name" = "landing-zone-transit-gateway-attachment"
  }
}

# Attachement of Application VPC from AWS production Account
resource "aws_ec2_transit_gateway_vpc_attachment" "application_vpc_attachment" {
  subnet_ids         = [aws_subnet.application_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.vpc_tgw.id
  vpc_id             = aws_vpc.application_vpc.id
  tags = {
    "Name" = "application-transit-gateway-attachment"
  }
}


data "template_file" "startup" {
 template = file("ssm-agent-install.sh")
}

resource "aws_instance" "landing_zone_instance" {
  ami = "ami-0b0f138edf421d756"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.landing_zone_private_subnet.id
  # key_name = "dicoding-demo"
  iam_instance_profile = aws_iam_instance_profile.dev_resources_iam_profile.name
  user_data = data.template_file.startup.rendered

  tags = {
    Name = "landing-zone-instance"
  }
}

resource "aws_instance" "application_instance" {
  ami           = "ami-0b0f138edf421d756"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.application_private_subnet.id
  # key_name = "dicoding-demo"

  tags = {
    Name = "application-instance"
  }
}

resource "aws_iam_instance_profile" "dev_resources_iam_profile" {
  name = "ec2_profile"
  role = aws_iam_role.dev_resources_iam_role.name
}

resource "aws_iam_role" "dev_resources_iam_role" {
  name        = "dev-ssm-role"
  description = "The role for the developer resources EC2"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": {
"Effect": "Allow",
"Principal": {"Service": "ec2.amazonaws.com"},
"Action": "sts:AssumeRole"
}
}
EOF
  tags = {
    stack = "test"
  }
}

resource "aws_iam_role_policy_attachment" "dev-resources-ssm-policy" {
  role       = aws_iam_role.dev_resources_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_ssm_parameter" "username" {
  name = var.username_parameter_name
}

data "aws_ssm_parameter" "password" {
  name = var.password_parameter_name
}

resource "aws_rds_cluster" "database" {
  cluster_identifier = "example"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "13.6"
  database_name      = "test"
  master_username    = data.aws_ssm_parameter.username
  master_password    = data.aws_ssm_parameter.password

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }
}

resource "aws_rds_cluster_instance" "db_instance" {
  cluster_identifier = aws_rds_cluster.database.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.database.engine
  engine_version     = aws_rds_cluster.database.engine_version
}

# Create an ECR repository
resource "aws_ecr_repository" "my_ecr_repo" {
  name = "my-ecr-repo"
}

# Create an EKS cluster with Fargate profile
module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  cluster_name       = "my-eks-cluster"
  subnets            = [aws_subnet.application_private_subnet.id]
  vpc_id             = aws_vpc.application_vpc.id
  worker_groups_launch_template = {
    instance_type   = "fargate"
    asg_desired_capacity = 1
  }
}

# Create a security group for the ALB
resource "aws_security_group" "my_alb_sg" {
  vpc_id = aws_vpc.application_vpc.id
  // Add any necessary security group rules
}

# Create an ALB
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_alb_sg.id]
  subnets            = [aws_subnet.application_private_subnet.id]
}

# Create a target group for Fargate tasks
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.application_vpc.id
}

# Create a listener for the ALB
resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "OK"
    }
  }
}

# Create a Fargate service
resource "aws_ecs_service" "my_fargate_service" {
  name            = "my-fargate-service"
  cluster         = module.eks.cluster_id
  task_definition = "<TASK_DEFINITION_ARN>" # Replace with your actual task definition ARN

  desired_count = 1

  network_configuration {
    subnets = [aws_subnet.application_private_subnet.id]

    security_groups = [
      aws_security_group.my_alb_sg.id,
      module.eks.default_security_group_id,
    ]
  }

  depends_on = [aws_ecs_task_definition.my_task_definition]
}

# Create an IAM role for the Fargate tasks to access ECR
resource "aws_iam_role" "my_fargate_task_role" {
  name = "my-fargate-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach a policy that allows access to ECR
resource "aws_iam_policy_attachment" "my_ecr_access_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  roles      = [aws_iam_role.my_fargate_task_role.name]
}

# Create a task definition for Fargate
resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.my_fargate_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-container"
      image     = "${aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/my-ecr-repo:latest" # Replace with your actual ECR repository URI
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# Output the ALB DNS name
output "alb_dns_name" {
  value = aws_lb.my_alb.dns_name
}