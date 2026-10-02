from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError
from typing import List

from app.database import get_db
from app.models import Owner, Restaurant, Inspection
from app.core.security import decode_token
from app.schemas.owner import KycItemResponse, KycRestaurantInfo, RejectRequest

router = APIRouter(prefix="/admin", tags=["Admin"])
bearer = HTTPBearer()


def _require_admin(credentials: HTTPAuthorizationCredentials) -> dict:
    try:
        payload = decode_token(credentials.credentials)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    if payload.get("role") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Requires admin role")
    return payload


# ── KYC: pending list ──────────────────────────────────────────────────────────

@router.get("/kyc/pending", response_model=List[KycItemResponse])
def kyc_pending(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    owners = (
        db.query(Owner)
        .filter(Owner.status == "pending")
        .order_by(Owner.created_at.asc())
        .all()
    )
    result = []
    for o in owners:
        restaurant = o.restaurants[0] if o.restaurants else None
        result.append(KycItemResponse(
            id=o.id,
            name=o.name,
            mobile=o.mobile,
            gstin=o.gstin,
            doc_url=o.doc_url,
            status=o.status,
            created_at=o.created_at,
            restaurant=KycRestaurantInfo(
                id=restaurant.id,
                name=restaurant.name,
                address=restaurant.address,
                area=restaurant.area,
                pincode=restaurant.pincode,
                state=restaurant.state,
                restaurant_code=restaurant.restaurant_code,
                food_type=restaurant.food_type,
            ) if restaurant else None,
        ))
    return result


# ── KYC: approve ──────────────────────────────────────────────────────────────

@router.post("/kyc/{owner_id}/approve")
def kyc_approve(
    owner_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    if owner.status == "active":
        raise HTTPException(status_code=400, detail="Owner is already active")

    owner.status = "active"
    owner.rejection_reason = None

    for restaurant in owner.restaurants:
        restaurant.status = "active"

    db.commit()
    return {"message": f"Owner '{owner.name}' approved. Restaurant(s) are now active."}


# ── KYC: reject ───────────────────────────────────────────────────────────────

@router.post("/kyc/{owner_id}/reject")
def kyc_reject(
    owner_id: str,
    body: RejectRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")

    owner.status = "rejected"
    owner.rejection_reason = body.reason

    for restaurant in owner.restaurants:
        restaurant.status = "suspended"

    db.commit()
    return {"message": f"Owner '{owner.name}' rejected.", "reason": body.reason}


# ── KYC: all owners (for admin view) ──────────────────────────────────────────

@router.get("/kyc/all", response_model=List[KycItemResponse])
def kyc_all(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    owners = db.query(Owner).order_by(Owner.created_at.desc()).all()
    result = []
    for o in owners:
        restaurant = o.restaurants[0] if o.restaurants else None
        result.append(KycItemResponse(
            id=o.id,
            name=o.name,
            mobile=o.mobile,
            gstin=o.gstin,
            doc_url=o.doc_url,
            status=o.status,
            created_at=o.created_at,
            restaurant=KycRestaurantInfo(
                id=restaurant.id,
                name=restaurant.name,
                address=restaurant.address,
                area=restaurant.area,
                pincode=restaurant.pincode,
                state=restaurant.state,
                restaurant_code=restaurant.restaurant_code,
                food_type=restaurant.food_type,
            ) if restaurant else None,
        ))
    return result
