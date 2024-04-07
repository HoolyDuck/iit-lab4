terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
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

provider "aws" {
  region = "eu-north-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_security_group" "http_server" {
  name = "http_server"
  vpc_id = "vpc-0cb5090078bee29d7"
}

resource "aws_vpc_security_group_ingress_rule" "http_server_http_rule" {
  security_group_id = aws_security_group.http_server.id
  cidr_ipv4 = "0.0.0.0/0"
  # from_port = 80
  # to_port = 80
  ip_protocol = "-1"
}

# resource "aws_vpc_security_group_ingress_rule" "http_server_ssh_rule" {
#     security_group_id = aws_security_group.http_server.id
#   cidr_ipv4 = "0.0.0.0/0"
#   from_port = 22
#   to_port = 22
#   ip_protocol = "tcp"
# }

resource "aws_vpc_security_group_egress_rule" "http_server_outer_rule" {
  security_group_id = aws_security_group.http_server.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_instance" "iit6" {
  ami           = var.ami
  instance_type = "t3.micro"
  key_name = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [
    aws_security_group.http_server.id,
  ]

  # User data
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y docker.io
              docker run -d -p 80:80 danyloberk/lab45
              docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --interval 20 --cleanup
              EOF

  tags = {
    Name = "IIT_lab_6"
  }
}

output "public_ip" {
  value = aws_instance.iit6.public_ip
}