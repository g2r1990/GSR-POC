# Project GSR — Phase 1 Runbook
**Last Updated:** 2026-10-01  
**Stack:** Flutter (Android) + FastAPI (Python) + PostgreSQL + AWS EC2 + S3  
**Estimated Duration:** 8 Sprints (~8 weeks)  
**Monthly Cost:** ~$32/month (EC2 t3.medium + S3, no ALB)

---

## Sprint Tracker

| Sprint | Target | Status | Completed |
|---|---|---|---|
| **Day 0** | Tools, AWS CLI, Git setup | ✅ Done | 2026-09-27 |
| **Sprint 1** | Terraform IaC, EC2, S3, Nginx, SSL | ✅ Done (infra) | 2026-09-28 |
| **Sprint 2** | FastAPI skeleton, PostgreSQL, Docker | ✅ Done | 2026-10-01 |
| **Sprint 3** | Auth (Admin TOTP + Owner/Customer OTP) | ✅ Done | 2026-10-01 |
| **Sprint 4** | Owner registration, KYC, Admin panel + Flutter screens | 🔲 Not Started | — |
| **Sprint 5** | Menu management (Owner app) | 🔲 Not Started | — |
| **Sprint 6** | Customer discovery (search + browse) | 🔲 Not Started | — |
| **Sprint 7** | Ordering flow + push notifications | 🔲 Not Started | — |
| **Sprint 8** | Testing, APK build, Play Store prep | 🔲 Not Started | — |

**Sprints 1 + 2 + 3 all complete as of 2026-10-01. GitHub Actions APK pipeline live. EC2 stopped (restart before Day 4).**

---

## Pre-Sprint: Quick Answers

### Q: Will I get a default VPC when I register my AWS account?
**Yes.** AWS automatically creates a **Default VPC** in every region when you open a new account.  
It includes:
- CIDR: `172.31.0.0/16`
- One public subnet per Availability Zone
- Internet Gateway (attached and routed)
- Default Security Group
- Default Route Table

**For this POC: use the Default VPC.** It saves you 1–2 hours.  
When you go to production, create a custom VPC with public/private subnets.  
The Terraform in Sprint 1 will reference the Default VPC by data source — no manual work needed.

---

### Q: Does AWS secure our data? Or keep code in personal Git?

**Two separate concerns:**

#### Data on AWS (EC2 + S3 + PostgreSQL)
AWS is responsible for the physical infrastructure (SOC2, ISO 27001 certified).  
You are responsible for:
- Security Group rules (who can reach your EC2)
- IAM permissions (who can access S3)
- SSL on Nginx (HTTPS only — covered in Sprint 1)
- EBS encryption (enable at EC2 creation — covered in Terraform)

For a POC this is **secure enough**. Your data is protected as long as SGs are tight.

#### Code — Use a Private Git Repository
Keep your code in a **private** GitHub or GitLab repository.  
**Never commit:**
- `.env` files (database passwords, API keys)
- AWS credentials (`~/.aws/credentials`)
- Firebase service account JSON
- SSL certificates / private keys

Use `.gitignore` to exclude all of the above.  
Recommended: **GitHub private repo** (free, personal account).  
Later you can mirror to AWS CodeCommit if you want everything inside AWS.

---

## Prerequisites (Before Sprint 1 — Day 0)

### AWS Account Setup
- [ ] Create AWS account at aws.amazon.com
- [ ] Enable MFA on root account
- [ ] Create an IAM user (do NOT use root for day-to-day work)
- [ ] Attach `AdministratorAccess` policy to IAM user (for POC)
- [ ] Generate Access Key + Secret Key for IAM user
- [ ] Install AWS CLI: `winget install Amazon.AWSCLI`
- [ ] Configure CLI: `aws configure` (enter Access Key, Secret, region: `ap-south-1` Mumbai recommended for India)
- [ ] Confirm default VPC exists: `aws ec2 describe-vpcs --filters Name=isDefault,Values=true`

### Local Machine Setup (Windows)
- [ ] Install **Git**: https://git-scm.com
- [ ] Install **Terraform**: `winget install HashiCorp.Terraform`
- [ ] Install **Python 3.11+**: `winget install Python.Python.3.11`
- [ ] Install **Docker Desktop**: https://www.docker.com/products/docker-desktop
- [ ] Install **Android Studio**: https://developer.android.com/studio (includes Android SDK + Emulator)
- [ ] Install **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows
- [ ] Install **VS Code** (optional but recommended for Flutter): https://code.visualstudio.com
  - Add extensions: Flutter, Dart, Python, Docker
- [ ] Install **Postman** (API testing): https://www.postman.com/downloads

### Verify Flutter Setup
```bash
flutter doctor
```
All items should show green. Fix any issues it reports before starting Sprint 3.

### Domain Name (Optional but Recommended)
- Buy a `.in` domain from GoDaddy or Namecheap (~₹800/year)
- Point the A record to your EC2 Elastic IP (done in Sprint 1)
- This gives you `https://api.yourdomain.in` for the app to call

### Git Repository
- [x] Created private GitHub repo: `Project-GSR` under personal account (gurpreet18121990@gmail.com)
- [x] Branch strategy: `main` = active working branch | `master` = validated/stable
- [x] All Terraform code pushed to `main` branch
- [x] `.gitignore` configured — never commits:
  - `terraform.tfvars` (contains your IPs, VPC IDs)
  - `*.pem` / `*.ppk` (SSH private keys)
  - `*.tfstate` / `*.tfstate.backup` (local state files)
  - `corporate-ca-bundle.pem` (QAD Zscaler CA — corporate only)

