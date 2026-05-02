# main.py
from fastapi import FastAPI
from database import engine, Base
from routers import notes

# Auto-create all tables defined via ORM models on startup
# (safe to call repeatedly — only creates tables that don't exist yet)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="FastAI Notes API",
    description="A simple Notes CRUD API built with FastAPI and SQLite via SQLAlchemy.",
    version="1.0.0",
)

app.include_router(notes.router)


@app.get("/")
def read_root():
    return {"message": "Notes API is running!"}