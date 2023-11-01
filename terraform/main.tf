terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_vpc" "vpc_a" {
  cidr_block = "10.100.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "VPC-A"
  }
}

resource "aws_internet_gateway" "vpc_a_igw" {
  vpc_id = aws_vpc.vpc_a.id
  tags = {
    Name = "VPC-A-IGW"
  }
}

resource "aws_subnet" "vpc_a_subnet_public" {
  vpc_id = aws_vpc.vpc_a.id
  cidr_block = "10.100.0.0/24"
  tags = {
    Name = "VPC-A-Subnet-Public"
  }
}

resource "aws_route_table" "vpc_a_rt_public" {
  vpc_id = aws_vpc.vpc_a.id
  tags = {
    "Name" = "VPC-A-RT-Public"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_a_igw.id
  }
}

resource "aws_route_table_association" "vpc_a_subnet_public_association" {
  subnet_id      = aws_subnet.vpc_a_subnet_public.id
  route_table_id = aws_route_table.vpc_a_rt_public.id
}

resource "aws_subnet" "vpc_a_subnet_private" {
  vpc_id = aws_vpc.vpc_a.id
  cidr_block = "10.100.1.0/24"
  tags = {
    Name = "VPC-A-Subnet-Private"
  }
}

resource "aws_route_table" "vpc_a_rt_private" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = aws_vpc.vpc_b.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
  }

  tags = {
    "Name" = "VPC-A-RT-Private"
  }
}

resource "aws_route_table_association" "vpc_a_subnet_private_association" {
  subnet_id      = aws_subnet.vpc_a_subnet_private.id
  route_table_id = aws_route_table.vpc_a_rt_private.id
}

resource "aws_vpc" "vpc_b" {
  cidr_block = "10.200.0.0/16"
  tags = {
    Name = "VPC-B"
  }
}

resource "aws_subnet" "vpc_b_subnet_private" {
  vpc_id = aws_vpc.vpc_b.id
  cidr_block = "10.200.1.0/24"
  tags = {
    Name = "VPC-B-Subnet-Private"
  }
}

resource "aws_route_table" "vpc_b_rt_private" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block = aws_vpc.vpc_a.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
  }

  tags = {
    "Name" = "VPC-B-RT-Private"
  }
}

resource "aws_route_table_association" "vpc_b_subnet_private_association" {
  subnet_id      = aws_subnet.vpc_b_subnet_private.id
  route_table_id = aws_route_table.vpc_b_rt_private.id
}

resource "aws_instance" "vpc_a_ec2_public" {
  ami = "ami-0b0f138edf421d756"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.vpc_a_subnet_public.id
  key_name = "demo-app"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.vpc_a_sg_public.id]
  tags = {
    Name = "VPC-A-EC2-Public"
  }
}

resource "aws_security_group" "vpc_a_sg_public" {
  name = "VPC-A-SG-Public"
  description = "VPC-A-SG-Public"
  vpc_id = aws_vpc.vpc_a.id

	egress {
		from_port = 0
		to_port = 0
		protocol = -1
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	# ingress {
	# 	from_port = 80
	# 	to_port = 80
	# 	protocol = "tcp"
	# 	cidr_blocks = ["0.0.0.0/0"]
	# }

  tags = {
    Name = "VPC-A-SG-Public"
  }
}

resource "aws_instance" "vpc_a_ec2_private" {
  ami = "ami-0b0f138edf421d756"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.vpc_a_subnet_private.id
  key_name = "demo-app"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.vpc_a_sg_private.id]
  tags = {
    Name = "VPC-A-EC2-Private"
  }
}

resource "aws_security_group" "vpc_a_sg_private" {
  name = "VPC-A-SG-Private"
  description = "VPC-A-SG-Private"
  vpc_id = aws_vpc.vpc_a.id

  ingress {
    description = "Allow inbound traffic from Public Subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/24"]
  }

  tags = {
    Name = "VPC-A-SG-Private"
  }
}

resource "aws_instance" "vpc_b_ec2_private" {
  ami = "ami-0b0f138edf421d756"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.vpc_b_subnet_private.id
  key_name = "demo-app"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.vpc_b_sg_private.id]
  tags = {
    Name = "VPC-B-EC2-Private"
  }
}

resource "aws_security_group" "vpc_b_sg_private" {
  name = "VPC-B-SG-Private"
  description = "VPC-B-SG-Private"
  vpc_id = aws_vpc.vpc_b.id

  ingress {
    description = "Allow inbound traffic from Private Subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.100.1.0/24"]
  }

  tags = {
    Name = "VPC-B-SG-Private"
  }
}

resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true
}

# resource "aws_key_pair" "demo_app_key_pair" {
# 	key_name = "demo-app"
# 	public_key = file("demo-app.pub")
# }

output "instance_a_public_ip_addr" {
  value = aws_instance.vpc_a_ec2_public.public_ip
}

output "instance_a_private_ip_addr" {
  value = aws_instance.vpc_a_ec2_private.private_ip
}

output "instance_b_private_ip_addr" {
  value = aws_instance.vpc_b_ec2_private.private_ip
}
