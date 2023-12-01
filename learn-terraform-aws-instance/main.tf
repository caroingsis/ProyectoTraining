terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "prueba-caro" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "caro"
  }
}

resource "aws_subnet" "caro_a" {
  vpc_id                  = aws_vpc.prueba-caro.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "caro-a"
  }
}

resource "aws_subnet" "caro_b" {
  vpc_id                  = aws_vpc.prueba-caro.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b" # Cambia la zona de disponibilidad si es necesario
  map_public_ip_on_launch = true

  tags = {
    Name = "caro-b"
  }
}

resource "aws_route_table" "caro_rt" {
  vpc_id = aws_vpc.prueba-caro.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.caro-gw.id
  }

  tags = {
    Name = "caro-rt"
  }
}

resource "aws_main_route_table_association" "caro_rta" {
  vpc_id         = aws_vpc.prueba-caro.id
  route_table_id = aws_route_table.caro_rt.id
}

resource "aws_lb" "caro-lb" {
  name               = "caro-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.caro-sg.id]
  subnets            = [aws_subnet.caro_a.id, aws_subnet.caro_b.id]
}

resource "aws_internet_gateway" "caro-gw" {
  vpc_id = aws_vpc.prueba-caro.id

  tags = {
    Name = "caro-gw"
  }
}

resource "aws_security_group" "caro-sg" {
  name        = "caro-sg"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.prueba-caro.id

  tags = {
    Name = "caro-sg"
  }
}

resource "aws_ecs_cluster" "caro_cluster" {
  name = "caro-cluster"
}

resource "aws_ecs_task_definition" "caro_task_definition" {
  family                   = "caro-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE", "EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true

      portMappings = [{
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "caro_service" {
  name             = "caro-service"
  cluster          = aws_ecs_cluster.caro_cluster.id
  task_definition  = aws_ecs_task_definition.caro_task_definition.arn
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.caro-sg.id]
    subnets          = [aws_subnet.caro_a.id, aws_subnet.caro_b.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.caro_target_group.arn
    container_name   = "nginx"
    container_port   = 80
  }

}

resource "aws_lb_target_group" "caro_target_group" {
  name        = "caro-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.prueba-caro.id
  target_type = "ip"

}

resource "aws_lb_listener" "caro_listener" {
  load_balancer_arn = aws_lb.caro-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.caro_target_group.arn
  }
}