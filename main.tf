# provider "aws" {
#     region = "us-east-1"
# }

#Create VPC 

resource "aws_vpc" "mProject_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = false
    tags = {
    Name = "mProject_vpc"
    }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.mProject_vpc.id
    tags = {
        Name = "igw"
        }
}

# Create Public Route table
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.mProject_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    "Name" = "rt-public"
  }
}

#Associate public-subnet 1 with public route-table
resource "aws_route_table_association" "public_subnet1_association" {
    subnet_id = aws_subnet.public_subnet1.id
    route_table_id = aws_route_table.rt-public.id
}

# Create Public subnet 1
resource "aws_subnet" "public_subnet1" {
    vpc_id = aws_vpc.mProject_vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1b"
    tags = {
      "Name" = "public_subnet1"
    }
}

# Create Public-subnet 2
resource "aws_subnet" "public_subnet2" {
    vpc_id = aws_vpc.mProject_vpc.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1c"
    tags = {
      "Name" = "public_subnet2"
    }
}

resource "aws_network_acl" "network_acl" {
    vpc_id = aws_vpc.mProject_vpc.id
    subnet_ids = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
    ingress {
        rule_no = 100
        protocol = "-1"
        action = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port = 0
    }

    egress {
        rule_no = 100
        protocol = "-1"
        action = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port = 0
    }
}

#Create security group for the load balancer
resource "aws_security_group" "load_balancer_sg" {
    name = "load_balancer_sg"
    description = "Security group for the load balancer"
    vpc_id = aws_vpc.mProject_vpc.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Create Security Group to allow port 22, 80 and 443
resource "aws_security_group" "security-grp-rule" {
    name = "allow_ssh_http_https"
    description = "Allow SSH, HTTP and HTTPS inbound traffic for private instances"
    vpc_id = aws_vpc.mProject_vpc.id

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        security_groups = [aws_security_group.load_balancer_sg.id]
    }

    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        security_groups = [aws_security_group.load_balancer_sg.id]
    }

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "security-grp-rule"
    }
}


# 3. CREATING INSTANCES

# creating instance 1
resource "aws_instance" "Project1" {
  ami = "ami-0778521d914d23bc1"
  instance_type = "t2.micro"
  key_name = "terraform"
  security_groups = [aws_security_group.security-grp-rule.id]
  subnet_id = aws_subnet.public_subnet1.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "Project-1"
    source = "terraform"
  }
}

# creating instance 2
 resource "aws_instance" "Project2" {
  ami = "ami-0778521d914d23bc1"
  instance_type = "t2.micro"
  key_name = "terraform"
  security_groups = [aws_security_group.security-grp-rule.id]
  subnet_id = aws_subnet.public_subnet2.id
  availability_zone = "us-east-1c"
  tags = {
    Name   = "Project-2"
    source = "terraform"
  }
}

# creating instance 3
resource "aws_instance" "Project3" {
  ami = "ami-0778521d914d23bc1"
  instance_type = "t2.micro"
  key_name = "terraform"
  security_groups = [aws_security_group.security-grp-rule.id]
  subnet_id = aws_subnet.public_subnet1.id
  availability_zone = "us-east-1b"
  tags = {
    Name   = "Project-3"
    source = "terraform"
  }
}

# Create a file to store the intance's IP address of the instances

resource "local_file" "IP_address" {
    filename = "/home/lade/Desktop/tf-project/host-inventory"
    content = <<EOT
${aws_instance.Project1.public_ip}
${aws_instance.Project2.public_ip}
${aws_instance.Project3.public_ip}
    EOT
}

# 4. CREATING AN APPLICATION LOAD BALANCER

resource "aws_lb" "load-balancer" {
    name = "load-balancer"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.load_balancer_sg.id]
    subnets = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
    #enable_cross_zone_load_balancing = true
    enable_deletion_protection = false
    depends_on = [aws_instance.Project2, aws_instance.Project2, aws_instance.Project3]
}

# Create the target group
resource "aws_lb_target_group" "target-group" {
    name = "target-group"
    target_type = "instance"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.mProject_vpc.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 4
        healthy_threshold = 4
        unhealthy_threshold = 4
    }
}

# Create the listener
resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.load-balancer.arn
    port = "80"
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.target-group.arn
    }
}

# Create the listener rule
resource "aws_lb_listener_rule" "listener-rule" {
    listener_arn = aws_lb_listener.listener.arn
    priority = 1
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.target-group.arn
    }
    condition {
        path_pattern {
        values = ["/"]
        }
    }
}

# Attach the target group to the load balancer
resource "aws_lb_target_group_attachment" "target-group-attachment1" {
    target_group_arn = aws_lb_target_group.target-group.arn
    target_id = aws_instance.Project1.id
    port = 80
}
 
resource "aws_lb_target_group_attachment" "target-group-attachment2" {
    target_group_arn = aws_lb_target_group.target-group.arn
    target_id = aws_instance.Project2.id
    port = 80
}
resource "aws_lb_target_group_attachment" "target-group-attachment3" {
    target_group_arn = aws_lb_target_group.target-group.arn
    target_id = aws_instance.Project3.id
    port = 80    
}