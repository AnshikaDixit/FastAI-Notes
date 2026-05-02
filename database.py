# database.py
#3. How it connects to the DB
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# SQLite database file will be created at project root as notes.db
DATABASE_URL = "sqlite:///./notes.db"

engine = create_engine( #Engine is the core thing in sqlalchemy which interacts with the database
    DATABASE_URL,
    connect_args={"check_same_thread": False} # connect_args is SQLite-specific: allows the same connection to be used across multiple threads (needed because FastAPI runs in a threadpool)
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine) # SessionLocal: each request gets its own DB session
# Whats happening? : This is creating a "Session Factory". Whenever you need to read or write something to the database, you will ask for a new Session from here.
# Why is it happening? : Instead of talking directly to the engine, we use sessions in ORM (Object Relational Mapper).
# Auto Commit False: This means that until you explicitly say db.commit(), the data will not be permanently saved in the database. This is good because if any error occurs during the process, you can easily undo (rollback) the changes.
# bind=engine: This tells the session factory which database engine to connect to.


# Base class that all ORM models will inherit from
class Base(DeclarativeBase):
    pass
# Whats happening? : We are creating an empty Base class.
# Why is it happening?: Later on, we will create database tables (like User, Note, etc.) in the form of python classes. All those classes will inherit this Base. This tells SQLAlchemy, "Oh, these classes are not normal Python classes, they are my database tables!"


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# What's happening? : This function opens a fresh database session (connection) for every new API request and closes it (close()) when the request is completed.
# Why is it happening? : This is a very powerful feature of FastAPI called Dependency Injection.
# db : SessionLocal(): New connection created
# yield db: This function will pause its work here and give the 'db' (connection) to the API route to use.
# finally: db.close(): When the API finishes sending the response, this finally block will run, and the connection will be closed. If we don't close the connection, the database will hang in a short time because the limit will be exceeded.
