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
    "placed":            {"accepted", "cancelled"},
    "accepted":          {"ready", "cancelled"},
    "ready":             {"out_for_delivery"},
    "out_for_delivery":  {"delivered"},
    "delivered":         set(),
    "cancelled":         set(),
}


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
    items = [OrderItemSnapshot(**i) for i in snapshot.get("items", [])]
    return OrderResponse(
        id=order.id,
        short_id=order.id[:8].upper(),
        restaurant_id=order.restaurant_id,
        customer_name=order.customer_name or "",
        customer_phone=order.customer_mobile or "",
        customer_area=order.customer_area,
        delivery_address=order.delivery_address or "",
        items=items,
        total=float(order.total),
        discount_amount=float(snapshot.get("discount_amount", 0)),
        offer_code=snapshot.get("offer_code", ""),
        status=order.status,
        notes=order.notes,
        created_at=order.created_at,
        delivery_pin=order.delivery_pin,
        assigned_rider_id=order.assigned_rider_id,
        rating=order.rating,
        rating_comment=order.rating_comment,
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

    if not getattr(restaurant, 'is_accepting_orders', True):
        raise HTTPException(
            status_code=400,
            detail="This restaurant is not currently accepting orders. Please try again later."
        )

    if not body.items:
        raise HTTPException(status_code=400, detail="Order must have at least one item.")

    # One-use-per-customer: reject if this mobile already used the same offer code
    if body.offer_code:
        from sqlalchemy import text as _text
        already_used = db.execute(
            _text(
                "SELECT id FROM \"order\" "
                "WHERE customer_mobile = :mobile "
                "  AND status != 'cancelled' "
                "  AND items_snapshot->>'offer_code' = :code "
                "LIMIT 1"
            ),
            {"mobile": body.customer_phone, "code": body.offer_code},
        ).fetchone()
        if already_used:
            raise HTTPException(
                status_code=400,
                detail="You have already used this offer. Each offer code can only be used once.",
            )

    snapshot_items = []
    total = 0.0

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
            raise HTTPException(
                status_code=400,
                detail=f"Item {line.item_id} is not available.",
            )
        price = float(item.price)
        subtotal = price * line.qty
        total += subtotal
        snapshot_items.append({
            "item_id": item.id,
            "name": item.name,
            "category": item.category,
            "price": price,
            "qty": line.qty,
            "subtotal": subtotal,
        })

    if not snapshot_items:
        raise HTTPException(status_code=400, detail="No valid items in order.")

    # Apply offer discount (sent pre-computed from Flutter checkout)
    discount = round(min(float(body.discount_amount or 0), total), 2)
    discounted_total = round(total - discount, 2)

    delivery_pin = str(random.randint(1000, 9999))
    order = Order(
        restaurant_id=body.restaurant_id,
        customer_name=body.customer_name,
        customer_mobile=body.customer_phone,
        customer_area=body.customer_area,
        delivery_address=body.delivery_address,
        notes=body.notes,
        items_snapshot={
            "items": snapshot_items,
            "discount_amount": discount,
            "offer_code": body.offer_code or "",
        },
        total=discounted_total,
        status="placed",
        delivery_pin=delivery_pin,
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    # Notify owner via FCM (fire and forget)
    owner = restaurant.owner
    if owner and owner.fcm_token:
        send_new_order_notification(owner.fcm_token, order.id[:8].upper(), total)

    return {
        "order_id": order.id,
        "short_id": order.id[:8].upper(),
        "total": float(order.total),
        "status": order.status,
        "delivery_pin": order.delivery_pin,
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

    if order.status == "placed" and body.status == "accepted":
        elapsed = (datetime.utcnow() - order.created_at).total_seconds()
        remaining = int(30 - elapsed)
        if remaining > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Customer cancel window active. Please wait {remaining}s.",
            )

    order.status = body.status
    db.commit()
    db.refresh(order)

    # In-app notification to customer for key status transitions
    if order.customer_mobile:
        short_id = order.id[:8].upper()
        rest_name = order.restaurant.name if order.restaurant else "The restaurant"
        _notif_messages = {
            "accepted":         f"Your order #{short_id} from {rest_name} is being prepared! 🍽️",
            "ready":            f"Your order #{short_id} from {rest_name} is ready!",
            "out_for_delivery": f"Your order #{short_id} is out for delivery! 🛵",
            "delivered":        f"Your order #{short_id} from {rest_name} has been delivered. Enjoy! 🎉",
            "cancelled":        f"We're sorry! 🙏 Your order #{short_id} from {rest_name} couldn't be accepted this time. We hope to see you again soon!",
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
    if elapsed > 30:
        raise HTTPException(
            status_code=400,
            detail="Cancellation window has expired. Orders can only be cancelled within 30 seconds of placing.",
        )
    order.status = "cancelled"
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
