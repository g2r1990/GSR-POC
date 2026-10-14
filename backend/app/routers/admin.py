from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError
from typing import List

from app.database import get_db
from app.models import Owner, Restaurant, Inspection, Rider
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
            "email": o.email,
            "mobile": o.mobile,
            "restaurant_name": restaurant.name if restaurant else None,
            "area": restaurant.area if restaurant else None,
            "address": restaurant.address if restaurant else None,
            "food_type": restaurant.food_type if restaurant else None,
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


# ── Rider Management ───────────────────────────────────────────────────────────

@router.get("/riders")
def list_riders(
    status: str = None,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    q = db.query(Rider)
    if status:
        q = q.filter(Rider.approval_status == status)
    riders = q.order_by(Rider.created_at.desc()).all()
    return [_rider_dict(r) for r in riders]


@router.patch("/riders/{rider_id}/approve")
def approve_rider(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    rider = db.query(Rider).filter(Rider.id == rider_id).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    if rider.approval_status != "pending_admin":
        raise HTTPException(status_code=400, detail=f"Rider is in status '{rider.approval_status}', not pending_admin.")
    rider.approval_status = "pending_owner"
    db.commit()
    return {"message": "Rider approved by admin. Awaiting restaurant owner confirmation.", "approval_status": "pending_owner"}


@router.patch("/riders/{rider_id}/reject")
def reject_rider(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    rider = db.query(Rider).filter(Rider.id == rider_id).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    rider.approval_status = "rejected"
    db.commit()
    return {"message": "Rider registration rejected.", "approval_status": "rejected"}


@router.get("/riders/deletion-requests")
def get_deletion_requests(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    riders = db.query(Rider).filter(
        Rider.deletion_requested == True,
        Rider.deleted_at == None,
    ).order_by(Rider.created_at.desc()).all()
    return [_rider_dict(r) for r in riders]


@router.patch("/riders/{rider_id}/approve-deletion")
def approve_rider_deletion(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    import datetime as _dt
    _require_admin(credentials)
    rider = db.get(Rider, rider_id)
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    rider.deleted_at = _dt.datetime.utcnow()
    rider.deletion_requested = False
    rider.approval_status = "rejected"
    db.commit()
    return {"message": f"Rider '{rider.name}' has been removed."}


@router.patch("/riders/{rider_id}/reject-deletion")
def reject_rider_deletion(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    rider = db.get(Rider, rider_id)
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    rider.deletion_requested = False
    db.commit()
    return {"message": "Deletion request rejected. Rider remains active."}


# ── Admin: Rider Update Requests ──────────────────────────────────────────────

@router.get("/rider-updates")
def get_rider_update_requests(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    riders = db.query(Rider).filter(
        Rider.update_status == "pending_admin",
    ).order_by(Rider.update_submitted_at.asc()).all()
    return [_rider_dict(r) for r in riders]


@router.patch("/rider-updates/{rider_id}/approve")
def approve_rider_update(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    rider = db.get(Rider, rider_id)
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    if getattr(rider, 'update_status', None) != "pending_admin":
        raise HTTPException(status_code=400, detail="No pending admin-level update request.")

    if rider.pending_phone:
        existing = db.query(Rider).filter(
            Rider.phone == rider.pending_phone, Rider.id != rider.id
        ).first()
        if existing:
            raise HTTPException(status_code=409, detail="Phone already used by another rider.")
        rider.phone = rider.pending_phone

    if rider.pending_vehicle:
        rider.vehicle_number = rider.pending_vehicle

    rider.pending_phone   = None
    rider.pending_vehicle = None
    rider.update_status   = None
    rider.update_submitted_at = None
    db.commit()
    return {"message": f"Rider '{rider.name}' profile updated successfully."}


@router.patch("/rider-updates/{rider_id}/reject")
def reject_rider_update(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    _require_admin(credentials)
    rider = db.get(Rider, rider_id)
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    rider.pending_phone   = None
    rider.pending_vehicle = None
    rider.update_status   = None
    rider.update_submitted_at = None
    db.commit()
    return {"message": "Update request rejected."}


def _rider_dict(r: Rider) -> dict:
    return {
        "id": r.id,
        "name": r.name,
        "phone": r.phone,
        "vehicle_number": r.vehicle_number,
        "approval_status": r.approval_status,
        "deletion_requested": getattr(r, 'deletion_requested', False) or False,
        "pending_phone": getattr(r, 'pending_phone', None),
        "pending_vehicle": getattr(r, 'pending_vehicle', None),
        "update_status": getattr(r, 'update_status', None),
        "update_submitted_at": r.update_submitted_at.isoformat() if getattr(r, 'update_submitted_at', None) else None,
        "restaurant_id": r.restaurant_id,
        "restaurant_name": r.restaurant.name if r.restaurant else None,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }
