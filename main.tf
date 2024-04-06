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

resource "aws_instance" "iit6" {
  ami           = var.ami
  instance_type = "t3.micro"
  key_name = aws_key_pair.key_pair.key_name

  # User data
  user_data = <<-EOF
  #!/bin/bash
  echo "This script was executed from user_data"
  EOF

  tags = {
    Name = "IIT_lab_6"
  }
}