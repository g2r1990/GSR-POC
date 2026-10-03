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


# ── Owner profile update requests ──────────────────────────────────────────────

@router.get("/profile-update-requests")
def list_profile_update_requests(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    import json as _json
    _require_admin(credentials)
    owners = (
        db.query(Owner)
        .filter(Owner.pending_profile_update.isnot(None))
        .order_by(Owner.pending_update_submitted_at.asc())
        .all()
    )
    result = []
    for o in owners:
        restaurant = o.restaurants[0] if o.restaurants else None
        result.append({
            "owner_id": o.id,
            "owner_name": o.name,
            "mobile": o.mobile,
            "restaurant_name": restaurant.name if restaurant else None,
            "submitted_at": o.pending_update_submitted_at.isoformat() if o.pending_update_submitted_at else None,
            "requested_changes": _json.loads(o.pending_profile_update),
        })
    return result


@router.post("/profile-update-requests/{owner_id}/approve")
def approve_profile_update(
    owner_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    import json as _json
    _require_admin(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    if not owner.pending_profile_update:
        raise HTTPException(status_code=400, detail="No pending update request")
    changes = _json.loads(owner.pending_profile_update)
    if 'owner_name' in changes:
        owner.name = changes['owner_name']
    if 'email' in changes:
        owner.email = changes['email']
    restaurant = owner.restaurants[0] if owner.restaurants else None
    if restaurant:
        if 'restaurant_name' in changes:
            restaurant.name = changes['restaurant_name']
        if 'area' in changes:
            restaurant.area = changes['area']
        if 'address' in changes:
            restaurant.address = changes['address']
        if 'food_type' in changes:
            restaurant.food_type = changes['food_type']
    owner.pending_profile_update = None
    owner.pending_update_submitted_at = None
    db.commit()
    return {"message": "Profile update approved and applied."}


@router.post("/profile-update-requests/{owner_id}/reject")
def reject_profile_update(
    owner_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    owner.pending_profile_update = None
    owner.pending_update_submitted_at = None
    db.commit()
    return {"message": "Profile update request rejected."}
