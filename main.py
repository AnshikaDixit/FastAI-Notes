# main.py 
#2. Where the app starts
from fastapi import FastAPI
from database import engine, Base
from routers import notes

Base.metadata.create_all(bind=engine)   
# Whats happening?: This command scans all the classes that inherit from our Base (like our NoteORM) and creates the corresponding tables in the database.
# Why?: This is how we create our database structure (schema) without writing manual SQL commands like CREATE TABLE.

app = FastAPI(
    title="FastAI Notes API",
    description="A simple Notes CRUD API built with FastAPI and SQLite via SQLAlchemy.",
    version="1.0.0",
)
# Whats happening?: This creates the main FastAPI application instance.
# Why?: This is the entry point for our entire API. All our routes (GET, POST, PUT, DELETE) will be attached to this app instance.

app.include_router(notes.router)
# Whats happening?: This includes all the routes defined in the notes.py file into our main application.
# Why?: This is done to keep our code organized. Instead of putting all the routes in one file, we can put them in different files (e.g., note_routes.py, auth_routes.py) and include them here.

@app.get("/")
def read_root():
    return {"message": "Notes API is running!"}