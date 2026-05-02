# Day 01 — Project Setup + SQLite Integration

**Date:** 2026-05-01  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Build a **Notes CRUD API** using FastAPI — a Python web framework — as a learning project to understand:
- How REST APIs work
- How FastAPI handles routing, validation, and documentation
- How to connect a Python app to a real database using SQLAlchemy

---

## 🏗️ What Was Built

By end of Day 1, the project had:

1. A working FastAPI app with 5 REST endpoints for Notes (Create, Read, Update, Delete)
2. Pydantic schemas for request/response validation
3. SQLite database connected via SQLAlchemy ORM
4. A proper layered architecture: Router → Service → Database
5. Auto-generated interactive API docs at `/docs`

---

## 📦 Phase 1 — Project Skeleton

### What is FastAPI?

FastAPI is a **Python web framework** for building APIs quickly. Key things it gives you:

- **Route decorators** (`@app.get`, `@app.post`, etc.) — map URLs to Python functions
- **Automatic validation** via Pydantic — if client sends wrong data, FastAPI rejects it automatically
- **Auto-generated Swagger UI** at `/docs` — a browser-based interface to test all endpoints
- **Dependency Injection** — auto-provides things like DB sessions to your route functions

**Real-world analogy:** FastAPI is the waiter at a restaurant. It takes orders from clients, validates them, talks to the kitchen (database), and brings back the food (response).

---

### Initial File Structure

The project started with this shape:

```
my-fastapi-app/
├── main.py            ← App entry point
├── models/
│   └── note.py        ← Pydantic data shapes
├── routers/
│   └── notes.py       ← API endpoint definitions
├── database.py        ← (was empty on Day 1 start)
└── requirements.txt   ← (was empty on Day 1 start)
```

---

### `requirements.txt` — The Dependency List

```
fastapi           # the web framework itself
uvicorn[standard] # the server that actually runs FastAPI (like Apache/Nginx, but lightweight)
sqlalchemy        # the ORM — lets you use Python objects instead of raw SQL
pydantic          # validates and parses JSON data
```

**Why uvicorn?** FastAPI itself doesn't serve HTTP — it just defines the logic. Uvicorn is the actual web server that listens for requests and passes them to FastAPI.

Install everything with:
```bash
pip install -r requirements.txt
```

---

### `main.py` — Where the App Starts

```python
from fastapi import FastAPI
from routers import notes

app = FastAPI(
    title="FastAI Notes API",
    description="A simple Notes CRUD API built with FastAPI and SQLite via SQLAlchemy.",
    version="1.0.0",
)

app.include_router(notes.router)

@app.get("/")
def read_root():
    return {"message": "Notes API is running!"}
```

**Key things happening:**
- `FastAPI()` creates the app instance — the title/description show up in the auto-generated Swagger docs at `/docs`
- `app.include_router(notes.router)` registers all the notes routes (defined in `routers/notes.py`) into the main app
- The `/` route is a health check — hit it to confirm the server is alive

**Run the server with:**
```bash
uvicorn main:app --reload
```
- `main` = the file `main.py`
- `app` = the FastAPI instance inside it
- `--reload` = auto-restart on file save (dev only)

---

## 📐 Phase 2 — Pydantic Schemas (`models/note.py`)

Pydantic is the validation layer. Every piece of data coming **into** or going **out of** the API is defined as a Pydantic class.

```python
from pydantic import BaseModel, ConfigDict
from datetime import datetime

class NoteBase(BaseModel):      # Shared fields
    title: str
    description: str
    personal: bool | None = None

class NoteCreate(NoteBase):     # What the CLIENT sends to CREATE a note
    pass                        # Inherits all fields from NoteBase

class NoteUpdate(BaseModel):    # What the CLIENT sends to UPDATE a note
    title: str | None = None    # All fields optional — partial update
    description: str | None = None
    personal: bool | None = None

class NoteResponse(NoteBase):   # What the SERVER sends BACK to the client
    id: int
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)
```

**Why separate schemas?**

