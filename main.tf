provider "aws" {
  region = "ap-south-1" # Replace with your desired AWS region
  profile = "dev"
}


# Use the private key created previously
resource "aws_key_pair" "terraform_keypair" {
  key_name   = "terraform"
  public_key = file("/.ssh/terraform.pub") # Replace with the path to your public key file
}


# Step-1: Creating the VPC 
resource "aws_vpc" "production" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}


# Step-2: Creating the internet gateway
resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.production.id
  tags = {
    Name = "production-vpc-gw"
  }
}


# Step-3: Creating the custom route table to router our server traffic to the internet.
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.production.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  tags = {
    Name = "prod-route"
  }
}

variable "subnet_prefix" {
  description = "CIDR block for the subnet"
  # default =  "10.0.1.0/24"
  # type = string
}


# Step-4: Create a subnet
resource "aws_subnet" "prod-subnet-1" {
    vpc_id = aws_vpc.production.id
    cidr_block = var.subnet_prefix[0].cidr_block
    availability_zone = "ap-south-1a"
    tags = {
        Name = var.subnet_prefix[0].name
    }  
}

resource "aws_subnet" "dev-subnet-1" {
    vpc_id = aws_vpc.production.id
    cidr_block = var.subnet_prefix[1].cidr_block
    availability_zone = "ap-south-1a"
    tags = {
        Name = var.subnet_prefix[1].name
    }  
}


# Step-5: Associate a subnet to the Route Table
resource "aws_route_table_association" "prod-route-association" {
  subnet_id = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}


# Step-6: Create a Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.production.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


# Step-7: Create a Network Interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.prod-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}


# Step-8: Assignt an Elastic IP
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.prod-gw]
}


# Step-9: Create Ubuntu Server
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}


resource "aws_instance" "web-server-instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name = "terraform"
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y

                sudo systemctl start apache2
                sudo bash -c 'echo "My first web server" > /var/www/html/server.html'
                EOF

  tags = {
    Name = "Web Server"
  }  
}

output "webserver_public_ip" {
  value = aws_eip.one.public_ip
}

output "webserver_private_ip" {
    value= aws_instance.web-server-instance.private_ip  
}