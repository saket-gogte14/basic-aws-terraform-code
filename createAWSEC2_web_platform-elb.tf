###################################################################################
# VARIABLES
####################################################################################

variable "aws_access_key" {
  sensitive = true
}

variable "aws_secret_key" {
    sensitive = true
}

variable "key_name" {}

variable "private_key_path" {}

variable "region" {
    default ="us-west-2"
}

variable "number_of_hosts_elb" {
  type = number
  validation {
    condition = var.number_of_hosts_elb < 3
    error_message = "This argument requires a number below 3 ...."
  } 
}

variable "network-address-space" {}

variable "subnet-address-space" {}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
    region      =var.region
    access_key  =var.aws_access_key
    secret_key  =var.aws_secret_key
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available"{}

data "aws_ami" "find_ami" {
    most_recent         =true
    owners              =["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
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

##################################################################################
# Resources
##################################################################################

# Networking 
##################################################################################
resource  "aws_vpc" "vpc" {
  cidr_block = var.network-address-space
  enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet" {
  count = var.number_of_hosts_elb
  cidr_block  = var.subnet-address-space[count.index]
  vpc_id = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

# Routing Table
##################################################################################
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta-subnet" {
  count = var.number_of_hosts_elb
  subnet_id   = aws_subnet.subnet[count.index].id
  route_table_id  = aws_route_table.rtb.id
}

# Security Groups
##################################################################################

resource "aws_security_group" "elb-sg" {
  name   = "nginx_elb_sg"
  vpc_id = aws_vpc.vpc.id

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"
  description = "Allow ports to open for nginx service to run"
  vpc_id = aws_vpc.vpc.id

  # SSH Access from Anywhere
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # http Access from Anywhere

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Elastic Load Balancer
##################################################################################

resource "aws_elb" "web_elb" {
  name = "nginx-elb"

  subnets = [for i in aws_subnet.subnet[*] : i.id]
  security_groups = [aws_security_group.elb-sg.id]
  instances = [ for i in aws_instance.web[*] : i.id]

 listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# Resources
##################################################################################

resource "aws_instance" "web" {
  count = var.number_of_hosts_elb
  ami      = data.aws_ami.find_ami.id
  instance_type = "t2.micro"
  key_name = var.key_name
  subnet_id = aws_subnet.subnet[count.index].id
  vpc_security_group_ids  = [aws_security_group.allow_ssh.id]

  connection {
    type  = "ssh"
    host  = self.public_ip
    user  = "ec2-user"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline =[
      "sudo yum -y install nginx",
      "sudo service nginx restart",
      "echo '<html><head><title>Web Host - $HOSTNAME </title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">This is the version running on $HOSTNAME </span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}


##################################################################################
# OUTPUT
##################################################################################


output "Private-IP-Address" {
  value = aws_instance.web[*].private_ip
  description = "The IP Address of the machine"
}

output "Public-IP-Address" {
  value = aws_instance.web[*].public_ip
  description = "The IP Address of the machine"
}

output "aws_instance_public_dns" {
  value = aws_instance.web[*].public_dns
}