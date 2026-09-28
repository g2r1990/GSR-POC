# Project GSR — Phase 1 Runbook
**Last Updated:** 2026-09-27  
**Stack:** Flutter (Android) + FastAPI (Python) + PostgreSQL + AWS EC2 + S3  
**Estimated Duration:** 8 Sprints (~8 weeks)  
**Monthly Cost:** ~$32/month (EC2 t3.medium + S3, no ALB)

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
- [ ] Create private GitHub repo: `project-gsr-backend`
- [ ] Create private GitHub repo: `project-gsr-app`
- [ ] Create private GitHub repo: `project-gsr-infra`
- [ ] Add `.gitignore` to each (Python / Flutter / Terraform templates)

---

## Sprint 1 — AWS Infrastructure (IaC with Terraform)
**Duration:** 1 day (DevOps-familiar, this is straightforward)  
**Goal:** EC2 running with Nginx + Docker, accessible via HTTPS

### What Gets Built
- EC2 instance (t3.medium) in Default VPC
- Security Group with correct inbound rules
- Elastic IP (static public IP)
- S3 bucket (photos + documents storage)
- IAM Role for EC2 → S3 access (no hardcoded keys)
- EBS volume encryption enabled
- Nginx + Certbot (Let's Encrypt SSL) on EC2

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

# 5. SSH into EC2
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>

# 6. On EC2 — configure Nginx
sudo nano /etc/nginx/sites-available/gsr-api

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
- [ ] EC2 is running, accessible via SSH
- [ ] Elastic IP is attached
- [ ] S3 bucket created, encryption enabled
- [ ] Nginx running, SSL certificate installed
- [ ] `https://api.yourdomain.in` returns a response

---

## Sprint 2 — FastAPI Backend Skeleton + PostgreSQL
**Duration:** 3–4 days  
**Goal:** API running in Docker on EC2, database connected, health check working

### Tools Needed
- Python 3.11
- Docker + Docker Compose
- VS Code with Python extension
- Postman (for testing endpoints)

### Key Python Packages (requirements.txt)
```
fastapi==0.111.0
uvicorn==0.29.0
sqlalchemy==2.0.30
alembic==1.13.1
psycopg2-binary==2.9.9
python-jose==3.3.0        # JWT tokens
passlib==1.7.4            # password hashing
pyotp==2.9.0              # Google Authenticator TOTP
python-multipart==0.0.9   # file uploads
boto3==1.34.0             # S3 uploads
pydantic-settings==2.2.1  # .env config
```

### Docker Compose (on EC2)
```yaml
version: '3.8'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: gsr_db
      POSTGRES_USER: gsr_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://gsr_user:${DB_PASSWORD}@db:5432/gsr_db
    depends_on:
      - db
    volumes:
      - .:/app

volumes:
  postgres_data:
```

### Database Tables Created (Alembic migrations)
All tables from the data model:
`owner`, `restaurant`, `menu_item`, `customer`, `order`, `order_item`, `inspection`

**Sprint 2 Done when:**
- [ ] FastAPI running in Docker on EC2
- [ ] PostgreSQL running in Docker on EC2
- [ ] All database tables created
- [ ] `GET /health` returns `{"status": "ok", "db": "connected"}`
- [ ] Postman can hit the EC2 via HTTPS

---

## Sprint 3 — Authentication
**Duration:** 3–4 days  
**Goal:** All three login types working

### Admin Login (Username + Password + Google Authenticator)

**How Google Authenticator works:**
1. Admin logs in with username + password → server returns a TOTP QR code URL
2. Admin scans QR code with Google Authenticator app (one-time setup)
3. Every login after: username + password → then 6-digit code from app → JWT issued
4. Server uses `pyotp` library — completely free, no external API

```python
import pyotp

# Generate secret for admin (store in DB, one time)
secret = pyotp.random_base32()

# Generate QR code URL (scan with Google Authenticator)
totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
    name="admin@projectgsr.com",
    issuer_name="Project GSR Admin"
)

# Verify code at login
totp = pyotp.TOTP(secret)
is_valid = totp.verify("123456")  # code from Google Authenticator app
```

### Owner + Customer Login (Mobile OTP via Firebase)

**Firebase Auth Setup (free):**
1. Go to console.firebase.google.com → Create project "Project-GSR"
2. Enable Authentication → Phone Sign-In
3. Download `google-services.json` → put in Flutter `android/app/` folder
4. Add Firebase Admin SDK to FastAPI for token verification

**Login flow:**
```
User enters mobile number in Flutter app
        ↓
Flutter sends OTP via Firebase (SMS to user)
        ↓
User enters 6-digit OTP in app
        ↓
Firebase verifies → returns Firebase ID Token
        ↓
Flutter sends Firebase ID Token to FastAPI
        ↓
FastAPI verifies token with Firebase Admin SDK
        ↓
FastAPI issues its own JWT → stored in app
```

**Sprint 3 Done when:**
- [ ] Admin can log in with username + password + Google Authenticator code
- [ ] Owner can log in via mobile OTP
- [ ] Customer can log in or order as guest
- [ ] JWT tokens issued and verified correctly
- [ ] Test all flows in Postman

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