> **Identity**: All Git commits use personal identity (`gurpreet18121990@gmail.com`) via local repo config only. QAD global git config is untouched.

---

## Sprint 1 — AWS Infrastructure (IaC with Terraform)
**Duration:** 1 day  
**Goal:** EC2 running with Nginx + Docker, accessible via HTTPS  
**Status:** ✅ Infrastructure complete — 11/11 resources created

### What Gets Built
- EC2 instance (t3.medium) in non-default VPC
- Security Group with correct inbound rules (SSH/HTTP/HTTPS)
- Elastic IP (static public IP — free while instance is running)
- S3 bucket (photos + documents storage)
- IAM Role for EC2 → S3 access (no hardcoded keys)
- EBS volume 30GB gp3, encryption enabled
- Nginx + Docker (via cloud-init bootstrap)

---

### Sprint 1 — Day 1 Execution Log (2026-09-28)

#### What Was Actually Deployed

| Resource | Value |
|---|---|
| **Account** | QAD Lab / Support account (personal lab, not production) |
| **Region** | `ap-south-1` (Mumbai) |
| **EC2 Instance ID** | `i-02bb92a9fa97bd78b` |
| **Instance Type** | `t3.medium` (2 vCPU, 4GB RAM) |
| **AMI** | `ami-066c4849e6b3a1e3d` — Amazon Linux 2023 (kernel 6.18) |
| **OS User** | `ec2-user` |
| **Elastic IP** | `43.204.43.71` (static — point domain A record here) |
| **S3 Bucket** | `project-gsr-qad-lab-test-storage-gsrpoc01` |
| **IAM Role ARN** | `arn:aws:iam::423451069244:role/project-gsr-qad-lab-test-ec2-role` |
| **VPC** | `vpc-06546e726a151b9ea` (QAD Lab non-default VPC) |
| **Key Pair** | `g2r-poc` (created in ap-south-1 — region-specific!) |
| **Local State File** | `C:\Claude\Project-GSR\terraform\terraform.tfstate` |

#### Terraform State — Local (Not Remote)
For this POC, state is stored **locally** on your machine.  
Remote S3 backend (cost + complexity) is skipped for now.

> **State file location:** `C:\Claude\Project-GSR\terraform\terraform.tfstate`  
> It is gitignored. Back it up manually if needed: copy `.tfstate` to a safe folder.  
> If you lose it: resources still exist in AWS; you'd need `terraform import` to re-link them.

#### Terraform Commands Run

```powershell
# Set environment (run at the start of every new PowerShell session)
$env:AWS_CA_BUNDLE = "C:\Claude\Project-GSR\corporate-ca-bundle.pem"
$env:SSL_CERT_FILE = "C:\Claude\Project-GSR\corporate-ca-bundle.pem"
# Set AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)

cd C:\Claude\Project-GSR\terraform
```

```powershell
# Step 1 — Initialize (downloads AWS provider, one-time per machine)
terraform init
```
Expected output:
```
Terraform has been successfully initialized!
Provider registry.terraform.io/hashicorp/aws v5.x installed.
```

```powershell
# Step 2 — Preview what will be created (no changes made)
terraform plan
```
Expected output (Sprint 1 shows ~11 resources to create):
```
Plan: 11 to add, 0 to change, 0 to destroy.
  + aws_security_group.gsr_ec2_sg
  + aws_instance.gsr_server
  + aws_eip.gsr_eip
  + aws_eip_association.gsr_eip_assoc
  + aws_s3_bucket.gsr_storage
  + aws_s3_bucket_server_side_encryption_configuration.gsr_s3_enc
  + aws_s3_bucket_public_access_block.gsr_s3_block
  + aws_s3_bucket_versioning.gsr_s3_versioning
  + aws_s3_bucket_lifecycle_configuration.gsr_s3_lifecycle
  + aws_iam_role.gsr_ec2_role
  + aws_iam_instance_profile.gsr_ec2_profile
```

```powershell
# Step 3 — Apply (creates all resources — takes ~2 minutes)
terraform apply
```
Expected output:
```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:
  api_base_url_http  = "http://43.204.43.71"
  ec2_ami_used       = "ami-066c4849e6b3a1e3d"
  ec2_instance_id    = "i-02bb92a9fa97bd78b"
  ec2_public_ip      = "43.204.43.71"
  s3_bucket_arn      = "arn:aws:s3:::project-gsr-qad-lab-test-storage-gsrpoc01"
  s3_bucket_name     = "project-gsr-qad-lab-test-storage-gsrpoc01"
  ssh_command        = "ssh -i your-key.pem ec2-user@43.204.43.71"
```

#### SSH into EC2

**PowerShell:**
```powershell
# Fix PEM permissions (Windows requires this — run once)
$pemFile = "C:\Claude\Project-GSR\g2r-poc.pem"
icacls $pemFile /inheritance:r
icacls $pemFile /remove "NT AUTHORITY\Authenticated Users"
icacls $pemFile /remove "BUILTIN\Users"
icacls $pemFile /remove "Everyone"
icacls $pemFile /grant:r "$($env:USERNAME):R"

# Connect
ssh -i "C:\Claude\Project-GSR\g2r-poc.pem" ec2-user@43.204.43.71
```

