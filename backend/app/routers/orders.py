import random
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError
from typing import List

from app.database import get_db
from app.models import Owner, Restaurant, MenuItem, Order, CustomerNotification
from app.core.security import decode_token
from app.core.fcm import send_new_order_notification
from app.schemas.order import (
    PlaceOrderRequest, OrderStatusUpdate, OrderResponse, OrderItemSnapshot,
)

router = APIRouter(prefix="/orders", tags=["Orders"])
bearer = HTTPBearer()

_VALID_TRANSITIONS = {
    # delivery flow
    "placed":           {"accepted", "cancelled"},
    "accepted":         {"ready", "cancelled"},
    "ready":            {"rider_assigned", "ready_for_pickup"},
    "rider_assigned":   {"out_for_delivery"},
    "out_for_delivery": {"delivered"},
    "delivered":        set(),
    # takeaway flow
    "ready_for_pickup": {"collected", "cancelled"},
    "collected":        set(),
    "cancelled":        set(),
}

DELIVERY_FEE        = 20.00  # flat fee; replace with distance-based later
CANCEL_WINDOW_SECS  = 15    # customer cancel window (aligned with owner accept-lock)
DELIVERY_PIN_DIGITS = 6     # PIN length — must match rider dialog in Flutter


def _get_owner_id(credentials: HTTPAuthorizationCredentials) -> str:
    try:
        payload = decode_token(credentials.credentials)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")
    if payload.get("role") != "owner":
        raise HTTPException(status_code=403, detail="Requires owner role.")
    return payload["sub"]


def _order_to_response(order: Order) -> OrderResponse:
    snapshot = order.items_snapshot or {}
    raw_items = snapshot.get("items", [])
    items = []
    for i in raw_items:
        items.append(OrderItemSnapshot(
            item_id=i.get("item_id", ""),
            name=i.get("name", ""),
            category=i.get("category", ""),
            price=float(i.get("price", 0)),
            qty=int(i.get("qty", 1)),
            subtotal=float(i.get("subtotal", 0)),
            spice_level=i.get("spice_level"),
            item_notes=i.get("item_notes"),
        ))
    food_total     = float(order.food_total or order.total or 0)
    customer_pays  = float(order.customer_pays or order.total or 0)
    return OrderResponse(
        id=order.id,
        short_id=order.id[:8].upper(),
        restaurant_id=order.restaurant_id,
        customer_name=order.customer_name or "",
        customer_phone=order.customer_mobile or "",
        customer_area=order.customer_area,
        order_type=getattr(order, "order_type", "delivery") or "delivery",
        delivery_address=order.delivery_address or "",
        items=items,
        food_total=food_total,
        restaurant_discount=float(getattr(order, "restaurant_discount", 0) or 0),
        bossbite_discount=float(getattr(order, "bossbite_discount", 0) or 0),
        taxable_amount=float(getattr(order, "taxable_amount", food_total) or food_total),
        gst_rate=float(getattr(order, "gst_rate", 0) or 0),
        gst_amount=float(getattr(order, "gst_amount", 0) or 0),
        delivery_fee=float(getattr(order, "delivery_fee", 0) or 0),
        cutlery_fee_amt=float(getattr(order, "cutlery_fee_amt", 0) or 0),
        rider_tip=float(getattr(order, "rider_tip", 0) or 0),
        cod_convenience_fee=float(getattr(order, "cod_convenience_fee", 0) or 0),
        customer_pays=customer_pays,
        total=float(order.total),
        discount_amount=float(snapshot.get("discount_amount", 0)),
        offer_code=snapshot.get("offer_code", ""),
        payment_method=getattr(order, "payment_method", "online") or "online",
        payment_status=getattr(order, "payment_status", "pending") or "pending",
        spice_level=getattr(order, "spice_level", None),
        special_instructions=getattr(order, "special_instructions", None),
        cutlery_requested=bool(getattr(order, "cutlery_requested", False)),
        status=order.status,
        notes=order.notes,
        delivery_pin=order.delivery_pin,
        pickup_code=getattr(order, "pickup_code", None),
        assigned_rider_id=order.assigned_rider_id,
        rating=order.rating,
        rating_comment=order.rating_comment,
        created_at=order.created_at,
    )


# ── Customer: place an order (public, no auth) ────────────────────────────────

