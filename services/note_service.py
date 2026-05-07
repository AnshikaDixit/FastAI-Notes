# services/note_service.py
# 5. The actual DB logic
# All database CRUD logic lives here — keeps routers thin and logic testable.
from sqlalchemy.orm import Session
from models.note_orm import NoteORM
from models.note import NoteCreate, NoteUpdate


def create_note(db: Session, note_data: NoteCreate, user_id: int) -> NoteORM: 
    """Insert a new note into the database and return the created ORM object."""
    db_note = NoteORM(**note_data.model_dump(), user_id=user_id) 
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    return db_note


def get_all_notes(db: Session, user_id: int) -> list[NoteORM]:
    """Return all notes for a specific user, ordered by most recently created."""
    return db.query(NoteORM).filter(NoteORM.user_id == user_id).order_by(NoteORM.created_at.desc()).all()


def get_note_by_id(db: Session, note_id: int, user_id: int) -> NoteORM | None:
    """Return a single note by ID for a specific user, or None if not found."""
    return db.query(NoteORM).filter(NoteORM.id == note_id, NoteORM.user_id == user_id).first()


def update_note(db: Session, note_id: int, update_data: NoteUpdate, user_id: int) -> NoteORM | None:
    """Partially update a note for a specific user."""
    db_note = get_note_by_id(db, note_id, user_id)
    if not db_note:
        return None

    # exclude_unset=True: only update fields the client actually provided
    for field, value in update_data.model_dump(exclude_unset=True).items():
        setattr(db_note, field, value)

    db.commit()
    db.refresh(db_note)
    return db_note


def delete_note(db: Session, note_id: int, user_id: int) -> NoteORM | None:
    """Delete a note by ID for a specific user."""
    db_note = get_note_by_id(db, note_id, user_id)
    if not db_note:
        return None

    db.delete(db_note)
    db.commit()
    return db_note
