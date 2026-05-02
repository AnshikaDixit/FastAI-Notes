# routers/notes.py
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from database import get_db
from models.note import NoteCreate, NoteUpdate, NoteResponse
import services.note_service as note_service

router = APIRouter(
    prefix="/notes",   # all routes here auto get /notes prefix
    tags=["Notes"]     # groups them in /docs
)


@router.post("/", status_code=201, response_model=NoteResponse)
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
    """Create a new note and persist it to the database."""
    return note_service.create_note(db, note)


@router.get("/", response_model=list[NoteResponse])
def list_notes(db: Session = Depends(get_db)):
    """Retrieve all notes, ordered by most recently created."""
    return note_service.get_all_notes(db)


@router.get("/{note_id}", response_model=NoteResponse)
def get_note(note_id: int, db: Session = Depends(get_db)):
    """Retrieve a single note by its ID."""
    note = note_service.get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@router.put("/{note_id}", response_model=NoteResponse)
def update_note(note_id: int, updated: NoteUpdate, db: Session = Depends(get_db)):
    """Partially update a note. Only provided fields are changed."""
    note = note_service.update_note(db, note_id, updated)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@router.delete("/{note_id}")
def delete_note(note_id: int, db: Session = Depends(get_db)):
    """Delete a note by ID."""
    note = note_service.delete_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return {"message": "Note deleted", "id": note_id}