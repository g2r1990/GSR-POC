import uuid
from datetime import datetime
from sqlalchemy import Column, String, Numeric, Boolean, DateTime, Text, ForeignKey, Integer, Float
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.database import Base

def new_uuid():
    return str(uuid.uuid4())


class Admin(Base):
    __tablename__ = "admin"
    id            = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    username      = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    totp_secret   = Column(String(64), nullable=True)
    totp_enabled  = Column(Boolean, default=False)
    is_active     = Column(Boolean, default=True)
    created_at    = Column(DateTime, default=datetime.utcnow)


class Owner(Base):
    __tablename__ = "owner"
    id                = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    name              = Column(String(100), nullable=False)
    mobile            = Column(String(15), unique=True, nullable=False)
    email             = Column(String(150), unique=True, nullable=True)
    password_hash     = Column(String(255), nullable=True)
    totp_secret       = Column(String(64), nullable=True)
    status            = Column(String(20), default="pending")   # pending | active | suspended | rejected
    gstin             = Column(String(15), nullable=True)
    doc_url           = Column(String(500), nullable=True)      # S3 URL of KYC document
    rejection_reason  = Column(Text, nullable=True)
    firebase_uid      = Column(String(128), nullable=True)
    fcm_token         = Column(String(500), nullable=True)
    tnc_accepted      = Column(Boolean, default=False)
    created_at        = Column(DateTime, default=datetime.utcnow)
    pending_profile_update      = Column(Text, nullable=True)
    pending_update_submitted_at = Column(DateTime, nullable=True)
    restaurants       = relationship("Restaurant", back_populates="owner")


class Restaurant(Base):
    __tablename__ = "restaurant"
    id          = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    owner_id    = Column(UUID(as_uuid=False), ForeignKey("owner.id"), nullable=False)
    name        = Column(String(150), nullable=False)
    address     = Column(Text, nullable=False)
    area        = Column(String(100), nullable=False)
    pincode         = Column(String(10), nullable=False)
    state           = Column(String(100), nullable=True)
    restaurant_code = Column(String(20), unique=True, nullable=True)
    food_type       = Column(String(10), default="both")    # veg | nonveg | both
    status          = Column(String(20), default="pending") # pending | active | suspended
    photo_url           = Column(String(500), nullable=True)
    is_accepting_orders = Column(Boolean, default=True)
    back_online_at      = Column(DateTime, nullable=True)
    created_at  = Column(DateTime, default=datetime.utcnow)
    owner       = relationship("Owner", back_populates="restaurants")
    menu_items  = relationship("MenuItem", back_populates="restaurant")
    orders      = relationship("Order", back_populates="restaurant")
    inspections = relationship("Inspection", back_populates="restaurant")
    offers      = relationship("Offer", back_populates="restaurant")


class MenuItem(Base):
    __tablename__ = "menu_item"
    id            = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    restaurant_id = Column(UUID(as_uuid=False), ForeignKey("restaurant.id"), nullable=False)
    category      = Column(String(100), nullable=False)
    name          = Column(String(150), nullable=False)
    description   = Column(Text, nullable=True)
    price         = Column(Numeric(10, 2), nullable=False)
    photo_url     = Column(String(500), nullable=True)
    is_available  = Column(Boolean, default=True)
    is_deleted    = Column(Boolean, default=False)
    created_at    = Column(DateTime, default=datetime.utcnow)
    restaurant    = relationship("Restaurant", back_populates="menu_items")


class Customer(Base):
    __tablename__ = "customer"
    id           = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    name         = Column(String(100), nullable=True)
    mobile       = Column(String(15), unique=True, nullable=False)
    email        = Column(String(150), nullable=True)
    firebase_uid = Column(String(128), unique=True, nullable=True)
    device_id    = Column(String(128), nullable=True)
    created_at   = Column(DateTime, default=datetime.utcnow)
    orders       = relationship("Order", back_populates="customer")


