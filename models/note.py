# models/note.py
from pydantic import BaseModel

class NoteBase(BaseModel):
    title: str
    description: str
    personal: bool | None = None

class NoteCreate(NoteBase):
    pass

class NoteUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    personal: bool | None = None

class NoteResponse(NoteBase):
    id: int

    class Config:
        from_attributes = True # Lets Pydantic read ORM objects, not just dicts, which Pydantic can't do by default