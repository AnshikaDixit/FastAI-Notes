from fastapi import FastAPI
from pydantic import BaseModel
from routers import notes

app = FastAPI()

app.include_router(notes.router)

@app.get("/")
def read_root():
    return {"message": "Notes API is running!"}