# routers/notes.py
from fastapi import APIRouter, HTTPException
from models.note import NoteCreate, NoteUpdate, NoteResponse

router = APIRouter(
    prefix="/notes",        # all routes here auto get /notes prefix
    tags=["Notes"]          # groups them in /docs
)

# In-memory store (will move to DB later)
notes = {}
counter = 1


@router.post("/", status_code=201, response_model=NoteResponse)
def create_note(note: NoteCreate):
    global counter
    note_dict = {"id": counter, **note.dict()}
    notes[counter] = note_dict
    counter += 1
    return note_dict


@router.get("/", response_model=list[NoteResponse])
def list_notes():
    return list(notes.values())


@router.get("/{note_id}", response_model=NoteResponse)
def get_note(note_id: int):
    if note_id not in notes:
        raise HTTPException(status_code=404, detail="Note not found")
    return notes[note_id]


@router.put("/{note_id}", response_model=NoteResponse)
def update_note(note_id: int, updated: NoteUpdate):
    if note_id not in notes:
        raise HTTPException(status_code=404, detail="Note not found")
    existing = notes[note_id]
    existing.update(updated.dict(exclude_unset=True)) # Only give me what the user explicitly sent, ignore everything else, so you never accidentally overwrite fields the user didn't intend to update
    return existing


@router.delete("/{note_id}")
def delete_note(note_id: int):
    if note_id not in notes:
        raise HTTPException(status_code=404, detail="Note not found")
    deleted = notes.pop(note_id)
    return {"message": "Note deleted", "note": deleted}