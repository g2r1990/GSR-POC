# Look up the latest Ubuntu 22.04 LTS AMI (Canonical official)
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
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
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.gsr_ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.gsr_ec2_profile.name

  root_block_device {
    volume_size           = var.ebs_volume_size
    volume_type           = "gp3"
    encrypted             = true   # EBS encryption at rest
    delete_on_termination = true
  }

  # Bootstrap script — runs once on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/gsr-bootstrap.log 2>&1

    echo "=== GSR Bootstrap started at $(date) ==="

    # Prevent apt-get from hanging on interactive prompts
    export DEBIAN_FRONTEND=noninteractive

    # System update
    apt-get update -y
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

    # Install Docker (official script)
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose plugin
    apt-get install -y docker-compose-plugin

    # Install Nginx
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Install Certbot for Let's Encrypt SSL
    apt-get install -y certbot python3-certbot-nginx

    # Install useful tools
    apt-get install -y htop curl wget git unzip postgresql-client

    # Create application directory
    mkdir -p /opt/project-gsr
    chown ubuntu:ubuntu /opt/project-gsr

    # Default Nginx config — proxies port 80 to FastAPI on 8000
    cat > /etc/nginx/sites-available/gsr-api << 'NGINXEOF'
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

    ln -sf /etc/nginx/sites-available/gsr-api /etc/nginx/sites-enabled/gsr-api
    rm -f /etc/nginx/sites-enabled/default
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

  # Ensure instance is running before EIP association
  depends_on = [aws_instance.gsr_server]
}
