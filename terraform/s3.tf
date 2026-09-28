resource "aws_s3_bucket" "gsr_storage" {
  bucket = "${var.project_name}-${var.environment}-storage-${var.s3_bucket_suffix}"

  tags = {
    Name = "${var.project_name}-${var.environment}-storage"
  }
}

# Enable versioning — protects against accidental overwrites
resource "aws_s3_bucket_versioning" "gsr_storage_versioning" {
  bucket = aws_s3_bucket.gsr_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption (AES-256) — all objects encrypted at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "gsr_storage_enc" {
  bucket = aws_s3_bucket.gsr_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access — objects accessible only via EC2 IAM role
resource "aws_s3_bucket_public_access_block" "gsr_storage_block" {
  bucket = aws_s3_bucket.gsr_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule — delete incomplete multipart uploads after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "gsr_storage_lifecycle" {
  bucket = aws_s3_bucket.gsr_storage.id

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {}
  }
}
