from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime


class OwnerRegisterRequest(BaseModel):
    name: str
    mobile: str
    password: str
    gstin: Optional[str] = None
    restaurant_name: str
    address: str
    area: str
    pincode: str
    state: str = ""
    food_type: str = "both"   # veg | nonveg | both

    @field_validator('mobile')
    @classmethod
    def mobile_format(cls, v: str) -> str:
        v = v.strip()
        if not v.startswith('+'):
            v = '+91' + v.lstrip('0')
        return v

    @field_validator('food_type')
    @classmethod
    def food_type_valid(cls, v: str) -> str:
        if v not in ('veg', 'nonveg', 'both'):
            raise ValueError("food_type must be veg, nonveg, or both")
        return v


class OwnerRegisterResponse(BaseModel):
    owner_id: str
    restaurant_code: str
    message: str = "Registration submitted. Awaiting admin approval."


class KycRestaurantInfo(BaseModel):
    id: str
    name: str
    address: str
    area: str
    pincode: str
    state: Optional[str] = None
    restaurant_code: Optional[str] = None
    food_type: str


class KycItemResponse(BaseModel):
    id: str
    name: str
    mobile: str
    gstin: Optional[str]
    doc_url: Optional[str]
    status: str
    created_at: datetime
    restaurant: Optional[KycRestaurantInfo] = None

    model_config = {"from_attributes": True}


class RejectRequest(BaseModel):
    reason: str


class OwnerSetPasswordRequest(BaseModel):
    mobile: str
    password: str

    @field_validator('mobile')
    @classmethod
    def mobile_format(cls, v: str) -> str:
        v = v.strip()
        if not v.startswith('+'):
            v = '+91' + v.lstrip('0')
        return v


class OwnerLoginRequest(BaseModel):
    mobile: str
    password: str

    @field_validator('mobile')
    @classmethod
    def mobile_format(cls, v: str) -> str:
        v = v.strip()
        if not v.startswith('+'):
            v = '+91' + v.lstrip('0')
        return v


class OwnerLoginResponse(BaseModel):
    access_token: str
    owner_id: str
    name: str
