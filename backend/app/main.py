from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.database import engine, SessionLocal
from app.routers import auth
from app.routers import owner, admin, menu

app = FastAPI(
    title="Project GSR API",
    description="Food ordering API for small Indian restaurants — Chhatrapati Sambhajinagar Phase 1",
    version="0.4.0"
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
    return {"status": "ok", "db": db_status, "version": "0.4.0"}


@app.get("/")
def root():
    return {"message": "Project GSR API is running", "docs": "/docs"}
