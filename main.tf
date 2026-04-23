####################################################################
#              THIS IS FOR A VERSINING ON A S3 BUCKET              #
####################################################################

terraform {
  backend "s3" {
    bucket = "aws-terraform-state-123456"
    key    = "terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
    region = "ap-south-1"
}

resource "aws_route_table" "aws-route" {
    vpc_id = aws_vpc.aws-vpc.id
    tags = {
        Name = "aws-route-table"
    }  
}

resource "aws_route" "aws-route" {
    route_table_id = aws_route_table.aws-route.id
    gateway_id = aws_internet_gateway.aws-gateway.id
    destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "aws-association" {
    subnet_id = aws_subnet.aws-subnet.id
    route_table_id = aws_route_table.aws-route.id
}

resource "aws_internet_gateway" "aws-gateway" { 
    vpc_id = aws_vpc.aws-vpc.id

    tags = {
        Name = "aws-gate"
    }
}

resource "aws_vpc" "aws-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "aws-vpc"
    }
}

resource "aws_security_group" "aws-sg"{
    name = "aws-SG"
    vpc_id = aws_vpc.aws-vpc.id

    ingress  {
        description = "for SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress  {
        description = "http"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress  {
        description = "for out bound"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_subnet" "aws-subnet" {

    vpc_id = aws_vpc.aws-vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true  # This is usefull for a EC2 public ip connect 
    tags = {
        Name = "aws-subnet"
    }
}

resource "aws_subnet" "aws-subnet-2" {
    vpc_id = aws_vpc.aws-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1b"  # ✅ Different AZ
    map_public_ip_on_launch = true

    tags = {
        Name = "aws-subnet-2"
    }
}

resource "aws_instance" "aws-instance"{
    ami = "ami-048f4445314bcaa09"
    instance_type = "t3.micro"
    associate_public_ip_address = true
    key_name = "webserver"
    subnet_id = aws_subnet.aws-subnet.id
    vpc_security_group_ids = [aws_security_group.aws-sg.id]

    user_data = <<-EOF
		#!/bin/bash
		#update packages
		sudo yum update -y
	
		#install apache web server
		sudo yum install httpd -y
	
		#start apache server
		sudo systemctl start httpd

		#enable apache on boot
		sudo systemctl enable httpd

		#create simple webpage
		sudo echo "<h1>Terraform Web Server</h1>" >/var/www/html/index.html
	EOF

    tags = {
        Name = "aws-instance"
    }

}

resource "aws_db_subnet_group" "aws-db-subnet" {
  name = "aws-db-subnet"

  subnet_ids = [
    aws_subnet.aws-subnet.id,
    aws_subnet.aws-subnet-2.id
  ]
  tags = {
    Name = "aws-db-subnet-group"
  }
}

resource "aws_db_instance" "awsdb" {
    allocated_storage = 20
    instance_class = "db.t3.micro"
    db_name = "dbaws"
    engine = "mysql"
    username = "aws"
    password = "12345678"
    publicly_accessible = true
    skip_final_snapshot = true
    db_subnet_group_name = aws_db_subnet_group.aws-db-subnet.name
    vpc_security_group_ids = [aws_security_group.aws-sg.id]
}

resource "aws_s3_bucket" "aws-bucket" {
    bucket = "aws-bucket"
}

resource "aws_s3_object" "files" {
    key = "data.txt"
    bucket = aws_s3_bucket.aws-bucket.id
    source = "data.txt"
    etag = filemd5("data.txt")
}

#################################################
##             AWS S3 Versioning               ##
#################################################

resource "aws_s3_bucket" "tf_state" {
    bucket = "aws-terraform-state-12345"
    tags = {
        Name = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "aws-v"{
    bucket = aws_s3_bucket.tf_state.id
    versioning_configuration {
        status = "Enabled"
    }
}