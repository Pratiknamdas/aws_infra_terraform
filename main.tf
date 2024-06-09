# Creating VPC

resource "aws_vpc" "tf-vpc" {
  cidr_block = var.cidr
}
# Creating Public Subnet
resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

# Creating InternetGateway

resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-vpc.id
}

# Creating Route-table

resource "aws_route_table" "tf-rt" {
    vpc_id = aws_vpc.tf-vpc.id
    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.tf-igw.id
    }
  
}

#Associting the Route-table to Subnets

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.tf-rt.id
  
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.tf-rt.id
  
}

# Creating Security-Group For EC2 Instance With Inbound and Outbiund Rule

resource "aws_security_group" "web-sg" {
  name        = "web-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.tf-vpc.id
  ingress{
    description       = "HTTP from VPC"
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress{
    description       = "SSH from VPC" 
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  } 
  egress{ 
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Web-sg"
  }
}

# Creating S3 Bucket

resource "aws_s3_bucket" "tf-bucket" {
  bucket = "tf-bucket9837e3"
  tags = {
  Name        = "My bucket"
  Environment = "Dev"
  }  
}

#Rule for Ownership of Bucket

resource "aws_s3_bucket_ownership_controls" "own" {
  bucket = aws_s3_bucket.tf-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Public Acl

resource "aws_s3_bucket_public_access_block" "bloc" {
  bucket = aws_s3_bucket.tf-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#Creating rule for public bucket


resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.own,
    aws_s3_bucket_public_access_block.bloc,
  ]

  bucket = aws_s3_bucket.tf-bucket.id
  acl    = "public-read"
}

#creating EC2 instances

resource "aws_instance" "webserver1" {
  ami = "ami-09040d770ffe2224f"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("user.sh"))
  
}

resource "aws_instance" "webserver2" {
  ami = "ami-09040d770ffe2224f"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("user1.sh"))
  
}

# Creatig IAM ROLE & Policy

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role.id


  policy = "${file("ec2-policy.json")}"
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = "${file("ec2-assume-policy.json")}"
}

# Creating Instance profile 

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role  = "${aws_iam_role.ec2_role.id}"
}

#Creating LoadBalancers

resource "aws_lb" "webserver-lb" {
  name = "webserver-lb"
  
  internal = false
  load_balancer_type = "application"
  
  security_groups = [aws_security_group.web-sg.id]
  subnets = [aws_subnet.sub1.id,aws_subnet.sub2.id] 

  tags = {
    Name = "web"
  }
}

#Creating LoadBalancers Target Group

resource "aws_lb_target_group" "tg" {
  name = "tg"
  
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.tf-vpc.id
  
  health_check {
  
   path = "/"
    port = "traffic-port"
  
  }
  
}

#Creating LoadBalancers Group Attachments to EC2

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver1.id
  port = 80

  
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver2.id
  port = 80
  
  
}

# Creating  LoadBalancer Listener to connect attachment and target

resource "aws_lb_listener" "listener" {
  
  load_balancer_arn = aws_lb.webserver-lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type = "forward"

  }

}

output "loadbalncerdns" {

  value = aws_lb.webserver-lb.dns_name
  
}