| Schema | Used when | Has `id`? | Has timestamps? |
|--------|-----------|-----------|-----------------|
| `NoteCreate` | Client creates a note | ❌ (DB generates it) | ❌ (DB generates them) |
| `NoteUpdate` | Client updates a note | ❌ | ❌ |
| `NoteResponse` | Server replies to client | ✅ | ✅ |

**`model_config = ConfigDict(from_attributes=True)`** — this tells Pydantic "you might receive a SQLAlchemy ORM object instead of a plain dict, and that's fine — read its attributes directly." Without this, Pydantic would crash when trying to serialize a database object.

**What Pydantic does automatically:**
- If a client sends `{"title": 123}` (number instead of string), Pydantic rejects it with HTTP `422 Unprocessable Entity` — before your code even runs.
- If a client sends extra fields not in the schema, Pydantic ignores them.

---

## 🗄️ Phase 3 — Database Layer

### Why SQLite?

SQLite is a **file-based database** — no server to install, no configuration. Perfect for learning and local development. The entire database lives in a single file: `notes.db` at the project root.

When the app grows, you can switch to PostgreSQL or MySQL by changing just one line (`DATABASE_URL`).

---

### `database.py` — The Connection Setup

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

DATABASE_URL = "sqlite:///./notes.db"

# Engine: the core SQLAlchemy object that manages the actual DB connection
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
    # check_same_thread=False is SQLite-specific:
    # allows the same DB connection to be used across multiple threads
    # (needed because FastAPI handles requests in a threadpool)
)

# Session Factory: each request gets its own fresh session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
# autocommit=False → data is NOT saved until you explicitly call db.commit()
# autoflush=False  → SQLAlchemy won't auto-sync pending changes to DB unexpectedly
# bind=engine      → tells sessions which DB to connect to

# Base: empty parent class all ORM models will inherit from
class Base(DeclarativeBase):
    pass

# get_db: FastAPI dependency — provides a DB session per request
def get_db():
    db = SessionLocal()   # open a fresh session
    try:
        yield db          # pause here, hand the session to the route function
    finally:
        db.close()        # always close after request, no matter what
```

**What `yield` does here (important):**  
`get_db()` is a generator function. `yield db` means: "pause this function, give `db` to whoever called me, and when they're done, come back here and run the `finally` block." This guarantees the session is always closed — even if an error occurs mid-request.

---

### `models/note_orm.py` — The Database Table Blueprint

```python
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from database import Base

class NoteORM(Base):
    __tablename__ = "notes"   # maps this class to the 'notes' table in SQLite

    id          = Column(Integer, primary_key=True, index=True)
    title       = Column(String, nullable=False)
    description = Column(String, nullable=False)
    personal    = Column(Boolean, default=False, nullable=True)
    created_at  = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at  = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
```

**What is an ORM?**  
ORM = Object-Relational Mapper. Instead of writing raw SQL:
```sql
INSERT INTO notes (title, description) VALUES ('My Note', 'Hello');
```
You write Python:
```python
note = NoteORM(title="My Note", description="Hello")
db.add(note)
db.commit()
```
SQLAlchemy translates your Python objects into SQL behind the scenes.

**Two model files — why?**

| File | Talks to | Purpose |
|------|----------|---------|
| `models/note_orm.py` | SQLite database | Defines the DB table structure |
| `models/note.py` | HTTP clients | Defines JSON request/response shapes |

They look similar but serve completely different layers. Mixing them causes circular import errors and breaks separation of concerns.

**`server_default=func.now()`** — lets SQLite automatically set the timestamp when a row is inserted. You never touch these fields manually in your Python code.

---

## 🔧 Phase 4 — Service Layer (`services/note_service.py`)

The service layer is where **all the database logic lives**. Routers should never talk to the database directly — they delegate to the service.

```python
from sqlalchemy.orm import Session
from models.note_orm import NoteORM
from models.note import NoteCreate, NoteUpdate

def create_note(db: Session, note_data: NoteCreate) -> NoteORM:
    db_note = NoteORM(**note_data.model_dump())
    # model_dump() converts the Pydantic object to a plain dict: {"title": "...", ...}
    # **note_data.model_dump() unpacks that dict as keyword arguments to NoteORM(...)
    db.add(db_note)      # stage the object for insertion
    db.commit()          # write to the database
    db.refresh(db_note)  # reload from DB to get auto-generated id + timestamps
    return db_note

