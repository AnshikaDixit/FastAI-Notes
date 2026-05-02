# models/note.py — Pydantic schemas (request/response shapes)
from datetime import datetime
from pydantic import BaseModel
from pydantic import ConfigDict


class NoteBase(BaseModel):
    title: str
    description: str
    personal: bool | None = None


class NoteCreate(NoteBase):
    """Schema for creating a note (all required fields)."""
    pass


class NoteUpdate(BaseModel):
    """Schema for partial updates — every field is optional."""
    title: str | None = None
    description: str | None = None
    personal: bool | None = None


class NoteResponse(NoteBase):
    """Schema returned to the client — includes DB-generated fields."""
    id: int
    created_at: datetime
    updated_at: datetime

    # Pydantic v2 style: tells Pydantic to read ORM attributes, not just dicts
    model_config = ConfigDict(from_attributes=True)