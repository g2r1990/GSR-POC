from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import Restaurant, MenuItem
from app.schemas.customer import RestaurantResponse, CustomerMenuItemResponse

router = APIRouter(prefix="/customer", tags=["Customer"])


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
