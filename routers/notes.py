# routers/notes.py
# 7. The API endpoints
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
    # note: NoteCreate -> The client must send a JSON body that matches the NoteCreate shape, Pydantic automatically reads the request body, validates it, and hands us a NoteCreate object. If the body is wrong, it rejects the request with 422 before code even runs.
    # db: Session -> Session is the type hint — it tells us that db is a SQLAlchemy database session object. This is just for autocomplete and readability.
    # Depends(get_db) -> The magic part -> This is Dependency Injection. Instead of manually calling get_db() inside every route, we say "FastAPI, please call get_db() for me and inject the result as db."
    return note_service.create_note(db, note)


@router.get("/", response_model=list[NoteResponse])
def list_notes(db: Session = Depends(get_db)):
    """Retrieve all notes, ordered by most recently created."""
    return note_service.get_all_notes(db)


@router.get("/{note_id}", response_model=NoteResponse)
def get_note(note_id: int, db: Session = Depends(get_db)):
    """Retrieve a single note by its ID."""
    # note_id: int -> This is a path parameter. FastAPI extracts '1', '2', etc., from the URL and passes them as integers.
    note = note_service.get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    # if not note -> If the service couldn't find a note with that ID, it returns None.
    # raise HTTPException -> We raise an HTTPException with a 404 status code and a JSON body.
    return note


@router.put("/{note_id}", response_model=NoteResponse)
def update_note(note_id: int, updated: NoteUpdate, db: Session = Depends(get_db)):
    """Partially update a note. Only provided fields are changed."""
    # note_id: int -> This is a path parameter. FastAPI extracts '1', '2', etc., from the URL and passes them as integers.
    # updated: NoteUpdate -> This is the body of the request. It uses the NoteUpdate schema, meaning the client can send only some fields (like just title) or all of them.
    note = note_service.update_note(db, note_id, updated)
    # note = note_service.update_note(db, note_id, updated) -> We call our service function.
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@router.delete("/{note_id}")
def delete_note(note_id: int, db: Session = Depends(get_db)):
    """Delete a note by ID."""
    note = note_service.delete_note(db, note_id)
    # note = note_service.delete_note(db, note_id) -> We call our service function.
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return {"message": "Note deleted", "id": note_id}   