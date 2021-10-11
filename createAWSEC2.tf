variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "region" {
    default ="us-west-2"
}

provider "aws" {
    region      =var.region
    access_key  =var.aws_access_key
    secret_key  =var.aws_secret_key
}

data "aws_ami" "find_ami" {
    most_recent         =true
    owners              =["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }      
}

resource "aws_instance" "web" {
  ami      = "${data.aws_ami.find_ami.id}"
  instance_type = "t3.micro"

  tags = {
    Name = "MyFirstInstance"
  }
}

output "Private-IP-Address" {
  value = aws_instance.web.private_ip
  description = "The IP Address of the machine"
}

output "Public-IP-Address" {
  value = aws_instance.web.public_ip
  description = "The IP Address of the machine"
}