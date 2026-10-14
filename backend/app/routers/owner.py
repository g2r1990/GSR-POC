import os
import uuid
import random
import string
import json as _json
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError

from app.database import get_db
from datetime import datetime as _dt
from app.models import Owner, Restaurant, Offer, NotificationRequest, CustomerNotification, Order, Rider
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


def _generate_offer_code(restaurant_name: str, db: Session) -> str:
    prefix = ''.join(c.upper() for c in restaurant_name if c.isalpha())[:4].ljust(4, 'X')
    for _ in range(10):
        code = prefix + ''.join(random.choices(string.digits, k=4))
        if not db.query(Offer).filter(Offer.offer_code == code).first():
            return code
    return prefix + ''.join(random.choices(string.digits, k=4))


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


# ── Offers ─────────────────────────────────────────────────────────────────────

@router.post("/offers", status_code=201)
def create_offer(
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner or not owner.restaurants:
        raise HTTPException(status_code=404, detail="No restaurant found for this owner.")
    restaurant = owner.restaurants[0]
    if not body.get("title"):
        raise HTTPException(status_code=422, detail="title is required.")
    valid_until = None
    if body.get("valid_until"):
        try:
            valid_until = _dt.fromisoformat(body["valid_until"])
        except ValueError:
            pass
    offer_type = body.get("offer_type", "order")
    if offer_type not in ("order", "item", "bogo"):
        offer_type = "order"
    offer_code = _generate_offer_code(restaurant.name, db)
    offer = Offer(
        restaurant_id=restaurant.id,
        title=body["title"],
        description=body.get("description"),
        offer_type=offer_type,
        offer_code=offer_code,
        discount_pct=body.get("discount_pct"),
        menu_item_id=body.get("menu_item_id"),
        menu_item_name=body.get("menu_item_name"),
        buy_qty=body.get("buy_qty"),
        free_qty=body.get("free_qty"),
        valid_until=valid_until,
        is_active=True,
    )
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return {"id": offer.id, "title": offer.title, "offer_code": offer.offer_code, "message": "Offer created."}


@router.get("/offers")
def get_owner_offers(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner or not owner.restaurants:
        return []
    restaurant = owner.restaurants[0]
    offers = (
        db.query(Offer)
        .filter(Offer.restaurant_id == restaurant.id)
        .order_by(Offer.created_at.desc())
        .all()
    )
    return [
        {
            "id": o.id,
            "title": o.title,
            "description": o.description,
            "offer_type": o.offer_type or "order",
            "discount_pct": float(o.discount_pct) if o.discount_pct else None,
            "menu_item_id": o.menu_item_id,
            "menu_item_name": o.menu_item_name,
            "buy_qty": o.buy_qty,
            "free_qty": o.free_qty,
            "valid_until": o.valid_until.isoformat() if o.valid_until else None,
            "offer_code": o.offer_code,
            "is_active": o.is_active,
            "created_at": o.created_at.isoformat(),
        }
        for o in offers
    ]


@router.delete("/offers/{offer_id}")
def delete_offer(
    offer_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner or not owner.restaurants:
        raise HTTPException(status_code=404, detail="Not found.")
    restaurant = owner.restaurants[0]
    offer = db.query(Offer).filter(
        Offer.id == offer_id, Offer.restaurant_id == restaurant.id
    ).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found.")
    db.delete(offer)
    db.commit()
    return {"message": "Offer deleted."}


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


@router.get("/profile")
def get_owner_profile(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    restaurant = owner.restaurants[0] if owner.restaurants else None
    return {
        "id": owner.id,
        "name": owner.name,
        "mobile": owner.mobile,
        "email": owner.email,
        "gstin": owner.gstin,
        "restaurant": {
            "id": restaurant.id,
            "name": restaurant.name,
            "area": restaurant.area,
            "address": restaurant.address,
            "pincode": restaurant.pincode,
            "state": restaurant.state,
            "food_type": restaurant.food_type,
            "restaurant_code": restaurant.restaurant_code,
        } if restaurant else None,
        "pending_update": _json.loads(owner.pending_profile_update) if owner.pending_profile_update else None,
        "pending_update_submitted_at": owner.pending_update_submitted_at.isoformat() if owner.pending_update_submitted_at else None,
    }


@router.post("/profile/update-request")
def request_profile_update(
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    owner.pending_profile_update = _json.dumps(body)
    owner.pending_update_submitted_at = _dt.utcnow()
    db.commit()
    return {"message": "Update request submitted. Pending admin review."}


@router.delete("/profile/update-request")
def cancel_profile_update(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.query(Owner).filter(Owner.id == owner_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    owner.pending_profile_update = None
    owner.pending_update_submitted_at = None
    db.commit()
    return {"message": "Update request cancelled."}


# ── Business Reports ──────────────────────────────────────────────────────────

@router.get("/reports")
def get_owner_report(
    from_date: str,
    to_date: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    """Daily business report for delivered orders within a date range."""
    from collections import defaultdict

    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")

    try:
        start = _dt.strptime(from_date, "%Y-%m-%d")
        end = _dt.strptime(to_date, "%Y-%m-%d").replace(hour=23, minute=59, second=59)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.")

    orders = (
        db.query(Order)
        .filter(
            Order.restaurant_id == restaurant.id,
            Order.status == "delivered",
            Order.created_at >= start,
            Order.created_at <= end,
        )
        .order_by(Order.created_at)
        .all()
    )

    day_groups: dict = defaultdict(list)
    for order in orders:
        day = order.created_at.date().isoformat()
        day_groups[day].append(order)

    rows = []
    grand = {
        "orders": 0, "item_subtotal": 0.0, "discount": 0.0,
        "total_food_cost": 0.0, "gst": 0.0, "delivery": 0.0,
        "customer_paid": 0.0, "bossbite_fee": 0.0, "restaurant_earnings": 0.0,
    }

    for day in sorted(day_groups.keys()):
        day_orders = day_groups[day]
        d: dict = {
            "date": day, "orders": len(day_orders),
            "item_subtotal": 0.0, "discount": 0.0, "total_food_cost": 0.0,
            "gst": 0.0, "delivery": 0.0, "customer_paid": 0.0,
            "bossbite_fee": 0.0, "restaurant_earnings": 0.0,
        }
        for order in day_orders:
            snapshot = order.items_snapshot or {}
            discount = float(snapshot.get("discount_amount", 0))
            total_food_cost = float(order.total)
            item_subtotal = total_food_cost + discount
            gst = round(total_food_cost * 0.05, 2)
            delivery = 20.0
            customer_paid = round(total_food_cost + gst + delivery, 2)
            bossbite_fee = round(total_food_cost * 0.15, 2)
            restaurant_earnings = round(total_food_cost * 0.85 + delivery, 2)

            d["item_subtotal"] += item_subtotal
            d["discount"] += discount
            d["total_food_cost"] += total_food_cost
            d["gst"] += gst
            d["delivery"] += delivery
            d["customer_paid"] += customer_paid
            d["bossbite_fee"] += bossbite_fee
            d["restaurant_earnings"] += restaurant_earnings

        for k, v in d.items():
            if isinstance(v, float):
                d[k] = round(v, 2)

        rows.append(d)
        grand["orders"] += d["orders"]
        for k in ["item_subtotal", "discount", "total_food_cost", "gst", "delivery",
                  "customer_paid", "bossbite_fee", "restaurant_earnings"]:
            grand[k] = round(grand[k] + d[k], 2)

    return {
        "restaurant_name": restaurant.name,
        "from_date": from_date,
        "to_date": to_date,
        "rows": rows,
        "totals": grand,
    }


# ── Restaurant Availability Toggle ────────────────────────────────────────────

def _fire_back_online_notifications(restaurant_id: str, db: Session):
    """Send SMS + in-app notification to all customers who requested notification, then clear them."""
    requests = db.query(NotificationRequest).filter(
        NotificationRequest.restaurant_id == restaurant_id
    ).all()
    if not requests:
        return
    # Get restaurant name for notification message
    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    restaurant_name = restaurant.name if restaurant else "The restaurant"
    api_key = os.getenv("FAST2SMS_API_KEY", "")
    for req in requests:
        # In-app notification
        db.add(CustomerNotification(
            restaurant_id=restaurant_id,
            restaurant_name=restaurant_name,
            customer_mobile=req.customer_mobile,
            message=f"{restaurant_name} is now accepting orders! Tap to order.",
        ))
        # SMS (optional, silently fails if not configured)
        if api_key:
            try:
                import urllib.request as _urllib
                import json as _json_mod
                payload = _json_mod.dumps({
                    "route": "dlt",
                    "sender_id": "BOSSBT",
                    "message": "Great news! The restaurant you were waiting for is now accepting orders on BossBite. Open the app and order now!",
                    "variables_values": "",
                    "numbers": req.customer_mobile,
                }).encode()
                r = _urllib.Request(
                    "https://www.fast2sms.com/dev/bulkV2",
                    data=payload,
                    headers={"authorization": api_key, "Content-Type": "application/json"},
                )
                _urllib.urlopen(r, timeout=5)
            except Exception:
                pass
    db.query(NotificationRequest).filter(
        NotificationRequest.restaurant_id == restaurant_id
    ).delete()
    db.commit()


@router.patch("/restaurant/availability")
def set_restaurant_availability(
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    """Toggle restaurant open/closed. body: {is_accepting_orders: bool, back_online_at: str|null}"""
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")
    if restaurant.status != "active":
        raise HTTPException(status_code=403, detail="Restaurant is not active.")

    was_accepting = bool(restaurant.is_accepting_orders)
    restaurant.is_accepting_orders = bool(body.get("is_accepting_orders", True))
    raw_time = body.get("back_online_at")
    if raw_time:
        try:
            restaurant.back_online_at = _dt.fromisoformat(raw_time.replace("Z", "+00:00")).replace(tzinfo=None)
        except (ValueError, AttributeError):
            restaurant.back_online_at = None
    else:
        restaurant.back_online_at = None
    db.commit()

    if not was_accepting and restaurant.is_accepting_orders:
        _fire_back_online_notifications(restaurant.id, db)

    return {
        "is_accepting_orders": restaurant.is_accepting_orders,
        "back_online_at": restaurant.back_online_at.isoformat() if restaurant.back_online_at else None,
    }


@router.get("/restaurant/availability")
def get_restaurant_availability(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    """Return current availability status for the owner's restaurant."""
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")
    return {
        "is_accepting_orders": restaurant.is_accepting_orders if restaurant.is_accepting_orders is not None else True,
        "back_online_at": restaurant.back_online_at.isoformat() if restaurant.back_online_at else None,
    }


# ── Rider Management ───────────────────────────────────────────────────────────

@router.get("/riders/pending")
def get_pending_riders(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")
    riders = db.query(Rider).filter(
        Rider.restaurant_id == restaurant.id,
        Rider.approval_status == "pending_owner",
    ).order_by(Rider.created_at.asc()).all()
    return [_rider_dict(r) for r in riders]


@router.get("/riders")
def get_active_riders(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")
    riders = db.query(Rider).filter(
        Rider.restaurant_id == restaurant.id,
        Rider.approval_status == "active",
    ).order_by(Rider.name.asc()).all()
    return [_rider_dict(r) for r in riders]


@router.patch("/riders/{rider_id}/confirm")
def confirm_rider(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")
    rider = db.query(Rider).filter(
        Rider.id == rider_id,
        Rider.restaurant_id == restaurant.id,
    ).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    if rider.approval_status != "pending_owner":
        raise HTTPException(status_code=400, detail=f"Rider is in status '{rider.approval_status}', not pending_owner.")
    rider.approval_status = "active"
    db.commit()
    return {"message": "Rider confirmed and activated.", "approval_status": "active"}


@router.patch("/riders/{rider_id}/reject")
def reject_rider(
    rider_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")
    rider = db.query(Rider).filter(
        Rider.id == rider_id,
        Rider.restaurant_id == restaurant.id,
    ).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found.")
    rider.approval_status = "rejected"
    db.commit()
    return {"message": "Rider rejected.", "approval_status": "rejected"}


# ── Assign Rider to Order ──────────────────────────────────────────────────────

@router.patch("/orders/{order_id}/assign-rider")
def assign_rider(
    order_id: str,
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == owner_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")

    order = db.query(Order).filter(
        Order.id == order_id,
        Order.restaurant_id == restaurant.id,
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")
    if order.status != "ready":
        raise HTTPException(status_code=400, detail="Order must be in 'ready' status to assign a rider.")

    rider_id = (body.get("rider_id") or "").strip()
    rider = db.query(Rider).filter(
        Rider.id == rider_id,
        Rider.restaurant_id == restaurant.id,
        Rider.approval_status == "active",
    ).first()
    if not rider:
        raise HTTPException(status_code=404, detail="Active rider not found for this restaurant.")

    order.assigned_rider_id = rider_id
    order.status = "rider_assigned"
    order.updated_at = _dt.utcnow()
    db.commit()
    return {
        "message": f"Rider {rider.name} assigned to order.",
        "order_id": order_id,
        "rider_name": rider.name,
        "status": "rider_assigned",
    }


def _rider_dict(r: Rider) -> dict:
    return {
        "id": r.id,
        "name": r.name,
        "phone": r.phone,
        "vehicle_number": r.vehicle_number,
        "approval_status": r.approval_status,
        "restaurant_id": r.restaurant_id,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }
