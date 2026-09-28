# Look up the latest Amazon Linux 2023 AMI (Amazon official)
data "aws_ami" "gsr_app_server_ami" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "gsr_server" {
  ami                    = data.aws_ami.gsr_app_server_ami.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.gsr_ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.gsr_ec2_profile.name

  root_block_device {
    volume_size           = var.ebs_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Bootstrap script — runs once on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/gsr-bootstrap.log 2>&1

    echo "=== GSR Bootstrap started at $(date) ==="

    # System update
    dnf update -y

    # Install Docker (available in AL2023 default repos)
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Docker Compose plugin
    dnf install -y docker-compose-plugin

    # Install Nginx
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Install Certbot for Let's Encrypt SSL
    dnf install -y python3-pip
    pip3 install certbot certbot-nginx

    # Install useful tools
    dnf install -y htop curl wget git unzip
    dnf install -y postgresql15

    # Create application directory
    mkdir -p /opt/project-gsr
    chown ec2-user:ec2-user /opt/project-gsr

    # Nginx config — AL2023 uses conf.d, not sites-available
    cat > /etc/nginx/conf.d/gsr-api.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 20M;

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
    }
}
NGINXEOF

    nginx -t && systemctl reload nginx

    echo "=== GSR Bootstrap complete at $(date) ==="
  EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-server"
  }
}

# Static Elastic IP — your EC2's permanent public IP
resource "aws_eip" "gsr_eip" {
  instance = aws_instance.gsr_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }

  depends_on = [aws_instance.gsr_server]
}
