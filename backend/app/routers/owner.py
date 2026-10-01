import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError

from app.database import get_db
from app.models import Owner, Restaurant
from app.core.security import decode_token, hash_password
from app.schemas.owner import OwnerRegisterRequest, OwnerRegisterResponse

router = APIRouter(prefix="/owner", tags=["Owner"])
bearer = HTTPBearer()

S3_BUCKET = os.getenv("S3_BUCKET_NAME", "")


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
        password_hash=None,   # Firebase-only login; no password needed
        status="pending",
    )
    db.add(owner)
    db.flush()   # get owner.id before committing

    restaurant = Restaurant(
        owner_id=owner.id,
        name=body.restaurant_name,
        address=body.address,
        area=body.area,
        pincode=body.pincode,
        food_type=body.food_type,
        status="pending",
    )
    db.add(restaurant)
    db.commit()
    db.refresh(owner)

    return OwnerRegisterResponse(owner_id=owner.id)


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
        # S3 not configured — acknowledge receipt without storing
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
            "status": restaurant.status,
        } if restaurant else None,
    }
