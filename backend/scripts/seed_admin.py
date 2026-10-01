"""
Run once to create the first admin user.

Usage (inside the api container):
  docker-compose exec -e PYTHONPATH=/app api python scripts/seed_admin.py
"""
import os, sys
sys.path.insert(0, "/app")

from app.database import SessionLocal
from app.models import Admin
from app.core.security import hash_password

USERNAME = os.getenv("ADMIN_USERNAME", "admin")
PASSWORD = os.getenv("ADMIN_PASSWORD", "Admin@GSR2026")

db = SessionLocal()
try:
    existing = db.query(Admin).filter(Admin.username == USERNAME).first()
    if existing:
        print(f"Admin '{USERNAME}' already exists — skipping.")
    else:
        admin = Admin(username=USERNAME, password_hash=hash_password(PASSWORD))
        db.add(admin)
        db.commit()
        print(f"Admin created: username='{USERNAME}'")
        print("Next step: call POST /auth/admin/login, then POST /auth/admin/setup-totp, then POST /auth/admin/confirm-totp")
finally:
    db.close()
