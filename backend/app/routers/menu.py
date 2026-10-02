from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError
from typing import List

from app.database import get_db
from app.models import MenuItem, Restaurant, Owner
from app.core.security import decode_token
from app.schemas.menu import MenuItemCreate, MenuItemUpdate, MenuItemResponse

router = APIRouter(prefix="/owner/menu", tags=["Menu"])
bearer = HTTPBearer()


def _get_owner(credentials: HTTPAuthorizationCredentials, db: Session) -> Owner:
    try:
        payload = decode_token(credentials.credentials)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    if payload.get("role") != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Requires owner role")
    owner = db.get(Owner, payload["sub"])
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    return owner


def _get_restaurant(owner: Owner) -> Restaurant:
    if not owner.restaurants:
        raise HTTPException(status_code=404, detail="No restaurant linked to this owner")
    return owner.restaurants[0]


# ── List menu ──────────────────────────────────────────────────────────────────

@router.get("", response_model=List[MenuItemResponse])
def list_menu(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner = _get_owner(credentials, db)
    restaurant = _get_restaurant(owner)
    items = (
        db.query(MenuItem)
        .filter(MenuItem.restaurant_id == restaurant.id, MenuItem.is_deleted == False)
        .order_by(MenuItem.category, MenuItem.name)
        .all()
    )
    return items


# ── Add item ───────────────────────────────────────────────────────────────────

@router.post("/item", response_model=MenuItemResponse, status_code=201)
def add_menu_item(
    body: MenuItemCreate,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner = _get_owner(credentials, db)
    restaurant = _get_restaurant(owner)
    item = MenuItem(
        restaurant_id=restaurant.id,
        category=body.category,
        name=body.name,
        description=body.description,
        price=body.price,
        photo_url=body.photo_url,
        is_available=True,
        is_deleted=False,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


# ── Edit item ──────────────────────────────────────────────────────────────────

@router.put("/item/{item_id}", response_model=MenuItemResponse)
def update_menu_item(
    item_id: str,
    body: MenuItemUpdate,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner = _get_owner(credentials, db)
    restaurant = _get_restaurant(owner)
    item = db.query(MenuItem).filter(
        MenuItem.id == item_id,
        MenuItem.restaurant_id == restaurant.id,
        MenuItem.is_deleted == False,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(item, field, value)
    db.commit()
    db.refresh(item)
    return item


# ── Toggle availability ────────────────────────────────────────────────────────

@router.patch("/item/{item_id}/availability")
def toggle_availability(
    item_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner = _get_owner(credentials, db)
    restaurant = _get_restaurant(owner)
    item = db.query(MenuItem).filter(
        MenuItem.id == item_id,
        MenuItem.restaurant_id == restaurant.id,
        MenuItem.is_deleted == False,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    item.is_available = not item.is_available
    db.commit()
    return {"id": item.id, "is_available": item.is_available}


# ── Soft delete ────────────────────────────────────────────────────────────────

@router.delete("/item/{item_id}", status_code=200)
def delete_menu_item(
    item_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
):
    owner = _get_owner(credentials, db)
    restaurant = _get_restaurant(owner)
    item = db.query(MenuItem).filter(
        MenuItem.id == item_id,
        MenuItem.restaurant_id == restaurant.id,
        MenuItem.is_deleted == False,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    item.is_deleted = True
    db.commit()
    return {"message": "Item removed from menu."}
