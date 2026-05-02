# services/note_service.py
# All database CRUD logic lives here — keeps routers thin and logic testable.
from sqlalchemy.orm import Session
from models.note_orm import NoteORM
from models.note import NoteCreate, NoteUpdate


def create_note(db: Session, note_data: NoteCreate) -> NoteORM:
    """Insert a new note into the database and return the created ORM object."""
    db_note = NoteORM(**note_data.model_dump())
    db.add(db_note)
    db.commit()
    db.refresh(db_note)  # reload to get DB-generated fields (id, created_at, updated_at)
    return db_note


def get_all_notes(db: Session) -> list[NoteORM]:
    """Return all notes ordered by most recently created."""
    return db.query(NoteORM).order_by(NoteORM.created_at.desc()).all()


def get_note_by_id(db: Session, note_id: int) -> NoteORM | None:
    """Return a single note by ID, or None if not found."""
    return db.query(NoteORM).filter(NoteORM.id == note_id).first()


def update_note(db: Session, note_id: int, update_data: NoteUpdate) -> NoteORM | None:
    """Partially update a note. Only fields explicitly sent by the client are changed."""
    db_note = get_note_by_id(db, note_id)
    if not db_note:
        return None

    # exclude_unset=True: only update fields the client actually provided
    for field, value in update_data.model_dump(exclude_unset=True).items():
        setattr(db_note, field, value)

    db.commit()
    db.refresh(db_note)
    return db_note


def delete_note(db: Session, note_id: int) -> NoteORM | None:
    """Delete a note by ID. Returns the deleted object, or None if not found."""
    db_note = get_note_by_id(db, note_id)
    if not db_note:
        return None

    db.delete(db_note)
    db.commit()
    return db_note
