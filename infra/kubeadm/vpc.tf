resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s-lab-vpc"
  }
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-lab-igw"
  }
}

resource "aws_subnet" "k8s_public_subnet_a" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "k8s-lab-public-subnet-a"
  }
}

resource "aws_subnet" "k8s_public_subnet_b" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name = "k8s-lab-public-subnet-b"
  }
}

resource "aws_route_table" "k8s_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }
}

resource "aws_route_table_association" "k8s_rta_a" {
  subnet_id      = aws_subnet.k8s_public_subnet_a.id
  route_table_id = aws_route_table.k8s_rt.id
}

resource "aws_route_table_association" "k8s_rta_b" {
  subnet_id      = aws_subnet.k8s_public_subnet_b.id
  route_table_id = aws_route_table.k8s_rt.id
}