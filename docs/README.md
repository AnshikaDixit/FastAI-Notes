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
| [day-03.md](./day-03.md) | CI/CD with GitHub Actions — auto-deploy to EC2 on every git push |
| [day-04.md](./day-04.md) | 🔐 JWT Authentication, Response Standardization, and Centralized Constants |
| [day-05.md](./day-05.md) | 🛡️ Protected Routes, Data Ownership, and Security Hardening |
| [deployment-guide.md](./deployment-guide.md) | ⭐ Reusable step-by-step deployment reference — use this for any future project |

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
│   ├── note_orm.py            ← SQLAlchemy ORM model (DB table structure)
│   ├── user.py                ← User schemas & Auth models
│   ├── user_orm.py            ← User DB table structure
│   └── response_schema.py     ← Generic APIResponse wrapper
│
├── routers/
│   ├── notes.py               ← CRUD endpoints (with standardized responses)
│   └── auth.py                ← Signup & Login endpoints
│
├── services/
│   ├── note_service.py        ← DB logic for notes
│   └── auth_service.py        ← Password hashing & JWT logic
│
├── utils/
│   └── messages.py            ← Centralized Success & Error strings
│
├── database.py                ← SQLAlchemy engine, session factory, get_db()
├── main.py                    ← App entry point, table auto-creation, route registration, global exception handlers
├── requirements.txt           ← Python dependencies
├── .env                       ← Environment variables (Secrets)
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
| HTTPBearer | Security scheme that adds a simple "Paste Token" box in Swagger UI |
| Data Ownership | Concept where database records (notes) are linked to a specific user |
| Protected Route | Endpoint that requires a valid JWT token to access |
