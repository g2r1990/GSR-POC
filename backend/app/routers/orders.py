from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError
from typing import List

from app.database import get_db
from app.models import Owner, Restaurant, MenuItem, Order
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
        delivery_address=order.delivery_address or "",
        items=items,
        total=float(order.total),
        status=order.status,
        notes=order.notes,
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

    if not body.items:
        raise HTTPException(status_code=400, detail="Order must have at least one item.")

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

    order = Order(
        restaurant_id=body.restaurant_id,
        customer_name=body.customer_name,
        customer_mobile=body.customer_phone,
        delivery_address=body.delivery_address,
        notes=body.notes,
        items_snapshot={"items": snapshot_items},
        total=round(total, 2),
        status="placed",
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
    return {"order_id": order.id, "status": order.status, "message": "Status updated."}


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
