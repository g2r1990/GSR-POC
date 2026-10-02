from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class MenuItemCreate(BaseModel):
    category: str
    name: str
    description: Optional[str] = None
    price: float
    photo_url: Optional[str] = None


class MenuItemUpdate(BaseModel):
    category: Optional[str] = None
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    photo_url: Optional[str] = None


class MenuItemResponse(BaseModel):
    id: str
    restaurant_id: str
    category: str
    name: str
    description: Optional[str]
    price: float
    photo_url: Optional[str]
    is_available: bool
    created_at: datetime

    model_config = {"from_attributes": True}