**PuTTY (alternative):**
1. Open **PuTTYgen** → Load `g2r-poc.pem` → Save private key → `g2r-poc.ppk`
2. Open **PuTTY** → Host: `43.204.43.71` → SSH → Auth → browse to `g2r-poc.ppk`
3. Login as: `ec2-user`

#### Issues Encountered & Resolved

| Issue | Root Cause | Fix Applied |
|---|---|---|
| Terraform `required_version` mismatch | Had v1.3.6, code required ≥1.5.0 | Changed to `>= 1.3.0` in main.tf |
| AWS CLI SSL error (Zscaler) | Corporate proxy intercepts HTTPS | Created `corporate-ca-bundle.pem` with Zscaler + QAD CA; set `AWS_CA_BUNDLE` env var |
| VPC not found | QAD Lab has no default VPC | Changed `default = true` to `id = var.vpc_id` in networking.tf |
| Em dash `—` in SG descriptions | AWS rejects non-ASCII characters | Replaced all `—` with `-` in security_groups.tf |
| Key pair not found | g2r-poc key was in us-east-2, not ap-south-1 | Created new key pair `g2r-poc` in ap-south-1 |
| SSH bad permissions on .pem | Windows ACL too permissive | Removed Authenticated Users / BUILTIN\Users with icacls |
| `ubuntu@` in SSH output | Old Ubuntu reference not updated | Fixed in outputs.tf → `ec2-user@` |

#### Sprint 1 Day 2 (2026-10-01) — Bootstrap Fix
Cloud-init had failed silently on Day 1 (VPC DNS couldn't resolve external hostnames). All items resolved manually.

**Problem 1: SSH timeout — IP check method matters**

Behind Zscaler, `ipify.org` returns the non-AWS exit IP. Always use AWS's own checker:
```powershell
# From PowerShell on your Windows machine
(Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()
# Returns: 165.225.120.238  ← this is what AWS SG must allow
```
Update `terraform.tfvars` `allowed_ssh_cidr` to match, then update Security Group in AWS Console (or re-apply Terraform).

**Problem 2: EC2 can't resolve external hostnames (VPC DNS)**

QAD Lab VPC uses internal-only DNS — it can't resolve `github.com`, `dl.fedoraproject.org`, etc.

```bash
# Quick fix (survives until next reboot)
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Permanent fix — Amazon Linux 2023 uses systemd-resolved
sudo sed -i 's/#DNS=/DNS=8.8.8.8 8.8.4.4/' /etc/systemd/resolved.conf
sudo sed -i 's/#FallbackDNS=/FallbackDNS=1.1.1.1/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

**Problem 3: dnf lock held by stale background process**
```bash
# Find and kill the process holding the lock
sudo lsof /var/cache/dnf | head
sudo kill -9 <PID>
```

**Installing Docker, Nginx, Git on Amazon Linux 2023**
```bash
sudo dnf update -y
sudo dnf install -y docker nginx git

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to docker group (takes effect on next login)
sudo usermod -aG docker ec2-user
```

**Verify installed versions**
```bash
docker --version    # Docker version 25.0.16
nginx -v            # nginx/1.30.4
git --version       # git version 2.50.1
```

**Install Docker Compose v2 (not in AL2023 dnf repos)**
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version    # Docker Compose version v2.27.0
```

---

### Terraform File Structure
```
project-gsr-infra/
├── main.tf             ← provider config, backend (S3 state)
├── variables.tf        ← region, instance type, key pair name
├── terraform.tfvars    ← your actual values (gitignored)
├── networking.tf       ← fetch default VPC + subnet
├── security_groups.tf  ← SG rules
├── ec2.tf              ← EC2 instance + Elastic IP + EBS
├── s3.tf               ← S3 bucket + bucket policy
├── iam.tf              ← IAM role + instance profile for S3
└── outputs.tf          ← EC2 public IP, S3 bucket name
```

### Terraform Code

**variables.tf**
```hcl
variable "aws_region"      { default = "ap-south-1" }
variable "instance_type"   { default = "t3.medium" }
variable "key_pair_name"   { description = "Your EC2 key pair name" }
variable "project_name"    { default = "project-gsr" }
variable "environment"     { default = "poc" }
```

**networking.tf**
```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

**security_groups.tf**
```hcl
resource "aws_security_group" "gsr_ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Project GSR EC2 Security Group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"]   # Replace with your IP
  }

  ingress {
    description = "HTTP (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg", Project = var.project_name }
}
```

**ec2.tf**
```hcl
resource "aws_instance" "gsr_server" {
  ami                    = "ami-0f5ee92e2d63afc18"  # Ubuntu 22.04 LTS ap-south-1
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.gsr_ec2_sg.id]
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  iam_instance_profile   = aws_iam_instance_profile.gsr_ec2_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true        # EBS encryption ON
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io docker-compose nginx certbot python3-certbot-nginx
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
  EOF

  tags = { Name = "${var.project_name}-server", Project = var.project_name }
}

resource "aws_eip" "gsr_eip" {
  instance = aws_instance.gsr_server.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}
