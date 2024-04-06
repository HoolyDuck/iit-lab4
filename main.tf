terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id
}

resource "aws_route" "prod__to_internet" {
  route_table_id = aws_vpc.prod.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.prod.id
}

resource "aws_subnet" "prod" {
  vpc_id = aws_vpc.prod.id
  availability_zone = "eu-north-1a"
  cidr_block = "10.0.0.0/18"
  map_public_ip_on_launch = true
  depends_on = [aws_internet_gateway.prod]
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

provider "aws" {
  region = "eu-north-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "tls_private_key" "rsa_4096-terraform" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

variable "key_name" {}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096-terraform.public_key_openssh
}

resource "local_file" "private_key" {
  content = tls_private_key.rsa_4096-terraform.private_key_pem
  filename = var.key_name
}

variable "ami" {
  type      = string
  sensitive = true
}

variable "docker_compose_content" {
    type = string
    default =  <<EOF
version: "3"
services:
  cavo:
    image: danyloberk/lab45
    ports:
      - "80:80"
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 20
EOF
}

resource "aws_security_group" "group" {
  name_prefix = "group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "iit6" {
  ami           = var.ami
  instance_type = "t3.micro"
  key_name = aws_key_pair.key_pair.key_name
    vpc_security_group_ids = [
    aws_security_group.group.id,
  ]
  subnet_id = aws_subnet.prod.id
  availability_zone = aws_subnet.prod.availability_zone

  # User data
  user_data = <<-EOF
              #!/bin/bash
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              sudo chown $USER /var/run/docker.sock
              cat > ./docker-compose.yml <<-TEMPLATE
              ${var.docker_compose_content}
              TEMPLATE
              docker compose up
              EOF

  tags = {
    Name = "IIT_lab_6"
  }
}