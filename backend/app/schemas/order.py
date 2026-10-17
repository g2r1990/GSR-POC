from enum import Enum
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class OrderStatus(str, Enum):
    placed           = "placed"
    accepted         = "accepted"
    ready            = "ready"
    rider_assigned   = "rider_assigned"
    out_for_delivery = "out_for_delivery"
    delivered        = "delivered"
    ready_for_pickup = "ready_for_pickup"
    collected        = "collected"
    cancelled        = "cancelled"


class OrderItemIn(BaseModel):
    item_id: str
    qty: int
    spice_level: Optional[str] = None   # per-item override
    item_notes: Optional[str] = None    # per-item notes


class PlaceOrderRequest(BaseModel):
    restaurant_id: str
    customer_name: str
    customer_phone: str
    order_type: str = "delivery"                   # delivery | takeaway
    delivery_address: Optional[str] = None
    delivery_lat: Optional[float] = None
    delivery_lng: Optional[float] = None
    customer_area: Optional[str] = None
    items: List[OrderItemIn]
    # food preferences
    spice_level: Optional[str] = None              # spicy | medium_spicy | less_spicy
    special_instructions: Optional[str] = None
    cutlery_requested: bool = False
    # payment
    payment_method: str = "online"                 # online | cod
    rider_tip: float = 0.0
    # legacy offer (kept for backward compat)
    notes: Optional[str] = None
    offer_code: Optional[str] = None
    discount_amount: Optional[float] = 0.0
    # new coupon system
    coupon_code: Optional[str] = None
    # idempotency
    idempotency_key: Optional[str] = None


class OrderStatusUpdate(BaseModel):
    status: OrderStatus
    note: Optional[str] = None


class OrderItemSnapshot(BaseModel):
    item_id: str
    name: str
    category: str
    price: float
    qty: int
    subtotal: float
    spice_level: Optional[str] = None
    item_notes: Optional[str] = None


class OrderResponse(BaseModel):
    id: str
    short_id: str
    restaurant_id: str
    customer_name: str
    customer_phone: str
    customer_area: Optional[str] = None
    order_type: str = "delivery"
    delivery_address: Optional[str] = None
    items: List[OrderItemSnapshot]
    # billing
    food_total: float = 0.0
    restaurant_discount: float = 0.0
    bossbite_discount: float = 0.0
    taxable_amount: float = 0.0
    gst_rate: float = 0.0
    gst_amount: float = 0.0
    delivery_fee: float = 0.0
    cutlery_fee_amt: float = 0.0
    rider_tip: float = 0.0
    cod_convenience_fee: float = 0.0
    customer_pays: float = 0.0
    total: float                         # backward compat
    discount_amount: float = 0.0         # backward compat
    offer_code: str = ""                 # backward compat
    # payment
    payment_method: str = "online"
    payment_status: str = "pending"
    # food prefs
    spice_level: Optional[str] = None
    special_instructions: Optional[str] = None
    cutlery_requested: bool = False
    # codes
    delivery_pin: Optional[str] = None
    pickup_code: Optional[str] = None
    # status
    status: str
    assigned_rider_id: Optional[str] = None
    rating: Optional[int] = None
    rating_comment: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