@router.post("", status_code=201)
def place_order(body: PlaceOrderRequest, db: Session = Depends(get_db)):
    restaurant = (
        db.query(Restaurant)
        .filter(Restaurant.id == body.restaurant_id, Restaurant.status == "active")
        .first()
    )
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found.")

    if not getattr(restaurant, "is_accepting_orders", True):
        raise HTTPException(status_code=400, detail="This restaurant is not currently accepting orders.")

    if getattr(restaurant, "closed_until", None) and restaurant.closed_until > datetime.utcnow():
        raise HTTPException(status_code=400, detail="This restaurant is temporarily closed.")

    order_type = body.order_type if body.order_type in ("delivery", "takeaway") else "delivery"

    if order_type == "delivery" and not body.delivery_address:
        raise HTTPException(status_code=400, detail="delivery_address is required for delivery orders.")
    if order_type == "takeaway" and not getattr(restaurant, "allows_takeaway", False):
        raise HTTPException(status_code=400, detail="This restaurant does not offer takeaway.")

    payment_method = body.payment_method if body.payment_method in ("online", "cod") else "online"
    if payment_method == "cod" and not getattr(restaurant, "cod_enabled", True):
        raise HTTPException(status_code=400, detail="Cash on delivery is not available at this restaurant.")

    if not body.items:
        raise HTTPException(status_code=400, detail="Order must have at least one item.")

    # idempotency guard
    if body.idempotency_key:
        existing = db.query(Order).filter(Order.idempotency_key == body.idempotency_key).first()
        if existing:
            return {
                "order_id": existing.id,
                "short_id": existing.id[:8].upper(),
                "customer_pays": float(existing.customer_pays or existing.total),
                "total": float(existing.total),
                "status": existing.status,
                "delivery_pin": existing.delivery_pin,
                "pickup_code": existing.pickup_code,
                "created_at": existing.created_at.isoformat(),
                "message": "Duplicate request — returning existing order.",
            }

    # ── Build items snapshot ────────────────────────────────────────────────────
    snapshot_items = []
    food_total = 0.0

    for line in body.items:
        if line.qty < 1:
            continue
        item = (
            db.query(MenuItem)
            .filter(
                MenuItem.id == line.item_id,
                MenuItem.restaurant_id == body.restaurant_id,
                MenuItem.is_available == True,
                MenuItem.is_deleted == False,
            )
            .first()
        )
        if not item:
            raise HTTPException(status_code=400, detail=f"Item {line.item_id} is not available.")
        price = float(item.price)
        subtotal = round(price * line.qty, 2)
        food_total += subtotal
        snapshot_items.append({
            "item_id": item.id,
            "name": item.name,
            "category": item.category,
            "price": price,
            "qty": line.qty,
            "subtotal": subtotal,
            "spice_level": line.spice_level,
            "item_notes": line.item_notes,
        })

    if not snapshot_items:
        raise HTTPException(status_code=400, detail="No valid items in order.")

    food_total = round(food_total, 2)

    # ── Minimum order check ─────────────────────────────────────────────────────
    min_order = float(getattr(restaurant, "min_order_value", 0) or 0)
    if food_total < min_order:
        raise HTTPException(status_code=400, detail=f"Minimum order value is ₹{min_order:.0f}.")

    # COD max order check
    if payment_method == "cod":
        cod_max = getattr(restaurant, "cod_max_order_value", None)
        if cod_max and food_total > float(cod_max):
            raise HTTPException(status_code=400, detail=f"COD not available for orders above ₹{float(cod_max):.0f}.")

    # ── Legacy offer discount (backward compat) ─────────────────────────────────
    restaurant_discount = 0.0
    bossbite_discount = 0.0

    if body.offer_code:
        from sqlalchemy import text as _text
        already_used = db.execute(
            _text(
                'SELECT id FROM "order" '
                "WHERE customer_mobile = :mobile "
                "  AND status != 'cancelled' "
                "  AND items_snapshot->>'offer_code' = :code "
                "LIMIT 1"
            ),
            {"mobile": body.customer_phone, "code": body.offer_code},
        ).fetchone()
        if already_used:
            raise HTTPException(status_code=400, detail="You have already used this offer code.")
        restaurant_discount = round(min(float(body.discount_amount or 0), food_total), 2)

    # ── Billing formula ─────────────────────────────────────────────────────────
    taxable_amount = round(food_total - restaurant_discount - bossbite_discount, 2)
    taxable_amount = max(taxable_amount, 0)

    gst_rate = 0.0
    gst_amount = 0.0
    delivery_fee = 0.0
    rider_tip = 0.0

    if order_type == "delivery":
        gst_rate = float(getattr(restaurant, "gst_rate", 5) or 5)
        gst_amount = round(taxable_amount * gst_rate / 100, 2)
        delivery_fee = DELIVERY_FEE
        # tip only for online payment
        if payment_method == "online":
            rider_tip = round(max(float(body.rider_tip or 0), 0), 2)
    # takeaway: gst=0, delivery_fee=0, rider_tip=0

    cutlery_fee_amt = 0.0
    if body.cutlery_requested:
        if not getattr(restaurant, "provides_cutlery", False):
            raise HTTPException(status_code=400, detail="This restaurant does not offer cutlery.")
        cutlery_fee_amt = float(getattr(restaurant, "cutlery_fee", 0) or 0)

    customer_pays = round(taxable_amount + gst_amount + delivery_fee + cutlery_fee_amt + rider_tip, 2)

    # ── Generate pin / code ─────────────────────────────────────────────────────
    delivery_pin = str(random.randint(100000, 999999)) if order_type == "delivery" else None
    pickup_code  = str(random.randint(1000, 9999))    if order_type == "takeaway" else None

    from app.models import new_uuid
    order = Order(
        id=new_uuid(),
        idempotency_key=body.idempotency_key or None,
        restaurant_id=body.restaurant_id,
        customer_name=body.customer_name,
        customer_mobile=body.customer_phone,
        customer_area=body.customer_area,
        order_type=order_type,
        delivery_address=body.delivery_address,
        delivery_lat=body.delivery_lat,
        delivery_lng=body.delivery_lng,
        spice_level=body.spice_level,
        special_instructions=body.special_instructions,
        cutlery_requested=body.cutlery_requested,
        notes=body.notes,
        items_snapshot={
            "items": snapshot_items,
            "discount_amount": restaurant_discount + bossbite_discount,
            "offer_code": body.offer_code or "",
        },
        food_total=food_total,
        restaurant_discount=restaurant_discount,
        bossbite_discount=bossbite_discount,
        taxable_amount=taxable_amount,
        gst_rate=gst_rate,
        gst_amount=gst_amount,
        delivery_fee=delivery_fee,
        cutlery_fee_amt=cutlery_fee_amt,
        rider_tip=rider_tip,
        customer_pays=customer_pays,
        total=customer_pays,      # keep total = customer_pays for backward compat
        payment_method=payment_method,
        payment_status="pending",
        delivery_pin=delivery_pin,
        pickup_code=pickup_code,
        status="placed",
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    # Notify owner via FCM (fire and forget)
    owner = restaurant.owner
    if owner and owner.fcm_token:
        send_new_order_notification(owner.fcm_token, order.id[:8].upper(), food_total)

    return {
        "order_id": order.id,
        "short_id": order.id[:8].upper(),
        "order_type": order.order_type,
        "food_total": food_total,
        "gst_amount": gst_amount,
        "delivery_fee": delivery_fee,
        "rider_tip": rider_tip,
        "cutlery_fee": cutlery_fee_amt,
        "customer_pays": customer_pays,
        "total": float(order.total),
        "payment_method": payment_method,
        "status": order.status,
        "delivery_pin": delivery_pin,
        "pickup_code": pickup_code,
        "created_at": order.created_at.isoformat(),
        "message": "Order placed successfully!",
    }


# ── Owner: list their orders ───────────────────────────────────────────────────

@router.get("/owner", response_model=List[OrderResponse])
def owner_list_orders(
    status_filter: str = "",
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found.")

    restaurant_ids = [r.id for r in owner.restaurants]
    if not restaurant_ids:
        return []

    q = db.query(Order).filter(Order.restaurant_id.in_(restaurant_ids))
    if status_filter:
        q = q.filter(Order.status == status_filter)
    orders = q.order_by(Order.created_at.desc()).all()
    return [_order_to_response(o) for o in orders]


# ── Owner: update order status ─────────────────────────────────────────────────

@router.patch("/owner/{order_id}/status")
def owner_update_status(
    order_id: str,
    body: OrderStatusUpdate,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found.")

    restaurant_ids = [r.id for r in owner.restaurants]
    order = db.query(Order).filter(
        Order.id == order_id,
        Order.restaurant_id.in_(restaurant_ids),
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")

    allowed = _VALID_TRANSITIONS.get(order.status, set())
    if body.status not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot move from '{order.status}' to '{body.status}'.",
        )

    order.status = body.status
    db.commit()
    db.refresh(order)

    # In-app notification to customer for key status transitions
    if order.customer_mobile:
        short_id = order.id[:8].upper()
        rest_name = order.restaurant.name if order.restaurant else "The restaurant"
        _notif_messages = {
            "accepted":         f"Your order #{short_id} from {rest_name} is accepted! 🍽️",
            "ready":            f"Your order #{short_id} from {rest_name} is ready and being dispatched!",
            "ready_for_pickup": f"Your order #{short_id} is ready for pickup!",
            "rider_assigned":   f"A rider is on the way with your order #{short_id}! 🛵",
            "out_for_delivery": f"Your order #{short_id} is out for delivery! 🛵",
            "delivered":        f"Your order #{short_id} from {rest_name} has been delivered. Enjoy! 🎉",
            "collected":        f"Enjoy your meal! Order #{short_id} marked as collected.",
            "cancelled":        f"Your order #{short_id} from {rest_name} was cancelled. We're sorry!",
        }
        msg = _notif_messages.get(body.status)
        if msg:
            db.add(CustomerNotification(
                restaurant_id=order.restaurant_id,
                restaurant_name=rest_name,
                customer_mobile=order.customer_mobile,
                message=msg,
            ))
            db.commit()

    return {"order_id": order.id, "status": order.status, "message": "Status updated."}


# ── Customer: cancel order within 60-second window ───────────────────────────

@router.post("/{order_id}/cancel")
def customer_cancel_order(order_id: str, db: Session = Depends(get_db)):
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")
    if order.status != "placed":
        raise HTTPException(status_code=400, detail="Order cannot be cancelled at this stage.")
    elapsed = (datetime.utcnow() - order.created_at).total_seconds()
    if elapsed > CANCEL_WINDOW_SECS:
        raise HTTPException(
            status_code=400,
            detail="Cancellation window has expired (30 seconds).",
        )
    order.status = "cancelled"
    order.cancelled_at = datetime.utcnow()
    order.cancellation_reason = "Customer cancelled"
    db.commit()
    return {"order_id": order.id, "status": "cancelled", "message": "Order cancelled."}


# ── Customer: get order status (public, poll) ─────────────────────────────────

@router.get("/{order_id}", response_model=OrderResponse)
def get_order_status(order_id: str, db: Session = Depends(get_db)):
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")
    return _order_to_response(order)


@router.post("/{order_id}/rate")
def rate_order(order_id: str, body: dict, db: Session = Depends(get_db)):
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")
    if order.status != "delivered":
        raise HTTPException(status_code=400, detail="Only delivered orders can be rated.")
    if order.rating is not None:
        raise HTTPException(status_code=400, detail="Order already rated.")
    rating = body.get("rating")
    if not isinstance(rating, int) or rating < 1 or rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be 1–5.")
    order.rating = rating
    comment = (body.get("comment") or "").strip()
    order.rating_comment = comment if comment else None
    db.commit()
    return {"message": "Thank you for your feedback!"}


@router.get("/{order_id}/rider-location")
def get_rider_location(order_id: str, db: Session = Depends(get_db)):
    from app.models import Rider
    order = db.get(Order, order_id)
    if not order or order.status != "rider_assigned":
        raise HTTPException(status_code=404, detail="Location not available.")
    if not order.assigned_rider_id:
        raise HTTPException(status_code=404, detail="No rider assigned.")
    rider = db.get(Rider, order.assigned_rider_id)
    if not rider or rider.current_lat is None or rider.current_lng is None:
        raise HTTPException(status_code=404, detail="Rider location not yet available.")
    return {
        "lat": rider.current_lat,
        "lng": rider.current_lng,
        "updated_at": rider.location_updated_at.isoformat() if rider.location_updated_at else None,
    }


# ── Owner: store FCM token ─────────────────────────────────────────────────────

@router.post("/owner/fcm-token", status_code=200)
def update_fcm_token(
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner_id = _get_owner_id(credentials)
    owner = db.get(Owner, owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found.")
    owner.fcm_token = body.get("fcm_token", "")
    db.commit()
    return {"message": "FCM token updated."}
