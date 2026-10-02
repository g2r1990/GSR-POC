import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError

from app.database import get_db
from app.models import Owner, Restaurant
from app.core.security import decode_token, hash_password, verify_password, create_access_token
from app.schemas.owner import (
    OwnerRegisterRequest, OwnerRegisterResponse,
    OwnerSetPasswordRequest, OwnerLoginRequest, OwnerLoginResponse,
)

router = APIRouter(prefix="/owner", tags=["Owner"])
bearer = HTTPBearer()

S3_BUCKET = os.getenv("S3_BUCKET_NAME", "")

# Indian state → ISO abbreviation
_STATE_CODES = {
    'Andhra Pradesh': 'AP', 'Arunachal Pradesh': 'AR', 'Assam': 'AS',
    'Bihar': 'BR', 'Chhattisgarh': 'CG', 'Delhi': 'DL', 'Goa': 'GA',
    'Gujarat': 'GJ', 'Haryana': 'HR', 'Himachal Pradesh': 'HP',
    'Jammu and Kashmir': 'JK', 'Jharkhand': 'JH', 'Karnataka': 'KA',
    'Kerala': 'KL', 'Ladakh': 'LA', 'Madhya Pradesh': 'MP',
    'Maharashtra': 'MH', 'Manipur': 'MN', 'Meghalaya': 'ML',
    'Mizoram': 'MZ', 'Nagaland': 'NL', 'Odisha': 'OD', 'Punjab': 'PB',
    'Rajasthan': 'RJ', 'Sikkim': 'SK', 'Tamil Nadu': 'TN',
    'Telangana': 'TS', 'Tripura': 'TR', 'Uttar Pradesh': 'UP',
    'Uttarakhand': 'UK', 'West Bengal': 'WB',
}


def _generate_restaurant_code(state: str, pincode: str, db: Session) -> str:
    sc = _STATE_CODES.get(state, (state[:2] if len(state) >= 2 else 'XX').upper())
    zone = pincode[:3] if len(pincode) >= 3 else pincode.zfill(3)
    prefix = f"{sc}{zone}"
    count = db.query(Restaurant).filter(
        Restaurant.restaurant_code.like(f"{prefix}-%")
    ).count()
    return f"{prefix}-{count + 1:03d}"


def _get_owner_id(credentials: HTTPAuthorizationCredentials) -> str:
    try:
        payload = decode_token(credentials.credentials)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    if payload.get("role") != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Requires owner role")
    return payload["sub"]


# ── Registration ───────────────────────────────────────────────────────────────

@router.post("/register", response_model=OwnerRegisterResponse, status_code=201)
def owner_register(body: OwnerRegisterRequest, db: Session = Depends(get_db)):
    if db.query(Owner).filter(Owner.mobile == body.mobile).first():
        raise HTTPException(status_code=409, detail="Mobile number already registered.")

    owner = Owner(
        name=body.name,
        mobile=body.mobile,
        gstin=body.gstin,
        password_hash=hash_password(body.password),
        status="pending",
    )
    db.add(owner)
    db.flush()

    restaurant_code = _generate_restaurant_code(body.state, body.pincode, db)

    restaurant = Restaurant(
        owner_id=owner.id,
        name=body.restaurant_name,
        address=body.address,
        area=body.area,
        pincode=body.pincode,
        state=body.state,
        restaurant_code=restaurant_code,
        food_type=body.food_type,
        status="pending",
    )
    db.add(restaurant)
    db.commit()
    db.refresh(owner)

    return OwnerRegisterResponse(
        owner_id=owner.id,
        restaurant_code=restaurant_code,
    )


# ── Application status (no auth — used by pending owners) ─────────────────────

@router.get("/status")
def owner_status(mobile: str, db: Session = Depends(get_db)):
    """Check registration status by mobile number. No auth required."""
    # Normalize mobile: strip +91 prefix for DB lookup
    normalized = mobile.strip()
    if not normalized.startswith('+'):
        normalized = '+91' + normalized.lstrip('0')

    owner = db.query(Owner).filter(Owner.mobile == normalized).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Mobile number not registered.")

    restaurant = owner.restaurants[0] if owner.restaurants else None
    return {
        "status": owner.status,
        "owner_name": owner.name,
        "rejection_reason": owner.rejection_reason,
        "restaurant_name": restaurant.name if restaurant else None,
        "restaurant_code": restaurant.restaurant_code if restaurant else None,
    }


# ── Auth ───────────────────────────────────────────────────────────────────────

@router.post("/auth/set-password", status_code=200)
def owner_set_password(body: OwnerSetPasswordRequest, db: Session = Depends(get_db)):
    owner = db.query(Owner).filter(Owner.mobile == body.mobile).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found.")
    owner.password_hash = hash_password(body.password)
    db.commit()
    return {"message": "Password set successfully."}


@router.post("/auth/login", response_model=OwnerLoginResponse)
def owner_login_password(body: OwnerLoginRequest, db: Session = Depends(get_db)):
    owner = db.query(Owner).filter(Owner.mobile == body.mobile).first()
    if not owner or not owner.password_hash:
        raise HTTPException(status_code=401, detail="Invalid credentials.")
    if not verify_password(body.password, owner.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials.")

    if owner.status == "pending":
        raise HTTPException(
            status_code=403,
            detail="Account pending. Your application is under review by the BossBite team.",
        )
    if owner.status == "rejected":
        reason = owner.rejection_reason or "No reason provided."
        raise HTTPException(
            status_code=403,
            detail=f"Account rejected. Reason: {reason}",
        )
    if owner.status not in ("active",):
        raise HTTPException(
            status_code=403,
            detail=f"Account {owner.status}. Please contact the BossBite team.",
        )

    token = create_access_token(subject=owner.id, role="owner")
    return OwnerLoginResponse(access_token=token, owner_id=owner.id, name=owner.name)


# ── Document upload ────────────────────────────────────────────────────────────

@router.post("/documents/upload")
async def upload_document(
    file: UploadFile = File(...),
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")

    contents = await file.read()
    ext = os.path.splitext(file.filename or "doc")[1] or ".jpg"
    key = f"kyc/{owner_id}/{uuid.uuid4()}{ext}"

    if S3_BUCKET:
        import boto3
        s3 = boto3.client("s3")
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=contents,
            ContentType=file.content_type or "application/octet-stream",
        )
        doc_url = f"https://{S3_BUCKET}.s3.amazonaws.com/{key}"
    else:
        doc_url = f"pending-upload/{key}"

    owner.doc_url = doc_url
    db.commit()
    return {"doc_url": doc_url, "message": "Document uploaded successfully."}


# ── Owner profile ──────────────────────────────────────────────────────────────

@router.get("/me")
def owner_me(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    restaurant = owner.restaurants[0] if owner.restaurants else None
    return {
        "id": owner.id,
        "name": owner.name,
        "mobile": owner.mobile,
        "gstin": owner.gstin,
        "status": owner.status,
        "rejection_reason": owner.rejection_reason,
        "doc_url": owner.doc_url,
        "restaurant": {
            "id": restaurant.id,
            "name": restaurant.name,
            "restaurant_code": restaurant.restaurant_code,
            "status": restaurant.status,
        } if restaurant else None,
    }
