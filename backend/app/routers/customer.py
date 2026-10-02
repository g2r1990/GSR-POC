import os
import random
import time
import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import Restaurant, MenuItem
from app.schemas.customer import RestaurantResponse, CustomerMenuItemResponse

router = APIRouter(prefix="/customer", tags=["Customer"])

logger = logging.getLogger(__name__)

# In-memory OTP store: {mobile: {'otp': str, 'expires': float}}
_otp_store: dict = {}
_OTP_TTL = 600  # 10 minutes


def _send_otp_sms(mobile: str, otp: str) -> bool:
    """Try to send OTP via Fast2SMS. Returns True if sent, False if not configured."""
    api_key = os.getenv("FAST2SMS_API_KEY")
    if not api_key:
        return False
    try:
        import urllib.request
        import json as _json
        payload = _json.dumps({
            "route": "otp",
            "variables_values": otp,
            "numbers": mobile,
        }).encode()
        req = urllib.request.Request(
            "https://www.fast2sms.com/dev/bulkV2",
            data=payload,
            headers={
                "authorization": api_key,
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            result = _json.loads(resp.read())
            return result.get("return", False)
    except Exception as exc:
        logger.warning("Fast2SMS send failed: %s", exc)
        return False


@router.get("/restaurants", response_model=List[RestaurantResponse])
def search_restaurants(pincode: str, db: Session = Depends(get_db)):
    """Search active restaurants within the same city area (first 5 pincode digits). No auth required."""
    # Match first 5 digits so nearby pincodes in the same city area are included.
    prefix = pincode[:5] if len(pincode) >= 5 else pincode
    restaurants = (
        db.query(Restaurant)
        .filter(Restaurant.pincode.like(prefix + "%"), Restaurant.status == "active")
        .order_by(Restaurant.name)
        .all()
    )
    return restaurants


@router.get("/restaurant/{restaurant_id}/menu")
def get_restaurant_menu(restaurant_id: str, db: Session = Depends(get_db)):
    """
    Return restaurant info + available menu items grouped by category.
    No auth required. Only is_available=True items are shown.
    """
    restaurant = (
        db.query(Restaurant)
        .filter(Restaurant.id == restaurant_id, Restaurant.status == "active")
        .first()
    )
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")

    items = (
        db.query(MenuItem)
        .filter(
            MenuItem.restaurant_id == restaurant_id,
            MenuItem.is_available == True,
            MenuItem.is_deleted == False,
        )
        .order_by(MenuItem.category, MenuItem.name)
        .all()
    )

    grouped: dict[str, list] = {}
    for item in items:
        cat = item.category
        if cat not in grouped:
            grouped[cat] = []
        grouped[cat].append(CustomerMenuItemResponse.model_validate(item))

    return {
        "restaurant": RestaurantResponse.model_validate(restaurant),
        "menu": grouped,
    }


@router.get("/orders")
def customer_order_history(mobile: str, db: Session = Depends(get_db)):
    """Return all orders placed from a mobile number, newest first. No auth required."""
    from app.models import Order as OrderModel
    if len(mobile) != 10 or not mobile.isdigit():
        raise HTTPException(status_code=400, detail="Enter a valid 10-digit mobile number.")
    orders = (
        db.query(OrderModel)
        .filter(OrderModel.customer_mobile == mobile)
        .order_by(OrderModel.created_at.desc())
        .all()
    )
    return [
        {
            "order_id": o.id,
            "short_id": o.id[:8].upper(),
            "status": o.status,
            "total": float(o.total),
            "restaurant_name": o.restaurant.name if o.restaurant else "",
            "items_count": len((o.items_snapshot or {}).get("items", [])),
            "created_at": o.created_at.isoformat() if o.created_at else None,
            "delivery_address": o.delivery_address or "",
        }
        for o in orders
    ]


@router.post("/send-otp")
def send_otp(mobile: str):
    """Generate and send OTP to the given mobile number. No auth required."""
    if len(mobile) != 10 or not mobile.isdigit():
        raise HTTPException(status_code=400, detail="Enter a valid 10-digit mobile number.")

    otp = str(random.randint(100000, 999999))
    _otp_store[mobile] = {"otp": otp, "expires": time.time() + _OTP_TTL}

    sms_sent = _send_otp_sms(mobile, otp)

    if sms_sent:
        logger.info("OTP sent via SMS to %s", mobile)
        return {"message": "OTP sent to your mobile number."}
    else:
        # Dev mode: log and return OTP in response so testing works without SMS credits
        logger.info("DEV MODE — OTP for %s: %s", mobile, otp)
        return {"message": "OTP generated (SMS not configured).", "dev_otp": otp}


@router.post("/verify-otp")
def verify_otp(mobile: str, otp: str):
    """Verify the OTP for a mobile number. Returns 200 on success, 400 on failure."""
    record = _otp_store.get(mobile)
    if not record:
        raise HTTPException(status_code=400, detail="OTP not found. Please request a new one.")
    if time.time() > record["expires"]:
        _otp_store.pop(mobile, None)
        raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")
    if record["otp"] != otp:
        raise HTTPException(status_code=400, detail="Incorrect OTP. Please try again.")

    _otp_store.pop(mobile, None)
    return {"verified": True, "message": "Mobile number verified successfully."}