def get_all_notes(db: Session) -> list[NoteORM]:
    return db.query(NoteORM).order_by(NoteORM.created_at.desc()).all()

def get_note_by_id(db: Session, note_id: int) -> NoteORM | None:
    return db.query(NoteORM).filter(NoteORM.id == note_id).first()

def update_note(db: Session, note_id: int, update_data: NoteUpdate) -> NoteORM | None:
    db_note = get_note_by_id(db, note_id)
    if not db_note:
        return None
    for field, value in update_data.model_dump(exclude_unset=True).items():
        # exclude_unset=True → only process fields the client actually sent
        # (if client only sends {"title": "New"}, don't touch description or personal)
        setattr(db_note, field, value)
    db.commit()
    db.refresh(db_note)
    return db_note

def delete_note(db: Session, note_id: int) -> NoteORM | None:
    db_note = get_note_by_id(db, note_id)
    if not db_note:
        return None
    db.delete(db_note)
    db.commit()
    return db_note
```

**Why isolate this in a service?**
- You can **test these functions without a running web server** — just pass a mock `db`
- If you switch from SQLite to PostgreSQL, you only change this layer
- Routers stay clean — they just call a function and return the result

**`-> NoteORM` — What does the arrow mean?**  
It's a Python **return type hint**. `-> NoteORM` means "this function returns a `NoteORM` object." It's documentation for you and your IDE — not enforced at runtime, but your editor uses it for autocomplete and warnings.

---

## 🛣️ Phase 5 — Router Layer (`routers/notes.py`)

The router is the **API interface** — it defines what URLs exist and what HTTP methods they respond to. It's intentionally thin: validate input → call service → return result.

```python
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from database import get_db
from models.note import NoteCreate, NoteUpdate, NoteResponse
import services.note_service as note_service

router = APIRouter(prefix="/notes", tags=["Notes"])
# prefix="/notes" → all routes automatically get /notes prepended
# tags=["Notes"]  → groups these endpoints together in the Swagger UI at /docs
```

### The 5 Endpoints

#### POST `/notes/` — Create a note
```python
@router.post("/", status_code=201, response_model=NoteResponse)
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
    return note_service.create_note(db, note)
```
- `note: NoteCreate` — FastAPI reads the JSON body, validates it against `NoteCreate`, and gives you the object
- `db: Session = Depends(get_db)` — FastAPI calls `get_db()`, gives you the session, closes it after
- `response_model=NoteResponse` — FastAPI converts the returned `NoteORM` into a `NoteResponse` JSON automatically
- `status_code=201` — HTTP 201 Created (more accurate than 200 for resource creation)

#### GET `/notes/` — List all notes
```python
@router.get("/", response_model=list[NoteResponse])
def list_notes(db: Session = Depends(get_db)):
    return note_service.get_all_notes(db)
```

#### GET `/notes/{note_id}` — Get one note
```python
@router.get("/{note_id}", response_model=NoteResponse)
def get_note(note_id: int, db: Session = Depends(get_db)):
    note = note_service.get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note
```
- `note_id: int` — path parameter. FastAPI extracts the number from the URL (`/notes/1` → `note_id=1`)
- `HTTPException(404)` — returns `{"detail": "Note not found"}` with HTTP 404

#### PUT `/notes/{note_id}` — Update a note
```python
@router.put("/{note_id}", response_model=NoteResponse)
def update_note(note_id: int, updated: NoteUpdate, db: Session = Depends(get_db)):
    note = note_service.update_note(db, note_id, updated)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note