class Order(Base):
    __tablename__ = "order"
    id              = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    restaurant_id   = Column(UUID(as_uuid=False), ForeignKey("restaurant.id"), nullable=False)
    customer_id     = Column(UUID(as_uuid=False), ForeignKey("customer.id"), nullable=True)
    customer_name   = Column(String(100), nullable=True)    # for guest orders
    customer_mobile = Column(String(15), nullable=True)     # for guest orders
    status          = Column(String(20), default="placed")  # placed|accepted|ready|out_for_delivery|delivered|cancelled
    items_snapshot  = Column(JSONB, nullable=False)         # price snapshot at order time
    total           = Column(Numeric(10, 2), nullable=False)
    customer_area   = Column(String(100), nullable=True)
    delivery_address= Column(Text, nullable=True)
    notes              = Column(Text, nullable=True)
    assigned_rider_id  = Column(UUID(as_uuid=False), ForeignKey("rider.id"), nullable=True)
    delivery_pin       = Column(String(4), nullable=True)
    delivery_lat       = Column(Float, nullable=True)
    delivery_lng       = Column(Float, nullable=True)
    rating             = Column(Integer, nullable=True)
    rating_comment     = Column(String(300), nullable=True)
    created_at         = Column(DateTime, default=datetime.utcnow)
    updated_at         = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    restaurant         = relationship("Restaurant", back_populates="orders")
    customer           = relationship("Customer", back_populates="orders")


class Offer(Base):
    __tablename__ = "offer"
    id             = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    restaurant_id  = Column(UUID(as_uuid=False), ForeignKey("restaurant.id"), nullable=False)
    title          = Column(String(200), nullable=False)
    description    = Column(Text, nullable=True)
    offer_type     = Column(String(20), nullable=False, default='order')  # order | item | bogo
    offer_code     = Column(String(10), nullable=True, unique=True)
    discount_pct   = Column(Numeric(5, 2), nullable=True)
    menu_item_id   = Column(String(36), nullable=True)   # FK to menu_item.id (soft ref)
    menu_item_name = Column(String(150), nullable=True)
    buy_qty        = Column(Integer, nullable=True)
    free_qty       = Column(Integer, nullable=True)
    valid_until    = Column(DateTime, nullable=True)
    is_active      = Column(Boolean, default=True)
    created_at     = Column(DateTime, default=datetime.utcnow)
    restaurant     = relationship("Restaurant", back_populates="offers")


class Inspection(Base):
    __tablename__ = "inspection"
    id            = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    restaurant_id = Column(UUID(as_uuid=False), ForeignKey("restaurant.id"), nullable=False)
    result        = Column(String(10), nullable=True)   # pass | fail
    notes         = Column(Text, nullable=True)
    inspector     = Column(String(100), nullable=True)
    due_date      = Column(DateTime, nullable=False)
    inspected_at  = Column(DateTime, nullable=True)
    created_at    = Column(DateTime, default=datetime.utcnow)
    restaurant    = relationship("Restaurant", back_populates="inspections")


class NotificationRequest(Base):
    __tablename__ = "notification_request"
    id              = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    restaurant_id   = Column(UUID(as_uuid=False), ForeignKey("restaurant.id", ondelete="CASCADE"), nullable=False)
    customer_mobile = Column(String(15), nullable=False)
    created_at      = Column(DateTime, default=datetime.utcnow)


class CustomerNotification(Base):
    __tablename__ = "customer_notification"
    id              = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    restaurant_id   = Column(UUID(as_uuid=False), nullable=False)
    restaurant_name = Column(String(200), nullable=False)
    customer_mobile = Column(String(15), nullable=False)
    message         = Column(String(500), nullable=False)
    is_read         = Column(Boolean, default=False)
    created_at      = Column(DateTime, default=datetime.utcnow)


class Rider(Base):
    __tablename__ = "rider"
    id                  = Column(UUID(as_uuid=False), primary_key=True, default=new_uuid)
    name                = Column(String(100), nullable=False)
    phone               = Column(String(15), unique=True, nullable=False)
    restaurant_id       = Column(UUID(as_uuid=False), ForeignKey("restaurant.id"), nullable=False)
    vehicle_number      = Column(String(20), nullable=False)
    # pending_admin | pending_owner | active | rejected
    approval_status     = Column(String(20), default="pending_admin", nullable=False)
    deletion_requested  = Column(Boolean, default=False, nullable=True)
    deleted_at          = Column(DateTime, nullable=True)
    pending_phone       = Column(String(15), nullable=True)
    pending_vehicle     = Column(String(20), nullable=True)
    update_status       = Column(String(20), nullable=True)   # pending_owner | pending_admin
    update_submitted_at = Column(DateTime, nullable=True)
    current_lat         = Column(Float, nullable=True)
    current_lng         = Column(Float, nullable=True)
    location_updated_at = Column(DateTime, nullable=True)
    created_at          = Column(DateTime, default=datetime.utcnow)
    restaurant          = relationship("Restaurant")
