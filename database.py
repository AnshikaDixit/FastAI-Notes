# database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# SQLite database file will be created at project root as notes.db
DATABASE_URL = "sqlite:///./notes.db"

# connect_args is SQLite-specific: allows the same connection to be used
# across multiple threads (needed because FastAPI runs in a threadpool)
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)

# SessionLocal: each request gets its own DB session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# Base class that all ORM models will inherit from
class Base(DeclarativeBase):
    pass


# Dependency: yields a DB session per request, always closes it after
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
