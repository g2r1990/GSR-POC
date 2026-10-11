from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class OrderItemIn(BaseModel):
    item_id: str
    qty: int


class PlaceOrderRequest(BaseModel):
    restaurant_id: str
    customer_name: str
    customer_phone: str
    delivery_address: str
    items: List[OrderItemIn]
    notes: Optional[str] = None
    customer_area: Optional[str] = None   # stored for Food Stat by Area
    offer_code: Optional[str] = None      # offer code applied at checkout


class OrderStatusUpdate(BaseModel):
    status: str   # accepted | ready | out_for_delivery | delivered | cancelled


class OrderItemSnapshot(BaseModel):
    item_id: str
    name: str
    category: str
    price: float
    qty: int
    subtotal: float


class OrderResponse(BaseModel):
    id: str
    short_id: str
    restaurant_id: str
    customer_name: str
    customer_phone: str
    customer_area: Optional[str] = None
    delivery_address: str
    items: List[OrderItemSnapshot]
    total: float
    status: str
    notes: Optional[str] = None
    created_at: datetime
