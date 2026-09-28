output "ec2_public_ip" {
  description = "Elastic IP of the EC2 server — point your domain A record here"
  value       = aws_eip.gsr_eip.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.gsr_server.id
}

output "ec2_ami_used" {
  description = "Ubuntu AMI ID used for this deployment"
  value       = data.aws_ami.ubuntu_22_04.id
}

output "s3_bucket_name" {
  description = "S3 bucket name — set this in FastAPI .env as S3_BUCKET_NAME"
  value       = aws_s3_bucket.gsr_storage.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.gsr_storage.arn
}

output "ec2_iam_role_arn" {
  description = "IAM role ARN attached to EC2"
  value       = aws_iam_role.gsr_ec2_role.arn
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i your-key.pem ubuntu@${aws_eip.gsr_eip.public_ip}"
}

output "api_base_url_http" {
  description = "API base URL (HTTP — before SSL setup)"
  value       = "http://${aws_eip.gsr_eip.public_ip}"
}
