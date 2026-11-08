data "aws_vpc" "work" {
  filter {
    name   = "tag:Name"
    values = ["Work VPC"]
  }
}

data "aws_subnets" "work" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.work.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}