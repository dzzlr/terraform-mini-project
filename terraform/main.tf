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
