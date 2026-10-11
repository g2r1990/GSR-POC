from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.database import engine, SessionLocal
from app.routers import auth
from app.routers import owner, admin, menu, customer, orders

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
        conn.commit()


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