```

**s3.tf**
```hcl
resource "aws_s3_bucket" "gsr_storage" {
  bucket = "${var.project_name}-storage-poc-2026"
  tags   = { Name = "${var.project_name}-storage", Project = var.project_name }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gsr_s3_enc" {
  bucket = aws_s3_bucket.gsr_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "gsr_s3_block" {
  bucket                  = aws_s3_bucket.gsr_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**iam.tf**
```hcl
resource "aws_iam_role" "gsr_ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "gsr_s3_policy" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.gsr_ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.gsr_storage.arn,
        "${aws_s3_bucket.gsr_storage.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "gsr_ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.gsr_ec2_role.name
}
```

**outputs.tf**
```hcl
output "ec2_public_ip"   { value = aws_eip.gsr_eip.public_ip }
output "s3_bucket_name"  { value = aws_s3_bucket.gsr_storage.bucket }
```

### Sprint 1 Execution Steps
```bash
# 1. Initialize Terraform
terraform init

# 2. Preview what will be created
terraform plan

# 3. Apply (creates all resources) — takes ~3 minutes
terraform apply

# 4. Note the output: EC2 public IP + S3 bucket name

# 5. SSH into EC2 (Amazon Linux 2023 uses ec2-user, not ubuntu)
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>

# 6. On EC2 — configure Nginx (Amazon Linux 2023 path)
sudo nano /etc/nginx/conf.d/gsr-api.conf

# 7. On EC2 — get SSL certificate (replace with your domain)
sudo certbot --nginx -d api.yourdomain.in

# 8. Verify HTTPS is working
curl https://api.yourdomain.in/health
```

**Nginx config for FastAPI:**
```nginx
server {
    listen 80;
    server_name api.yourdomain.in;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name api.yourdomain.in;

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
    }
}
```

**Sprint 1 Done when:**
- [x] EC2 is running, accessible via SSH — `ec2-user@43.204.43.71` ✅
- [x] Elastic IP is attached — `43.204.43.71` ✅
- [x] S3 bucket created, encryption enabled ✅
- [x] IAM Role attached to EC2 (EC2 can access S3 without hardcoded keys) ✅
- [x] Docker 25.0.16 + Nginx 1.30.4 installed on EC2 ✅ (fixed Day 2)
- [ ] SSL certificate installed (requires domain — deferred, using HTTP for POC)
- [ ] `https://api.yourdomain.in` returns a response (deferred until domain purchased)

---

## Sprint 2 — FastAPI Backend Skeleton + PostgreSQL
**Duration:** 1 day (2026-10-01)  
**Goal:** API running in Docker on EC2, database connected, health check working  
**Status:** ✅ COMPLETE

### What Was Built

| Component | Detail |
|---|---|
| FastAPI app | `backend/app/main.py` — `/health` + `/` endpoints, CORS middleware |
| Database layer | `backend/app/database.py` — SQLAlchemy engine, `get_db()` dependency |
| ORM models | `backend/app/models.py` — 6 tables: Owner, Restaurant, MenuItem, Customer, Order, Inspection |
| Docker Compose | `backend/docker-compose.yml` — `api` + `db` services with healthcheck |
| Dockerfile | `backend/Dockerfile` — python:3.11-slim, uvicorn |
| Alembic | Migrations configured, initial migration applied — all 6 tables created |
| Nginx proxy | Port 80 → 127.0.0.1:8000 |

### Key Python Packages (requirements.txt)
```
fastapi==0.111.0
uvicorn==0.29.0
sqlalchemy==2.0.30
alembic==1.13.1
psycopg2-binary==2.9.9
python-jose==3.3.0
passlib==1.7.4
pyotp==2.9.0
python-multipart==0.0.9
boto3==1.34.0
pydantic-settings==2.2.1
```

---

### Sprint 2 — Execution Log (2026-10-01)

#### Step 1 — Clone repo on EC2

GitHub SSH (port 22) is blocked from EC2 outbound. Use HTTPS with a Personal Access Token (PAT):
```bash
# On EC2 — clone via HTTPS + PAT (SSH port 22 to GitHub is blocked)
git clone https://<YOUR_PAT>@github.com/gurupreet18121990/GSR-Project.git /opt/project-gsr
cd /opt/project-gsr/backend
```
> PAT: generate at GitHub → Settings → Developer Settings → Personal access tokens → Tokens (classic)  
> Scopes needed: `repo` (full repo access)

#### Step 2 — Create .env on EC2 (NEVER commit this file)
```bash
cat > /opt/project-gsr/backend/.env << 'EOF'
DB_PASSWORD=GsrMumbai2026
DATABASE_URL=postgresql://gsr_user:GsrMumbai2026@db:5432/gsr_db
EOF
```
> **Password rule:** Do NOT use special characters like `@` in the DB password.  
> SQLAlchemy parses the DATABASE_URL and a second `@` breaks the host parsing.  
> Example of what breaks: `postgresql://gsr_user:Gsr@Mumbai2026@db:5432/gsr_db`  
> → SQLAlchemy reads host as `Mumbai2026@db` — wrong. Use alphanumeric passwords only.

#### Step 3 — Start containers
```bash
cd /opt/project-gsr/backend
sudo docker-compose up -d --build
```
Expected output:
```
[+] Running 2/2
 ✔ Container gsr_db   Healthy
 ✔ Container gsr_api  Started
```

Check containers are running:
```bash
sudo docker-compose ps
sudo docker-compose logs api     # check for startup errors
```

> **Note:** `sudo` is required until you log out and back in after `usermod -aG docker ec2-user`.  
> After your next SSH login, you can drop `sudo` from docker commands.

#### Step 4 — Run Alembic migrations (create all 6 tables)
```bash
cd /opt/project-gsr/backend

# Create the versions directory (git doesn't track empty dirs)
mkdir -p alembic/versions

# Generate initial migration — detects all 6 models automatically
sudo docker-compose exec -e PYTHONPATH=/app api \
  alembic revision --autogenerate -m "initial_tables"

# Apply the migration
sudo docker-compose exec -e PYTHONPATH=/app api \
  alembic upgrade head
```
> `PYTHONPATH=/app` is required so Alembic can import `app.models` inside the container.

Verify tables were created:
```bash
sudo docker-compose exec db \
  psql -U gsr_user -d gsr_db -c "\dt"
```
Expected output:
```
           List of relations
 Schema |      Name       | Type  |  Owner
--------+-----------------+-------+----------
 public | alembic_version | table | gsr_user
 public | customer        | table | gsr_user
 public | inspection      | table | gsr_user
 public | menu_item       | table | gsr_user
 public | order           | table | gsr_user
 public | owner           | table | gsr_user
 public | restaurant      | table | gsr_user
(7 rows)
```

#### Step 5 — Configure Nginx reverse proxy
```bash
sudo tee /etc/nginx/conf.d/gsr-api.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }
}
EOF

# Test config and reload
sudo nginx -t
sudo systemctl reload nginx
```

#### Step 6 — Verify end-to-end
```bash
# Health check from inside EC2
curl http://localhost:8000/health
# Expected: {"status":"ok","db":"connected","version":"0.1.0"}

# Health check through Nginx (port 80)
curl http://43.204.43.71/health
# Expected: {"status":"ok","db":"connected","version":"0.1.0"}
```

Swagger UI in browser: **http://43.204.43.71/docs**

#### Step 7 — Commit migration file and push to GitHub
```bash
cd /opt/project-gsr
git add backend/alembic/versions/
git commit -m "Sprint 2: Alembic initial migration - 6 tables created"
git push https://<YOUR_PAT>@github.com/gurupreet18121990/GSR-Project.git main
```

---

### Sprint 2 Issues Encountered & Resolved

| Issue | Root Cause | Fix |
|---|---|---|
| `@` in DB password broke DATABASE_URL | SQLAlchemy parses `@` as host delimiter | Changed password to `GsrMumbai2026` (no special chars) |
| `No module named 'app'` in Alembic | Container PYTHONPATH not set | Add `-e PYTHONPATH=/app` to docker-compose exec |
| `alembic/versions` dir missing | Git doesn't track empty directories | `mkdir -p alembic/versions` on EC2 before running autogenerate |
| `docker-compose restart` didn't re-read .env | restart re-uses existing container config | Use `docker-compose down && docker-compose up -d` to recreate |
| GitHub SSH port 22 blocked from EC2 | Outbound 22 blocked in VPC/SG | Clone via HTTPS + PAT instead |
| `git push` to master failed from EC2 | EC2 local branch is `main`, not `master` | Push to `main`: `git push origin main` |
| Permission denied on docker socket | `ec2-user` not in docker group yet | Use `sudo docker-compose` until next login |

---

### Useful Day-to-Day Commands (EC2)

```bash
# Check containers status
sudo docker-compose -f /opt/project-gsr/backend/docker-compose.yml ps

# Tail API logs
sudo docker-compose -f /opt/project-gsr/backend/docker-compose.yml logs -f api

# Restart API only (if you pushed new code)
cd /opt/project-gsr
git pull https://<PAT>@github.com/gurupreet18121990/GSR-Project.git main
cd backend
sudo docker-compose up -d --build api

# Connect to PostgreSQL directly
sudo docker-compose -f /opt/project-gsr/backend/docker-compose.yml exec db \
  psql -U gsr_user -d gsr_db

# Run a new Alembic migration after adding models
sudo docker-compose -f /opt/project-gsr/backend/docker-compose.yml exec \
  -e PYTHONPATH=/app api alembic revision --autogenerate -m "describe_change"
sudo docker-compose -f /opt/project-gsr/backend/docker-compose.yml exec \
  -e PYTHONPATH=/app api alembic upgrade head
```

---

### Running EC2 State (as of 2026-10-01)

| Item | Value |
|---|---|
| EC2 Public IP | `43.204.43.71` (Elastic IP) |
| API Health | http://43.204.43.71/health |
| Swagger UI | http://43.204.43.71/docs |
| Working dir on EC2 | `/opt/project-gsr/backend/` |
| DB name | `gsr_db` / user `gsr_user` |
| DB password | In `.env` on EC2 (not in git) |
| Docker containers | `gsr_api` (port 8000), `gsr_db` (port 5432 internal only) |
| DB volume | `backend_postgres_data` (persistent — survives container restart) |
| GitHub branch | `main` = active working | `master` = validated/stable |

---

**Sprint 2 Done when:**
- [x] FastAPI running in Docker on EC2 ✅
- [x] PostgreSQL running in Docker on EC2 ✅
- [x] All 6 database tables created via Alembic ✅
- [x] `GET /health` returns `{"status":"ok","db":"connected","version":"0.1.0"}` ✅
- [x] Nginx proxying port 80 → FastAPI ✅
- [x] Swagger UI accessible at http://43.204.43.71/docs ✅
- [x] Code + migration pushed to GitHub ✅

---

## Sprint 3 — Authentication
**Duration:** 1 day (2026-10-01)  
**Goal:** All three login types working  
**Status:** 🔶 Admin TOTP complete. Firebase (Owner/Customer) pending.

### New Files Added
| File | Purpose |
|---|---|
| `backend/app/core/security.py` | bcrypt hashing, JWT create/decode, TOTP generate/verify |
| `backend/app/schemas/auth.py` | Pydantic request/response models |
| `backend/app/routers/auth.py` | Auth endpoints |
| `backend/scripts/seed_admin.py` | Seeds first admin user (run once) |

### Auth Endpoints
| Endpoint | Purpose |
|---|---|
| `POST /auth/admin/login` | Step 1 — verify password, require TOTP code if enabled |
| `POST /auth/admin/setup-totp` | Protected — generate TOTP secret + QR URI |
| `POST /auth/admin/confirm-totp` | Protected — verify first code, activate TOTP |
| `POST /auth/owner/login` | Firebase token → JWT (503 until Firebase configured) |
| `POST /auth/customer/login` | Firebase token → auto-register + JWT |

### Sprint 3 Day 3 Execution Log (2026-10-01)

#### Step 1 — Rebuild container with new packages
```bash
cd /opt/project-gsr/backend
sudo docker-compose down
sudo docker-compose up -d --build
```

#### Step 2 — Run Alembic migration (adds admin table)
```bash
sudo docker-compose exec -e PYTHONPATH=/app api \
  alembic revision --autogenerate -m "add_admin_table"
sudo docker-compose exec -e PYTHONPATH=/app api alembic upgrade head
```

#### Step 3 — Add JWT secret + seed admin user
```bash
echo "JWT_SECRET_KEY=GsrJwtSecret2026MumbaiPhase1" >> /opt/project-gsr/backend/.env
sudo docker-compose exec -e PYTHONPATH=/app api python scripts/seed_admin.py
```

#### Step 4 — First login (password only — TOTP not set up yet)
```powershell
Invoke-RestMethod -Uri "http://43.204.43.71/auth/admin/login" -Method POST `
  -Headers @{Accept="application/json"} -ContentType "application/json" `
  -Body '{"username":"admin","password":"Admin@GSR2026"}'
# Returns: access_token + totp_setup_required: true
```

#### Step 5 — Get TOTP secret
```powershell
$token = "<access_token_from_step_4>"
Invoke-RestMethod -Uri "http://43.204.43.71/auth/admin/setup-totp" -Method POST `
  -Headers @{Authorization="Bearer $token"; Accept="application/json"}
# Returns: secret + qr_uri
```

#### Step 6 — Add to Google Authenticator
1. Open app → tap **+** → **Enter a setup key**
2. Account name: `GSR Admin`, Key: paste the `secret`, Type: Time-based → **Add**

#### Step 7 — Confirm TOTP (get 6-digit code from app, act within 30s)
```powershell
Invoke-RestMethod -Uri "http://43.204.43.71/auth/admin/confirm-totp" -Method POST `
  -Headers @{Authorization="Bearer $token"; Accept="application/json"} `
  -ContentType "application/json" -Body '{"code":"123456"}'
# Returns: "TOTP enabled. Future logins require the 6-digit code."
```

#### Step 8 — Full login (all future logins use this)
```powershell
Invoke-RestMethod -Uri "http://43.204.43.71/auth/admin/login" -Method POST `
  -Headers @{Accept="application/json"} -ContentType "application/json" `
  -Body '{"username":"admin","password":"Admin@GSR2026","totp_code":"123456"}'
# Returns: clean access_token — no totp_setup_required flag
```

### Admin Credentials (EC2)
| Item | Value |
|---|---|
| Username | `admin` |
| Password | `Admin@GSR2026` |
| TOTP | Google Authenticator — "GSR Admin" entry |
| TOTP secret backup | `YBSQN43UNUXX7F4BEE7IBEZD63H7KMDZ` |
| JWT expiry | 8 hours |

### Sprint 3 Issues & Fixes
| Issue | Fix |
|---|---|
| Swagger Authorize not sending Bearer header | Page refresh fixes it. Use PowerShell as reliable fallback. |
| `bcrypt` warning — no `__about__` attribute | Harmless — bcrypt ≥ 4.0 removed it. Hashing still works. |
| TOTP code expires in 30s | Use PowerShell (faster). If expired, use the next rotating code. |

### Owner + Customer Login (Firebase OTP) — Pending

**Firebase Auth Setup (free — ~15 min):**
1. Go to console.firebase.google.com → Create project "Project-GSR"
2. Enable Authentication → Phone Sign-In
3. Download service account JSON → copy to EC2
4. Add path to `.env`: `FIREBASE_SERVICE_ACCOUNT_PATH=/app/firebase-service-account.json`
5. Restart containers

**Login flow (already coded — just needs Firebase configured):**
```
Flutter → enter mobile number
  → Firebase sends SMS OTP
  → User enters OTP → Firebase returns ID Token
  → FastAPI: POST /auth/owner/login {firebase_id_token, mobile}
  → FastAPI verifies token via Firebase Admin SDK
  → FastAPI issues JWT
```

**Sprint 3 Done when:**
- [x] Admin can log in with username + password + Google Authenticator code ✅
- [x] Firebase Admin SDK initialized and connected (project-gsr-cd6c6) ✅
- [x] Owner login endpoint live — awaits real Firebase ID token from Flutter app ✅
- [x] Customer login + auto-register endpoint live ✅
- [x] JWT tokens issued and verified correctly ✅

---

## Sprint 4 Prep — GitHub Actions APK Pipeline + Flutter Scaffold
**Completed:** 2026-10-01 (same session as Sprint 3)

### What Was Set Up

| Item | Detail |
|---|---|
| Flutter project | `gsr_app/` — created with `flutter create --org com.gsr --project-name gsr_app` on EC2 |
| Flutter version | 3.47.5 (stable) / Dart 3.13.4 |
| Package ID | `com.gsr.gsr_app` |
| GitHub Actions workflow | `.github/workflows/build-apk.yml` |
| Trigger | Push to main/master when `gsr_app/**` changes, or manual dispatch |
| Build output | `gsr_app/build/app/outputs/flutter-apk/app-debug.apk` |
| First build | Build #1 — SUCCESS — 6m 44s — 66.8 MB |
| APK download | GitHub → Actions → Build #1 → Artifacts → GSR-debug-1 |

### How to Get a Fresh APK (every time you push Flutter code)
1. Push any change to `gsr_app/` → GitHub Actions auto-starts
2. Wait ~6–7 min → green checkmark
3. Click the run → scroll to **Artifacts** → download **GSR-debug-1**
4. Unzip → get `app-debug.apk` → send to phone via WhatsApp → install

### How to Manually Trigger a Build
GitHub → Actions → **Build Flutter APK** → **Run workflow** → Run workflow

### Stop/Start EC2 (cost saving)
```powershell
# Check your current AWS-visible IP before starting (Zscaler changes it)
(Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()

# SSH after starting
ssh -i "C:\Claude\Project-GSR\g2r-poc.pem" ec2-user@43.204.43.71
```
> EC2 stopped at end of Day 3. Restart from AWS Console → EC2 → i-02bb92a9fa97bd78b → Start.
> Elastic IP (43.204.43.71) stays the same after restart — no config changes needed.

---

## Sprint 4 — Owner Registration + KYC Admin Panel
**Duration:** 4–5 days  
**Goal:** Owner can register, upload docs; Admin can approve/reject

### Flutter Screens Built This Sprint
- `registration_screen.dart` — multi-step form (personal details → restaurant details → document upload)
- `admin_login_screen.dart` + `totp_verify_screen.dart`
- `kyc_pending_screen.dart` — list of pending registrations
- `restaurant_review_screen.dart` — view owner docs, approve/reject

### Document Upload Flow
```
Flutter → pick image from gallery/camera
        ↓
Flutter → POST /upload (multipart form)
        ↓
FastAPI → boto3 → upload to S3
        ↓
FastAPI → store S3 URL in database
        ↓
Admin views document via pre-signed S3 URL (expires in 1 hour)
```

### Inspection Scheduling
- On restaurant approval → auto-create first `Inspection` record with `NextDueDate = today + 30 days`
- Admin panel shows inspections due this month
- Field agent logs result (Pass/Fail + notes + photos)
- On Fail → restaurant status → `Suspended` (hidden from customers)

**Sprint 4 Done when:**
- [ ] Owner can complete registration with photo + GSTIN upload
- [ ] Admin sees pending KYC list with documents viewable
- [ ] Admin can approve (owner gets SMS confirmation) or reject
- [ ] Inspection record auto-created on approval
- [ ] Rejected restaurant cannot log in

---

## Sprint 5 — Menu Management (Owner Side)
**Duration:** 3–4 days  
**Goal:** Owner can fully manage their menu from the app

### Flutter Screens Built This Sprint
- `restaurant_select_screen.dart` — if owner has multiple restaurants
- `owner_dashboard_screen.dart` — summary: orders today, menu items
- `menu_manage_screen.dart` — list of categories + items
- `add_edit_item_screen.dart` — form to add/edit item with photo upload

### Menu Features
- Add categories (e.g., Starters, Main Course, Drinks, Desserts)
- Add items under each category (name, description, price, photo)
- Toggle item availability (on/off) — shown greyed out to customers when off
- Delete item (soft delete — hidden, not removed from order history)

**Sprint 5 Done when:**
- [ ] Owner can add/edit/delete menu items
- [ ] Owner can toggle item availability
- [ ] Menu items with photos visible correctly
- [ ] Owner with 2 restaurants can switch between them

---

## Sprint 6 — Customer App — Discovery & Browsing
**Duration:** 3–4 days  
**Goal:** Customer can find and browse restaurants

### Flutter Screens Built This Sprint
- `home_screen.dart` — pincode search + district selector
- `restaurant_list_screen.dart` — sorted by area/locality
- `restaurant_detail_screen.dart` — photos, address, full menu

### Customer Search Logic
```
Customer enters pincode (e.g., 431001)
        ↓
GET /restaurants?pincode=431001
        ↓
Returns: Active restaurants only
         Grouped by Area/Locality
         Sorted alphabetically by area
        ↓
Each card shows:
  - Restaurant photo
  - Name
  - Area (e.g., Osmanpura)
  - Type (Veg / Non-Veg / Both)
  - Address
```

**Sprint 6 Done when:**
- [ ] Customer can search by pincode
- [ ] Restaurant list appears, grouped by area
- [ ] Suspended restaurants do NOT appear
- [ ] Restaurant detail shows full menu with prices
- [ ] Guest users (no login) can browse freely

---

## Sprint 7 — Ordering Flow + Notifications
**Duration:** 4–5 days  
**Goal:** Customer places order, owner gets notified, updates status

### Flutter Screens Built This Sprint
- `cart_screen.dart` — items, quantities, total
- `checkout_screen.dart` — name, address, Cash/UPI note
- `order_confirm_screen.dart` — order placed confirmation
- `incoming_orders_screen.dart` (Owner) — live list of new orders
- `order_detail_screen.dart` (Owner) — accept, update status

### Order Status Flow
```
Customer places order → Status: PLACED
        ↓
Owner receives push notification (Firebase FCM)
        ↓
Owner taps notification → sees order details
        ↓
Owner accepts → Status: ACCEPTED
        ↓
Owner marks food ready → Status: READY
        ↓
Rider collects → Status: OUT_FOR_DELIVERY (optional Phase 1)
        ↓
Delivered → Status: DELIVERED
```

### Order Items — Snapshot Approach
When order is placed, **copy current prices into the order** (JSONB field).  
This ensures if the owner changes prices tomorrow, old orders still show correct prices.

```json
{
  "items": [
    {"item_id": "uuid", "name": "Chicken Biryani", "price": 180, "qty": 2},
    {"item_id": "uuid", "name": "Raita", "price": 30, "qty": 1}
  ],
  "total": 390
}
```

**Sprint 7 Done when:**
- [ ] Customer can add to cart, checkout, place order
- [ ] Owner receives push notification on new order
- [ ] Owner can accept order and update status
- [ ] Order shows correct prices even if menu changes

---

## Sprint 8 — Testing + APK Build + Play Store Prep
**Duration:** 3–4 days  
**Goal:** Working APK ready for real-device testing + Play Store submission prep

### Testing Checklist
- [ ] Full order flow: search → browse → cart → checkout → order placed
- [ ] Owner receives notification, accepts order
- [ ] Admin KYC approval flow end-to-end
- [ ] Menu toggle hides item from customer immediately
- [ ] Suspended restaurant disappears from customer search
- [ ] Guest ordering works (no login required)
- [ ] Multiple restaurants under one owner work correctly
- [ ] Test on real Android device (not just emulator)

### How to Build the APK

**Step 1 — Create a keystore (one-time, keep it safe)**
```bash
keytool -genkey -v -keystore gsr-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias gsr-key
```
> IMPORTANT: Back up this `.jks` file. If you lose it, you cannot update the app on Play Store.

**Step 2 — Configure signing in Flutter**  
Create `android/key.properties`:
```
storePassword=yourpassword
keyPassword=yourpassword
keyAlias=gsr-key
storeFile=../gsr-release-key.jks
```

**Step 3 — Build release APK (for direct install/testing)**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Step 4 — Build App Bundle (for Google Play Store)**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Step 5 — Install APK directly on Android device (for testing)**
```bash
# Via USB (ADB)
adb install build/app/outputs/flutter-apk/app-release.apk

# Or share the .apk file via WhatsApp/Google Drive
# User enables: Settings → Install unknown apps → Allow
```

### Google Play Store Submission
| Step | Detail |
|---|---|
| Developer account | $25 one-time fee at play.google.com/console |
| App listing | App name, description, screenshots, icon |
| Upload | Upload the `.aab` file (not APK) |
| Review | 1–3 days for first submission |
| Updates | Usually approved within hours |

**For internal testing before Play Store:**
- Use **Firebase App Distribution** (free)
- Upload APK → invite testers via email → they install directly
- No Play Store review needed for this stage

---

## Summary: Full Sprint Timeline

| Sprint | What Gets Built | Duration | Who Does It |
|---|---|---|---|
| **Day 0** | Account setup, tools install, Git repos | 1 day | You (DevOps) |
| **Sprint 1** | Terraform IaC, EC2, S3, Nginx, SSL | 1 day | You (DevOps) |
| **Sprint 2** | FastAPI skeleton, PostgreSQL, Docker | 3–4 days | Developer |
| **Sprint 3** | Auth (Admin TOTP + Owner/Customer OTP) | 3–4 days | Developer |
| **Sprint 4** | Owner registration, KYC, Admin panel | 4–5 days | Developer |
| **Sprint 5** | Menu management (Owner app) | 3–4 days | Developer |
| **Sprint 6** | Customer discovery (search + browse) | 3–4 days | Developer |
| **Sprint 7** | Ordering flow + push notifications | 4–5 days | Developer |
| **Sprint 8** | Testing, APK build, Play Store prep | 3–4 days | Developer + You |
| **Total** | | **~8 weeks** | |

---

## Cost Summary (Monthly — POC)

| Service | Cost |
|---|---|
| EC2 t3.medium (Mumbai) | ~$30 |
| S3 (20GB + requests) | ~$1–2 |
| Elastic IP (attached) | $0 |
| Let's Encrypt SSL | $0 |
| Firebase Auth OTP | $0 (free up to 10k/month) |
| Firebase FCM notifications | $0 (free) |
| Google Play Developer | $25 one-time |
| **Monthly total** | **~$32/month** |

---

## Future Scale-Up Path (When Needed)

| Current (POC) | Scale-Up |
|---|---|
| PostgreSQL on EC2 | Move to RDS PostgreSQL (change 1 line in .env) |
| Single EC2 | Add ALB + second EC2 (horizontal scale) |
| No website | Add Flutter Web or React → same FastAPI backend |
| Manual deployment | Add GitHub Actions CI/CD pipeline |
| Basic monitoring | Add CloudWatch + alerts |
| Direct APK/Play Store | Add Firebase App Distribution for staged rollout |
