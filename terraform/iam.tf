# IAM Role — allows EC2 to assume this role
resource "aws_iam_role" "gsr_ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# IAM Policy — EC2 can read/write its own S3 bucket only
resource "aws_iam_role_policy" "gsr_s3_policy" {
  name = "${var.project_name}-${var.environment}-s3-access"
  role = aws_iam_role.gsr_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${aws_s3_bucket.gsr_storage.arn}/*"
      },
      {
        Sid    = "AllowS3ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.gsr_storage.arn
      }
    ]
  })
}

# Instance Profile — attaches the IAM role to the EC2 instance
resource "aws_iam_instance_profile" "gsr_ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.gsr_ec2_role.name
}
