#configure the AWS provider and the region to deploy resources in
provider "aws" {
  region = var.aws_region
  #region = "${var.aws_region}"
}


#retrieve the list of AZs in the specified AWS region

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# Create a VPC in the specified AWS region
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = var.vpc_name
    Environment = "demo_environment"
    Terraform   = "true"
  }

}

# Create private subnets in the VPC.

resource "aws_subnet" "private_subnets" {
  for_each = var.private_subnets
  vpc_id   = aws_vpc.vpc.id
  #cidr_block = "10.0.${each.value}.0/24"
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  #availability_zone = data.aws_availability_zones.available.names[each.value - 1]
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    #Name = "${each.key}"
    Name        = each.key
    Environment = "demo_environment"
    Terraform   = "true"
  }

}

# Create public subnets in the VPC.

resource "aws_subnet" "public_subnets" {
  for_each = var.public_subnets
  vpc_id   = aws_vpc.vpc.id
  #cidr_block = "10.0.${each.value}.0/24"
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value + 200)
  #availability_zone = data.aws_availability_zones.available.names[each.value - 1]
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    #Name = "${each.key}"
    Name        = each.key
    Environment = "demo_environment"
    Terraform   = "true"
  }

}

#create route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route  {
    cidr_block = "0.0.0.0/0"
    #gateway_id=aws_internal_gateway.internet_gateway.id
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name        = "private_route_table"
    Environment = "demo_environment"
    Terraform   = "true"
  }
}

#create route table for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route  {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name        = "public_route_table"
    Environment = "demo_environment"
    Terraform   = "true"
  }

}

#Create route table association for private subnets
resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}

#Create route table association for public subnets
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create an internet gateway for the VPC
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "idemo_igw"
    Environment = "demo_environment"
    Terraform   = "true"
  }
}

#create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  depends_on = [ aws_internet_gateway.internet_gateway ]
  tags = {
    Name = "demo_igw_eip"
    Environment = "demo_environment"
    Terraform = "true"
  }
  
}

#create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id = aws_subnet.public_subnets["public_subnet_1"].id
  depends_on = [ aws_subnet.public_subnets ]
  
  tags = {
    Name = "demo_nat_gateway"
    Environment = "demo_environment"
    Terraform = "true"
  }
  
}
/* */