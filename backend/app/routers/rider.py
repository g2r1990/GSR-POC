import os
import random
import time
import logging
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import Rider, Restaurant
from app.core.security import create_access_token, decode_token

router = APIRouter(prefix="/rider", tags=["Rider"])
bearer = HTTPBearer()
logger = logging.getLogger(__name__)

# In-memory OTP store (same pattern as customer)
_otp_store: dict = {}
_OTP_TTL = 600  # 10 minutes


def _get_rider(credentials: HTTPAuthorizationCredentials, db: Session) -> Rider:
    payload = decode_token(credentials.credentials)
    if not payload or payload.get("role") != "rider":
        raise HTTPException(status_code=401, detail="Invalid rider token.")
    rider = db.query(Rider).filter(Rider.id == payload["sub"]).first()
    if not rider or rider.approval_status != "active":
        raise HTTPException(status_code=403, detail="Rider account not active.")
    if getattr(rider, 'deleted_at', None) is not None:
        raise HTTPException(status_code=403, detail="Rider account has been removed.")
    return rider


# ── Public: Restaurant list (for registration dropdown) ───────────────────────

@router.get("/restaurants")
def list_restaurants(db: Session = Depends(get_db)):
    restaurants = db.query(Restaurant).filter(Restaurant.status == "active").all()
    return [{"id": r.id, "name": r.name, "area": r.area} for r in restaurants]


# ── Public: Registration ───────────────────────────────────────────────────────

@router.post("/register")
def register_rider(body: dict, db: Session = Depends(get_db)):
    name           = (body.get("name") or "").strip()
    phone          = (body.get("phone") or "").strip()
    restaurant_id  = (body.get("restaurant_id") or "").strip()
    vehicle_number = (body.get("vehicle_number") or "").strip()

    if not all([name, phone, restaurant_id, vehicle_number]):
        raise HTTPException(status_code=400, detail="All fields are required.")

    restaurant = db.query(Restaurant).filter(
        Restaurant.id == restaurant_id,
        Restaurant.status == "active"
    ).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")

    existing = db.query(Rider).filter(Rider.phone == phone).first()
    if existing:
        raise HTTPException(status_code=409, detail="Phone number already registered.")

    from app.models import new_uuid
    rider = Rider(
        id=new_uuid(),
        name=name,
        phone=phone,
        restaurant_id=restaurant_id,
        vehicle_number=vehicle_number,
        approval_status="pending_admin",
    )
    db.add(rider)
    db.commit()
    db.refresh(rider)
    return {
        "message": "Registration submitted. Awaiting admin approval.",
        "rider_id": rider.id,
        "approval_status": rider.approval_status,
    }


@router.get("/registration-status")
def check_registration_status(phone: str, db: Session = Depends(get_db)):
    rider = db.query(Rider).filter(Rider.phone == phone).first()
    if not rider:
        raise HTTPException(status_code=404, detail="No registration found for this number.")
    return {
        "approval_status": rider.approval_status,
        "name": rider.name,
    }


# ── Public: OTP Login (active riders only) ─────────────────────────────────────

@router.post("/send-otp")
def send_otp(body: dict, db: Session = Depends(get_db)):
    phone = (body.get("phone") or "").strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone number required.")

    rider = db.query(Rider).filter(Rider.phone == phone).first()
    if not rider:
        raise HTTPException(status_code=404, detail="No rider registered with this number.")
    if rider.approval_status != "active":
        status_msg = {
            "pending_admin": "Your registration is pending admin review.",
            "pending_owner": "Your registration is pending restaurant owner confirmation.",
            "rejected": "Your registration has been rejected. Please contact support.",
        }.get(rider.approval_status, "Account not active.")
        raise HTTPException(status_code=403, detail=status_msg)

    otp = str(random.randint(100000, 999999))
    _otp_store[phone] = {"otp": otp, "expires": time.time() + _OTP_TTL}
    logger.info("RIDER DEV OTP for %s: %s", phone, otp)
    return {"message": "OTP generated (SMS not configured).", "dev_otp": otp}


@router.post("/verify-otp")
def verify_otp(body: dict, db: Session = Depends(get_db)):
    phone = (body.get("phone") or "").strip()
    otp   = (body.get("otp") or "").strip()

    stored = _otp_store.get(phone)
    if not stored or stored["otp"] != otp or time.time() > stored["expires"]:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP.")

    del _otp_store[phone]

    rider = db.query(Rider).filter(Rider.phone == phone).first()
    if not rider or rider.approval_status != "active":
        raise HTTPException(status_code=403, detail="Rider account not active.")

    token = create_access_token(subject=rider.id, role="rider")
    return {
        "token": token,
        "rider_id": rider.id,
        "name": rider.name,
        "restaurant_id": rider.restaurant_id,
        "restaurant_name": rider.restaurant.name,
    }


# ── Rider: Profile ────────────────────────────────────────────────────────────

