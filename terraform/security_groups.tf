resource "aws_security_group" "gsr_ec2_sg" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Project GSR EC2 Security Group — SSH, HTTP, HTTPS"
  vpc_id      = data.aws_vpc.default.id

  # SSH — restricted to your IP only
  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP — allow all (Nginx redirects to HTTPS)
  ingress {
    description = "HTTP — redirects to HTTPS via Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — allow all (Flutter app + browser)
  ingress {
    description = "HTTPS — Flutter app and browser traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic allowed
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  }
}
