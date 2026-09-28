variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair (must already exist in the AWS account)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "project-gsr"
}

variable "environment" {
  description = "Environment name (qad-lab-test | poc | staging | prod)"
  type        = string
  default     = "poc"
}

variable "allowed_ssh_cidr" {
  description = "Your public IP in CIDR format for SSH access — e.g. 1.2.3.4/32"
  type        = string
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "s3_bucket_suffix" {
  description = "Unique suffix for the S3 bucket name (use account ID or random string)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy resources into"
  type        = string
}
