from pydantic import BaseModel
from typing import Optional


# ── Admin ──────────────────────────────────────────────────────────────────

class AdminLoginRequest(BaseModel):
    username: str
    password: str
    totp_code: Optional[str] = None   # required only when totp_enabled=True


class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    totp_setup_required: bool = False  # True on first login before TOTP is configured


class SetupTotpResponse(BaseModel):
    secret: str
    qr_uri: str
    message: str = "Scan the Qr URI with Google Authenticator, then call /auth/admin/confirm-totp"


class ConfirmTotpRequest(BaseModel):
    code: str   # 6-digit code from Google Authenticator


class ConfirmTotpResponse(BaseModel):
    message: str


# ── Owner / Customer (Firebase OTP) ────────────────────────────────────────

class FirebaseLoginRequest(BaseModel):
    firebase_id_token: str
    mobile: str
    name: Optional[str] = None   # optional — used for first-time customer registration


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    is_new_user: bool = False
