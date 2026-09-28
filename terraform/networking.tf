# Look up the VPC by ID provided in tfvars
data "aws_vpc" "default" {
  id = var.vpc_id
}

# Get all subnets in the specified VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
