# Use the default VPC that AWS creates automatically in every account
data "aws_vpc" "default" {
  default = true
}

# Get all default subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}
