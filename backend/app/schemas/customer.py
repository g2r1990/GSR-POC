from datetime import datetime
from pydantic import BaseModel
from typing import Optional


class RestaurantResponse(BaseModel):
    id: str
    name: str
    address: str
    area: str
    pincode: str
    food_type: str
    photo_url: Optional[str] = None
    is_accepting_orders: bool = True
    back_online_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CustomerMenuItemResponse(BaseModel):
    id: str
    category: str
    name: str
    description: Optional[str] = None
    price: float
    photo_url: Optional[str] = None
    is_available: bool
    model_config = {"from_attributes": True}
