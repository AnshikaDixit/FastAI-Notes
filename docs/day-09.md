# Day 09 — Security Hardening: PIN Protection & Alembic Migrations

**Date:** 2026-05-11  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Today was all about **Security Hardening** and **Infrastructure Maturity**. We wanted to:
- Implement a **Security PIN system** to protect "Personal" notes from unauthorized viewing, even if someone gets access to the logged-in app.
- Transition from manual database management to **Alembic Migrations** to ensure database schema changes are tracked and reproducible across local and production (EC2) environments.
- Establish a robust **Sync & Deploy workflow** for Docker containers on EC2.

---

## 🏗️ What Was Built

### 1. Backend: PIN Security Infrastructure
- **Hashed Storage:** Added `hashed_pin` to `UserORM`. We use **bcrypt** for hashing (the same standard used for passwords) to ensure that even if the database is leaked, PINs remain secure.
- **Secure API Endpoints:** 
  - `POST /auth/pin/set`: For first-time setup.
  - `POST /auth/pin/verify`: For unlocking notes.
  - `POST /auth/pin/reset`: For updating an existing PIN.
  - `POST /auth/pin/forgot`: A recovery flow using the account password to clear a forgotten PIN.

### 2. Database: Migration Engine (Alembic)
- **Why Alembic?** Previously, we were manually deleting the database file to apply schema changes. In production (Docker/EC2), this is impossible as it would delete all user data.
- **Implementation:**
  - Configured `migrations/` directory with `env.py` and `script.py.mako`.
  - Enabled **Batch Mode** for SQLite: This allows adding/modifying columns in SQLite (which doesn't natively support many `ALTER TABLE` operations).
  - **Version Tracking:** Every change is now a Python script in `versions/`, allowing us to `upgrade` or `downgrade` at will.

### 3. Frontend: PIN Gating & Privacy
- **Automatic Masking:** In `NotesScreen`, descriptions of "Personal" notes are now automatically masked with `••••••••`.
- **Gatekeeper Modal:** Implemented a secure bottom sheet that prompts for a PIN when a user tries to view or edit a locked note.
- **Security Settings:** Added a 🛡️ **Shield Icon** to the top bar for managing security settings (Change/Forgot PIN).

---

## 🔄 The "Sync to Server" Workflow

We established a clean 3-step process to sync code changes with the EC2 production server:

1.  **Git Pull:** Fetch the latest migration scripts and code from GitHub.
2.  **Docker Rebuild:** Run `docker compose build --no-cache api` to bake the new code and migration tools into the production image.
3.  **Alembic Upgrade:** Run `docker exec -it <container> alembic upgrade head` to apply the database changes without losing existing user data.

---

## 🧠 Key Concepts Introduced on Day 09

| Concept | Why We Used It |
|---------|---------------|
| **Bcrypt PIN Hashing** | Ensures high-entropy security for 4-digit codes. |
| **Alembic Batch Mode** | Required for SQLite compatibility during `ALTER TABLE`. |
| **Alembic Stamp** | Used to synchronize the migration history when a column was added manually during testing. |
| **PIN Gating** | A UI pattern that intercepts user actions until authentication is provided. |
| **Safe Area Adoption** | Wrapped all screens in `SafeArea` to ensure compatibility with modern notched devices (Dynamic Island, etc.). |

---

## 📁 New Files & Major Updates

| File | Purpose |
|------|---------|
| `migrations/` | Entirely new directory for DB version control. |
| `alembic.ini` | Configuration for the Alembic migration engine. |
| `models/user_orm.py` | Updated with `hashed_pin` field. |
| `routers/auth.py` | Added 4 new PIN management endpoints. |
| `services/auth_service.py` | Core logic for PIN hashing and verification. |
| `flutter_client/lib/providers/auth_provider.dart` | Integrated PIN state management. |
| `flutter_client/lib/screens/notes_screen.dart` | Implemented 🛡️ Security UI and PIN gating logic. |

---

## ✅ End of Day 09 — What Works

| Feature | Status |
|---------|--------|
| Database versioning via Alembic | ✅ |
| Secure PIN Hashing (Bcrypt) | ✅ |
| Personal Note description masking | ✅ |
| PIN Verification modal in Flutter | ✅ |
| PIN Reset/Forgot flow via Password | ✅ |
| Seamless production sync (EC2 + Docker) | ✅ |

---

## 🔄 How to Run Migrations

**Local:**
```bash
./venv/bin/python3 -m alembic upgrade head
```

**Production (Docker):**
```bash
docker exec -it fastai-notes-api-1 alembic upgrade head
```

---

> 🔒 **Security Note**: We never store the plain PIN. We only store the bcrypt hash, ensuring the highest level of privacy for user notes.
