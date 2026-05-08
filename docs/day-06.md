# Day 06 — Background Tasks (Fire-and-Forget)

**Date:** 2026-05-08  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Learn and implement **FastAPI BackgroundTasks** — the built-in mechanism for running fire-and-forget jobs. We wanted to:
- Build a real feature that uses background processing (note export).
- Understand when and why to use `BackgroundTasks` vs. heavier tools like Celery.
- Introduce an **Activity Log** (audit trail) to track background job results.
- Return an instant `202 Accepted` response while work continues in the background.

---

## 🏗️ What Was Built

1. **`POST /export/notes`** — Triggers a background export of all user notes to a Markdown file. Returns `202 Accepted` immediately.
2. **`GET /export/history`** — Polls the activity log to check export status (`pending → completed / failed`).
3. **`activity_logs` DB table** — Tracks every background job: who triggered it, what happened, and where the result file is.
4. **`exports/` directory** — Where generated Markdown files are saved.

---

## 📦 Feature 1 — FastAPI BackgroundTasks

### What is `BackgroundTasks`?
FastAPI provides a built-in `BackgroundTasks` class that lets you schedule functions to run **after** the HTTP response has been sent. The client never waits for these tasks to complete.

### How it works:
```
1. Client → POST /export/notes  (with Bearer token)
2. Server → Creates activity log (status="pending")
3. Server → Adds export_notes_task to BackgroundTasks queue
4. Server → Returns 202 Accepted IMMEDIATELY ← client gets response here
5. Background → export_notes_task() runs silently:
   - Fetches all user notes from DB
   - Generates Markdown file
   - Updates activity log → status="completed"
6. Client → GET /export/history to check if it's done
```

### The Key Code (`routers/export.py`):
```python
from fastapi import BackgroundTasks

@router.post("/notes", status_code=202)
def trigger_notes_export(
    background_tasks: BackgroundTasks,  # ← FastAPI injects this automatically
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user),
):
    # 1. Create a "pending" log entry
    log_entry = ActivityLogORM(user_id=current_user.id, action="note_export", status="pending")
    db.add(log_entry)
    db.commit()

    # 2. Schedule heavy work AFTER the response
    background_tasks.add_task(export_notes_task, user_id=..., log_id=..., db=db)

    # 3. Return instantly — client doesn't wait!
    return APIResponse(status_code=202, message="Export started", data=...)
```

### Why `202 Accepted`?
- `200 OK` = "Done, here's your result."
- `202 Accepted` = "Got it, I'm working on it — check back later."
- This is the correct HTTP semantics for async/fire-and-forget operations.

---

## 📦 Feature 2 — Activity Log (Audit Trail)

### New Table: `activity_logs`
```python
class ActivityLogORM(Base):
    __tablename__ = "activity_logs"

    id        = Column(Integer, primary_key=True)
    user_id   = Column(Integer, ForeignKey("users.id"))   # who triggered it
    action    = Column(String)                              # what: "note_export"
    status    = Column(String, default="pending")           # pending → completed / failed
    detail    = Column(Text)                                # human-readable result
    file_path = Column(String)                              # path to export file
```

### Why an Activity Log?
- **Traceability**: You can see exactly what background jobs ran and whether they succeeded.
- **Polling**: The client can check `GET /export/history` to see when jobs finish.
- **Extensibility**: Future tasks (email, analytics, cleanup) all log here too.

---

## 📦 Feature 3 — Markdown Export File

The background task generates a clean Markdown file in the `exports/` directory:

```markdown
# 📝 Notes Export
**User:** user@example.com
**Exported at:** 2026-05-08 12:00:00 UTC
**Total Notes:** 3

---

## 1. My First Note
Description of the note here.
_Created: 2026-05-07 · Updated: 2026-05-07_

---
```

Personal notes get a 🔒 badge in the export.

---

## 🧠 Key Concepts Explained

### When to use `BackgroundTasks` vs. Celery?

| Feature | `BackgroundTasks` | Celery |
|---------|-------------------|--------|
| Setup | Zero — built into FastAPI | Needs Redis/RabbitMQ |
| Best for | Quick tasks (< 30s) | Long/heavy tasks (minutes+) |
| Retry logic | ❌ None | ✅ Built-in |
| Distributed | ❌ Same process | ✅ Separate workers |
| Our use case | ✅ Perfect fit | Overkill |

### `create_all()` vs. Alembic — When Do You Need Migrations?

| Scenario | `create_all()` | Needs Alembic? |
|----------|----------------|----------------|
| **New table** (like `activity_logs`) | ✅ Auto-creates it | ❌ No |
| **Add column to existing table** | ❌ Ignores it | ✅ Yes |
| **Rename/drop column** | ❌ Ignores it | ✅ Yes |

Since `activity_logs` was a brand new table, `create_all()` handled it perfectly — no Alembic needed.

---

## 📁 New Files Created

| File | Purpose |
|------|---------|
| `models/activity_log_orm.py` | SQLAlchemy ORM model for the `activity_logs` table |
| `models/activity_log.py` | Pydantic response schema for activity logs |
| `services/export_service.py` | The actual background task logic (fetch → generate → write) |
| `routers/export.py` | API routes: trigger export + view history |

## 📁 Files Modified

| File | Change |
|------|--------|
| `main.py` | Added `export` router + explicit ORM imports |
| `models/user_orm.py` | Added `activity_logs` relationship |
| `utils/messages.py` | Added export success messages |
| `.gitignore` | Added `exports/` directory |

---

## 🔄 How to Test

```bash
# 1. Login to get a token
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpassword"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# 2. Trigger export (returns 202 instantly)
curl -s -X POST http://localhost:8000/export/notes \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# 3. Wait a few seconds, then check history
curl -s http://localhost:8000/export/history \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# 4. Check the generated file
ls exports/
cat exports/notes_export_*.md
```

---

## ✅ End of Day 06 — What Works

| Feature | Status |
|---------|--------|
| `POST /export/notes` returns `202 Accepted` | ✅ Works |
| Background task runs after response sent | ✅ Works |
| Activity log created with `pending` status | ✅ Works |
| Activity log updated to `completed` | ✅ Works |
| Markdown export file generated | ✅ Works |
| `GET /export/history` shows all logs | ✅ Works |
| `activity_logs` table auto-created | ✅ Works |
| Protected by JWT (same as notes) | ✅ Works |

---

## 📌 Concepts Introduced on Day 06

| Concept | Introduced in |
|---------|--------------|
| `BackgroundTasks` | `routers/export.py` |
| `background_tasks.add_task()` | `routers/export.py` |
| Fire-and-forget pattern | `services/export_service.py` |
| HTTP `202 Accepted` | `routers/export.py` |
| Activity Log / Audit Trail | `models/activity_log_orm.py` |
| Job status tracking (pending → completed) | `services/export_service.py` |
| `create_all()` vs Alembic | `main.py` |
