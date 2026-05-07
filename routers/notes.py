# routers/notes.py
# 7. The API endpoints
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from database import get_db
from models.note import NoteCreate, NoteUpdate, NoteResponse
import services.note_service as note_service
from services.auth_service import get_current_user
from models.user_orm import UserORM
from models.response_schema import APIResponse
from utils.messages import SuccessMessages

router = APIRouter(
    prefix="/notes",   # all routes here auto get /notes prefix
    tags=["Notes"]     # groups them in /docs
)


@router.post("/", status_code=201, response_model=APIResponse[NoteResponse])
def create_note(note: NoteCreate, db: Session = Depends(get_db), current_user: UserORM = Depends(get_current_user)):
    """Create a new note and persist it to the database."""
    # note: NoteCreate -> The client must send a JSON body that matches the NoteCreate shape, Pydantic automatically reads the request body, validates it, and hands us a NoteCreate object. If the body is wrong, it rejects the request with 422 before code even runs.
    # db: Session -> Session is the type hint — it tells us that db is a SQLAlchemy database session object. This is just for autocomplete and readability.
    # Depends(get_db) -> The magic part -> This is Dependency Injection. Instead of manually calling get_db() inside every route, we say "FastAPI, please call get_db() for me and inject the result as db."
    # current_user: UserORM -> This ensures the user is logged in before they can create a note.
    db_note = note_service.create_note(db, note, current_user.id)
    return APIResponse(
        status_code=201,
        message=SuccessMessages.NOTE_CREATED,
        data=NoteResponse.model_validate(db_note)
    )


@router.get("/", response_model=APIResponse[list[NoteResponse]])
def list_notes(db: Session = Depends(get_db), current_user: UserORM = Depends(get_current_user)):
    """Retrieve all notes for the logged-in user."""
    notes = note_service.get_all_notes(db, current_user.id)
    return APIResponse(
        status_code=200,
        message=SuccessMessages.NOTES_RETRIEVED,
        data=[NoteResponse.model_validate(n) for n in notes]
    )


@router.get("/{note_id}", response_model=APIResponse[NoteResponse])
def get_note(note_id: int, db: Session = Depends(get_db), current_user: UserORM = Depends(get_current_user)):
    """Retrieve a single note by its ID for the logged-in user."""
    # note_id: int -> This is a path parameter. FastAPI extracts '1', '2', etc., from the URL and passes them as integers.
    note = note_service.get_note_by_id(db, note_id, current_user.id)
    if not note:
        # if not note -> If the service couldn't find a note with that ID, it returns None.
        # raise HTTPException -> We raise an HTTPException with a 404 status code and a JSON body.
        raise HTTPException(status_code=404, detail=ErrorMessages.NOTE_NOT_FOUND)
    return APIResponse(
        status_code=200,
        message=SuccessMessages.NOTE_RETRIEVED,
        data=NoteResponse.model_validate(note)
    )


@router.put("/{note_id}", response_model=APIResponse[NoteResponse])
def update_note(note_id: int, updated: NoteUpdate, db: Session = Depends(get_db), current_user: UserORM = Depends(get_current_user)):
    """Partially update a note for the logged-in user."""
    # note_id: int -> This is a path parameter. FastAPI extracts '1', '2', etc., from the URL and passes them as integers.
    # updated: NoteUpdate -> This is the body of the request. It uses the NoteUpdate schema, meaning the client can send only some fields (like just title) or all of them.
    note = note_service.update_note(db, note_id, updated, current_user.id)
    # note = note_service.update_note(db, note_id, updated) -> We call our service function.
    if not note:
        raise HTTPException(status_code=404, detail=ErrorMessages.NOTE_NOT_FOUND)
    return APIResponse(
        status_code=200,
        message=SuccessMessages.NOTE_UPDATED,
        data=NoteResponse.model_validate(note)
    )


@router.delete("/{note_id}", response_model=APIResponse[None])
def delete_note(note_id: int, db: Session = Depends(get_db), current_user: UserORM = Depends(get_current_user)):
    """Delete a note by ID for the logged-in user."""
    note = note_service.delete_note(db, note_id, current_user.id)
    # note = note_service.delete_note(db, note_id) -> We call our service function.
    if not note:
        raise HTTPException(status_code=404, detail=ErrorMessages.NOTE_NOT_FOUND)
    return APIResponse(
        status_code=200,
        message=SuccessMessages.NOTE_DELETED,
        data=None
    )