```
- `updated: NoteUpdate` — all fields optional, so the client can send just `{"title": "New Title"}` without touching other fields

#### DELETE `/notes/{note_id}` — Delete a note
```python
@router.delete("/{note_id}")
def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = note_service.delete_note(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return {"message": "Note deleted", "id": note_id}
```

---

## 🔄 Request Flow — End-to-End

Let's trace a full `POST /notes/` request:

```
Client sends:  POST /notes/  { "title": "Shopping List", "description": "Eggs, milk" }
                │
                ▼
        main.py (app entry point)
        → routes to notes.router because URL starts with /notes
                │
                ▼
        routers/notes.py  →  create_note()
        1. FastAPI reads JSON body → validates → NoteCreate object ✅
        2. FastAPI calls get_db() → opens a fresh DB session
        3. Calls note_service.create_note(db, note)
                │
                ▼
        services/note_service.py  →  create_note()
        4. NoteORM(**note_data.model_dump()) → creates DB object
        5. db.add() → stages for insert
        6. db.commit() → writes to notes.db
        7. db.refresh() → reloads to get id + timestamps
        8. Returns NoteORM object
                │
                ▼
        Back in routers/notes.py
        9. FastAPI sees response_model=NoteResponse
        10. Converts NoteORM → NoteResponse (Pydantic serialization)
        11. get_db() finally block → db.close()
                │
                ▼
Client gets:   HTTP 201  { "id": 1, "title": "Shopping List", "description": "Eggs, milk",
                           "personal": null, "created_at": "...", "updated_at": "..." }
```

---

## 🐛 Problems Encountered & Fixed

### 1. `database.py` was empty
**Problem:** File existed but had no content — SQLAlchemy wasn't set up at all.  
**Fix:** Implemented engine, SessionLocal, Base, and get_db() from scratch.

### 2. `requirements.txt` was empty
**Problem:** `pip install -r requirements.txt` installed nothing.  
**Fix:** Pinned all 4 dependencies: fastapi, uvicorn[standard], sqlalchemy, pydantic.

### 3. In-memory `notes` dict + global `counter` in router
**Problem:** All data lost on every server restart. Not thread-safe.  
**Fix:** Replaced with SQLite via SQLAlchemy. Data now persists in `notes.db`.

### 4. Deprecated `.dict()` (Pydantic v2)
**Problem:** `note.dict()` is deprecated in Pydantic v2 — triggers warnings.  
**Fix:** Replaced with `.model_dump()` throughout.

### 5. Old-style Pydantic Config
**Problem:** `class Config: from_attributes = True` is Pydantic v1 style.  
**Fix:** Replaced with `model_config = ConfigDict(from_attributes=True)`.

### 6. No `.gitignore`
**Problem:** `__pycache__/`, `.DS_Store`, `venv/` were all committed in the initial commit.  
**Fix:** Added `.gitignore`. Ran `git rm -r --cached` to untrack already-committed files.

---

## ✅ End of Day 1 — What Works

```bash
uvicorn main:app --reload   # start the server
```

Visit **http://127.0.0.1:8000/docs** — the Swagger UI is auto-generated.

| Endpoint | Method | What it does |
|----------|--------|-------------|
| `/notes/` | POST | Create a new note |
| `/notes/` | GET | List all notes |
| `/notes/{id}` | GET | Get one note by ID |
| `/notes/{id}` | PUT | Update a note (partial) |
| `/notes/{id}` | DELETE | Delete a note |

Data persists in `notes.db` across server restarts. ✅

---

## 📌 Concepts Introduced on Day 1

| Concept | Introduced in |
|---------|--------------|
| FastAPI app setup | `main.py` |
| Route decorators (`@router.post`, etc.) | `routers/notes.py` |
| Pydantic BaseModel + validation | `models/note.py` |
| `response_model` — automatic serialization | `routers/notes.py` |
| SQLAlchemy ORM models | `models/note_orm.py` |
| `create_engine`, `SessionLocal` | `database.py` |
| `Depends(get_db)` — dependency injection | `routers/notes.py` |
| `yield` in generator dependencies | `database.py` |
| `db.add() / db.commit() / db.refresh()` | `services/note_service.py` |
| `model_dump(exclude_unset=True)` — partial updates | `services/note_service.py` |
| `HTTPException` — manual error responses | `routers/notes.py` |
| Return type hints (`-> NoteORM`) | `services/note_service.py` |
| Service layer pattern | `services/note_service.py` |
| `.gitignore` + `git rm --cached` | project root |
