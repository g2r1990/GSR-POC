import os
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError

from app.database import get_db
from app.models import Admin, Owner, Customer
from app.core.security import (
    hash_password, verify_password,
    create_access_token, decode_token,
    generate_totp_secret, get_totp_uri, verify_totp,
)
from app.schemas.auth import (
    AdminLoginRequest, AdminLoginResponse,
    SetupTotpResponse, ConfirmTotpRequest, ConfirmTotpResponse,
    FirebaseLoginRequest, TokenResponse,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])
bearer = HTTPBearer()

FIREBASE_ENABLED = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH") is not None

# ── helpers ────────────────────────────────────────────────────────────────

def _require_role(credentials: HTTPAuthorizationCredentials, role: str) -> dict:
    try:
        payload = decode_token(credentials.credentials)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    if payload.get("role") != role:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Requires {role} role")
    return payload


def _verify_firebase_token(id_token: str) -> dict:
    if not FIREBASE_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase not configured on this server. Set FIREBASE_SERVICE_ACCOUNT_PATH env var."
        )
    import firebase_admin
    from firebase_admin import auth as fb_auth
    try:
        return fb_auth.verify_id_token(id_token)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid Firebase token: {e}")


# ── Admin: login ───────────────────────────────────────────────────────────

@router.post("/admin/login", response_model=AdminLoginResponse)
def admin_login(body: AdminLoginRequest, db: Session = Depends(get_db)):
    admin = db.query(Admin).filter(Admin.username == body.username, Admin.is_active == True).first()
    if not admin or not verify_password(body.password, admin.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if not admin.totp_enabled:
        # TOTP not set up yet — issue a token with a flag so the client knows to call setup-totp
        token = create_access_token(subject=admin.id, role="admin")
        return AdminLoginResponse(access_token=token, totp_setup_required=True)

    # TOTP is enabled — code is required
    if not body.totp_code:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="totp_code is required because TOTP is enabled for this account")

    if not verify_totp(admin.totp_secret, body.totp_code):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid TOTP code")

    token = create_access_token(subject=admin.id, role="admin")
    return AdminLoginResponse(access_token=token)


# ── Admin: setup TOTP (first-time) ────────────────────────────────────────

@router.post("/admin/setup-totp", response_model=SetupTotpResponse)
def admin_setup_totp(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    payload = _require_role(credentials, "admin")
    admin = db.get(Admin, payload["sub"])
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")
    if admin.totp_enabled:
        raise HTTPException(status_code=400, detail="TOTP already configured. Disable it first to reset.")

    secret = generate_totp_secret()
    admin.totp_secret = secret
    db.commit()

    return SetupTotpResponse(secret=secret, qr_uri=get_totp_uri(secret, admin.username))


# ── Admin: confirm TOTP (scan QR → enter first code → enable) ─────────────

@router.post("/admin/confirm-totp", response_model=ConfirmTotpResponse)
def admin_confirm_totp(
    body: ConfirmTotpRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    payload = _require_role(credentials, "admin")
    admin = db.get(Admin, payload["sub"])
    if not admin or not admin.totp_secret:
        raise HTTPException(status_code=400, detail="Run /auth/admin/setup-totp first")
    if admin.totp_enabled:
        raise HTTPException(status_code=400, detail="TOTP already confirmed")

    if not verify_totp(admin.totp_secret, body.code):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid TOTP code — try again")

    admin.totp_enabled = True
    db.commit()
    return ConfirmTotpResponse(message="TOTP enabled. Future logins require the 6-digit code.")


# ── Owner: Firebase OTP login ──────────────────────────────────────────────

@router.post("/owner/login", response_model=TokenResponse)
def owner_login(body: FirebaseLoginRequest, db: Session = Depends(get_db)):
    decoded = _verify_firebase_token(body.firebase_id_token)
    firebase_uid = decoded["uid"]

    owner = db.query(Owner).filter(Owner.mobile == body.mobile).first()
    if not owner:
        raise HTTPException(status_code=404,
                            detail="Owner not registered. Complete registration first.")
    if owner.status == "suspended":
        raise HTTPException(status_code=403, detail="Account suspended. Contact admin.")

    token = create_access_token(subject=owner.id, role="owner")
    return TokenResponse(access_token=token)


# ── Customer: Firebase OTP login / auto-register ───────────────────────────

@router.post("/customer/login", response_model=TokenResponse)
def customer_login(body: FirebaseLoginRequest, db: Session = Depends(get_db)):
    decoded = _verify_firebase_token(body.firebase_id_token)
    firebase_uid = decoded["uid"]

    customer = db.query(Customer).filter(Customer.mobile == body.mobile).first()
    is_new = False

    if not customer:
        customer = Customer(
            mobile=body.mobile,
            firebase_uid=firebase_uid,
            name=body.name,
        )
        db.add(customer)
        db.commit()
        db.refresh(customer)
        is_new = True
    else:
        if not customer.firebase_uid:
            customer.firebase_uid = firebase_uid
            db.commit()

    token = create_access_token(subject=customer.id, role="customer")
    return TokenResponse(access_token=token, is_new_user=is_new)
