# 📚 FastAI Notes — Project Documentation

This folder is the **single source of truth** for understanding this project.
Every day we build something new, a log entry is added here.

A new developer should be able to read these docs from top to bottom and fully understand:
- Why the project exists
- What was built and when
- Every technical decision and concept introduced

---

## 📖 Reading Order

| File | What it covers |
|------|---------------|
| [day-01.md](./day-01.md) | Project setup, FastAPI basics, in-memory CRUD → SQLite + SQLAlchemy migration, full project architecture |
| [day-02.md](./day-02.md) | Dockerization, Nginx reverse proxy, AWS EC2 deployment, data persistence with Docker volumes |

---

## 🗂️ Project Structure (current)

```
my-fastapi-app/
├── docs/                      ← You are here — all documentation lives here
│   ├── README.md              ← This file — docs index
│   └── day-01.md              ← Day 1 progress log
│
├── models/
│   ├── note.py                ← Pydantic schemas (request/response shapes)
│   └── note_orm.py            ← SQLAlchemy ORM model (DB table structure)
│
├── routers/
│   └── notes.py               ← API endpoints (thin layer, delegates to service)
│
├── services/
│   └── note_service.py        ← All DB CRUD logic lives here
│
├── database.py                ← SQLAlchemy engine, session factory, get_db()
├── main.py                    ← App entry point, table auto-creation, route registration
├── requirements.txt           ← Python dependencies
└── .gitignore                 ← Files excluded from version control
```

---

## 🔑 Key Concepts (quick reference)

| Concept | One-line explanation |
|---------|---------------------|
| FastAPI | Python web framework — maps URLs + HTTP methods to Python functions |
| Uvicorn | ASGI server that runs the FastAPI app |
| SQLAlchemy | ORM — lets you use Python classes instead of writing raw SQL |
| Pydantic | Validates and parses JSON in/out of the API |
| SQLite | Lightweight file-based database — stored as `notes.db` |
| ORM Model | Python class that represents a DB table (`note_orm.py`) |
| Pydantic Schema | Python class that represents request/response JSON shape (`note.py`) |
| Dependency Injection | `Depends(get_db)` — FastAPI auto-creates a DB session per request |
| Router | Groups related endpoints under a common URL prefix |
| Service Layer | Where business logic lives — keeps routers thin and testable |
