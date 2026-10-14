import asyncio
from datetime import datetime, timedelta
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.database import engine, SessionLocal
from app.models import Restaurant
from app.routers import auth
from app.routers import owner, admin, menu, customer, orders, rider

app = FastAPI(
    title="BossBite API",
    description="Food ordering API — BossBite Phase 1, Chhatrapati Sambhajinagar POC",
    version="0.6.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(owner.router)
app.include_router(admin.router)
app.include_router(menu.router)
app.include_router(customer.router)
app.include_router(orders.router)
app.include_router(rider.router)


@app.on_event("startup")
def _auto_migrate():
    with engine.connect() as conn:
        conn.execute(text(
            "ALTER TABLE restaurant ADD COLUMN IF NOT EXISTS "
            "is_accepting_orders BOOLEAN DEFAULT TRUE"
        ))
        conn.execute(text(
            "ALTER TABLE restaurant ADD COLUMN IF NOT EXISTS "
            "back_online_at TIMESTAMP WITHOUT TIME ZONE"
        ))
        conn.execute(text(
            'ALTER TABLE "order" ADD COLUMN IF NOT EXISTS '
            "customer_area VARCHAR(100)"
        ))
        conn.execute(text(
            "CREATE TABLE IF NOT EXISTS notification_request "
            "(id uuid PRIMARY KEY, restaurant_id uuid NOT NULL, "
            "customer_mobile VARCHAR(15) NOT NULL, "
            "created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now())"
        ))
        conn.execute(text(
            "CREATE TABLE IF NOT EXISTS customer_notification "
            "(id uuid PRIMARY KEY, restaurant_id uuid NOT NULL, "
            "restaurant_name VARCHAR(200) NOT NULL, "
            "customer_mobile VARCHAR(15) NOT NULL, "
            "message VARCHAR(500) NOT NULL, "
            "is_read BOOLEAN DEFAULT FALSE, "
            "created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now())"
        ))
        # Unique index on offer_code (partial — NULLs don't conflict)
        conn.execute(text(
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_offer_code "
            "ON offer (offer_code) WHERE offer_code IS NOT NULL"
        ))
        conn.execute(text(
            "CREATE TABLE IF NOT EXISTS rider ("
            "id uuid PRIMARY KEY, "
            "name VARCHAR(100) NOT NULL, "
            "phone VARCHAR(15) UNIQUE NOT NULL, "
            "restaurant_id uuid NOT NULL REFERENCES restaurant(id), "
            "vehicle_number VARCHAR(20) NOT NULL, "
            "approval_status VARCHAR(20) NOT NULL DEFAULT 'pending_admin', "
            "created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now())"
        ))
        conn.execute(text(
            'ALTER TABLE "order" ADD COLUMN IF NOT EXISTS '
            "assigned_rider_id uuid REFERENCES rider(id)"
        ))
        conn.execute(text(
            'ALTER TABLE "order" ADD COLUMN IF NOT EXISTS '
            "delivery_pin VARCHAR(4)"
        ))
        conn.execute(text(
            "ALTER TABLE rider ADD COLUMN IF NOT EXISTS "
            "deletion_requested BOOLEAN DEFAULT FALSE"
        ))
        conn.execute(text(
            "ALTER TABLE rider ADD COLUMN IF NOT EXISTS "
            "deleted_at TIMESTAMP WITHOUT TIME ZONE"
        ))
        conn.commit()


def _close_restaurants_for_night():
    """Set is_accepting_orders=False for all active restaurants (runs at 23:45 IST = 18:15 UTC)."""
    db = SessionLocal()
    try:
        db.query(Restaurant).filter(Restaurant.status == "active").update(
            {"is_accepting_orders": False}, synchronize_session=False
        )
        db.commit()
    except Exception as e:
        print(f"[night-close] error: {e}")
    finally:
        db.close()


async def _night_close_loop():
    while True:
        now = datetime.utcnow()
        target = now.replace(hour=18, minute=15, second=0, microsecond=0)
        if now >= target:
            target += timedelta(days=1)
        await asyncio.sleep((target - now).total_seconds())
        _close_restaurants_for_night()


@app.on_event("startup")
async def start_night_close_scheduler():
    asyncio.create_task(_night_close_loop())


@app.get("/health")
def health_check():
    db_status = "disconnected"
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db_status = "connected"
        db.close()
    except Exception as e:
        db_status = f"error: {str(e)}"
    return {"status": "ok", "db": db_status, "version": "0.6.0"}


@app.get("/")
def root():
    return {"message": "Project GSR API is running", "docs": "/docs"}
