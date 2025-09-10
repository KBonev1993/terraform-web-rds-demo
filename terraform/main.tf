provider "aws" {
  region = "eu-north-1"
}

# Data source за последната Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group за Web Server
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

# Security Group за RDS
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL access from web server"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web Server EC2
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = "key_pair_10.09.2025"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "WebServer"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform Web Server!</h1>" > /var/www/html/index.html
              EOF
}

# RDS MySQL
resource "aws_db_instance" "db" {
  allocated_storage     = 20
  engine                = "mysql"
  engine_version        = "8.0.42"
  instance_class        = "db.t3.micro"
  username              = "admin"
  password              = "SuperSecret123!"
  db_name               = "mydb"
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot   = true
}

# Load Balancer
resource "aws_elb" "web_lb" {
  name               = "web-lb"
  availability_zones = ["eu-north-1a"]
  security_groups    = [aws_security_group.web_sg.id]
  instances          = [aws_instance.web.id]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }
}

# Outputs
output "web_ip" {
  value = aws_instance.web.public_ip
}

output "elb_dns" {
  value = aws_elb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.endpoint
}
