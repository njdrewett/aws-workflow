
#Basic Linux EC2 instance running a busybox basic html page exposed
#Replaced with aws launch configuration and auto-scaling group
# resource "aws_instance" "linux" {
#   ami                    = "ami-0aaa5410833273cfe"
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.instance.id]

#   user_data                   = <<-EOF
#   #!/bin/bash
#   echo "Hello World" > index.html
#   nohup busybox httpd -f -p ${var.server_port} &
#   EOF
#   user_data_replace_on_change = true

#   tags = {
#     Name = "aws-linux"
#   }
# }


resource "aws_launch_configuration" "linux_launch_config" {
  image_id        = "ami-0aaa5410833273cfe"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data                   = <<EOF
  #!/bin/bash
  echo "Hello World" > index.html
  nohup busybox httpd -f -p ${var.server_port} &
  EOF

  #Required when using asg due to dependency
  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "linux_asg" {
  launch_configuration = aws_launch_configuration.linux_launch_config.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg_tg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 5

  tag {
    key                 = "Name"
    value               = "Linux ASG"
    propagate_at_launch = true
  }
}

resource "aws_lb_listener_rule" "asg_lr" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_tg.arn
  }
}

# used to lookup subnets and ips
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_lb" "linux_lb" {
  name               = "aws-linux-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.linux_lb.arn
  port              = 80
  protocol          = "HTTP"

  # By default return a simple error 404
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb_sg" {
  name = "linux_alb_sg"

  # Allow inbound http requests
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

resource "aws_lb_target_group" "asg_tg" {
  name     = "linux-asg-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Security Group to allow access to the port 8080 of the above linux instance
resource "aws_security_group" "instance" {
  name = "linux-sg-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Required if trying to recreate SG otherwise can hang due to instance dependency
  lifecycle {
    create_before_destroy = true
  }
}

variable "server_port" {
  description = "The Port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

## Only viable if we deployed a single AWS EC2 instance
# output "public_ip" {
#   value       = aws_instance.linux.public_ip
#   description = "The public IP address of the web server"
# }

output "alb_dns_name" {
  value       = aws_lb.linux_lb.dns_name
  description = "The DNS Name of the Load Balancer"
}

output "server_port" {
  value = var.server_port
}