@router.get("/profile")
def get_rider_profile(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    rider = _get_rider(credentials, db)
    return {
        "id": rider.id,
        "name": rider.name,
        "phone": rider.phone,
        "vehicle_number": rider.vehicle_number,
        "pending_phone": getattr(rider, 'pending_phone', None),
        "pending_vehicle": getattr(rider, 'pending_vehicle', None),
        "update_status": getattr(rider, 'update_status', None),
        "update_submitted_at": rider.update_submitted_at.isoformat() if getattr(rider, 'update_submitted_at', None) else None,
    }


@router.post("/profile/update-request")
def request_profile_update(
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    from datetime import datetime as _dt
    rider = _get_rider(credentials, db)
    if getattr(rider, 'update_status', None) is not None:
        raise HTTPException(status_code=400, detail="You already have a pending update request.")

    new_phone   = (body.get("phone") or "").strip()
    new_vehicle = (body.get("vehicle_number") or "").strip()

    if not new_phone and not new_vehicle:
        raise HTTPException(status_code=400, detail="Provide at least one field to update.")

    if new_phone and new_phone == rider.phone:
        raise HTTPException(status_code=400, detail="New phone is the same as the current one.")
    if new_vehicle and new_vehicle == rider.vehicle_number:
        raise HTTPException(status_code=400, detail="New vehicle number is the same as the current one.")

    if new_phone:
        existing = db.query(Rider).filter(Rider.phone == new_phone, Rider.id != rider.id).first()
        if existing:
            raise HTTPException(status_code=409, detail="Phone number already in use by another rider.")

    rider.pending_phone   = new_phone or None
    rider.pending_vehicle = new_vehicle or None
    rider.update_status   = "pending_owner"
    rider.update_submitted_at = _dt.utcnow()
    db.commit()
    return {"message": "Update request submitted. Awaiting owner review."}


@router.delete("/profile/update-request")
def cancel_profile_update(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    rider = _get_rider(credentials, db)
    rider.pending_phone   = None
    rider.pending_vehicle = None
    rider.update_status   = None
    rider.update_submitted_at = None
    db.commit()
    return {"message": "Update request cancelled."}


# ── Rider: Home screen data ────────────────────────────────────────────────────

@router.get("/orders/active")
def get_active_orders(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    from app.models import Order
    rider = _get_rider(credentials, db)
    orders = db.query(Order).filter(
        Order.restaurant_id == rider.restaurant_id,
        Order.status == "rider_assigned",
        Order.assigned_rider_id == rider.id,
    ).order_by(Order.updated_at.desc()).all()
    return [_order_dict(o) for o in orders]


@router.get("/orders/history")
def get_order_history(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    from app.models import Order
    rider = _get_rider(credentials, db)
    orders = db.query(Order).filter(
        Order.assigned_rider_id == rider.id,
        Order.status == "delivered",
    ).order_by(Order.updated_at.desc()).limit(50).all()
    return [_order_dict(o) for o in orders]


def _order_dict(o) -> dict:
    snap = o.items_snapshot or {}
    discount = float(snap.get("discount_amount", 0))
    total_food = float(o.total)
    gst = round(total_food * 0.05, 2)
    delivery = 20.0
    return {
        "id": o.id,
        "status": o.status,
        "customer_name": o.customer_name,
        "customer_mobile": o.customer_mobile,
        "delivery_address": o.delivery_address,
        "delivery_lat": o.delivery_lat,
        "delivery_lng": o.delivery_lng,
        "customer_area": o.customer_area,
        "total_food_cost": total_food,
        "discount_amount": discount,
        "gst": gst,
        "delivery_fee": delivery,
        "customer_paid": round(total_food + gst + delivery, 2),
        "items": snap.get("items", []),
        "delivery_pin": o.delivery_pin,
        "created_at": o.created_at.isoformat() if o.created_at else None,
        "updated_at": o.updated_at.isoformat() if o.updated_at else None,
    }


# ── Rider: Confirm delivery with PIN ──────────────────────────────────────────

@router.post("/orders/{order_id}/deliver")
def confirm_delivery(
    order_id: str,
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    from app.models import Order
    rider = _get_rider(credentials, db)
    order = db.query(Order).filter(
        Order.id == order_id,
        Order.assigned_rider_id == rider.id,
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")
    if order.status != "rider_assigned":
        raise HTTPException(status_code=400, detail="Order is not in rider_assigned state.")

    pin_entered = (body.get("delivery_pin") or "").strip()
    if not pin_entered or pin_entered != order.delivery_pin:
        raise HTTPException(status_code=400, detail="Incorrect delivery PIN.")

    order.status = "delivered"
    from datetime import datetime
    order.updated_at = datetime.utcnow()
    # Clear rider location when delivery is done
    rider.current_lat = None
    rider.current_lng = None
    rider.location_updated_at = None
    db.commit()
    return {"message": "Delivery confirmed. Order marked as delivered."}


# ── Rider: Live location update ────────────────────────────────────────────────

@router.post("/location")
def update_rider_location(
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    from datetime import datetime
    from app.models import Order
    rider = _get_rider(credentials, db)
    lat = body.get("lat")
    lng = body.get("lng")
    if lat is None or lng is None:
        raise HTTPException(status_code=400, detail="lat and lng are required.")
    # Only accept location when rider has an active delivery
    active = db.query(Order).filter(
        Order.assigned_rider_id == rider.id,
        Order.status == "rider_assigned",
    ).first()
    if not active:
        raise HTTPException(status_code=400, detail="No active delivery.")
    rider.current_lat = float(lat)
    rider.current_lng = float(lng)
    rider.location_updated_at = datetime.utcnow()
    db.commit()
    return {"ok": True}
