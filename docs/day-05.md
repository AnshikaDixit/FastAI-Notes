# Day 05 — Protected Routes & Data Ownership

**Date:** 2026-05-07  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Now that we have a login system, the next goal was to make the API **private**. We set out to:
- Protect all "Notes" endpoints so only logged-in users can access them.
- Implement **Data Ownership**: Users should only see their *own* notes, not everyone's.
- Improve the developer experience for testing authenticated routes in Swagger UI.
- Fix security warnings regarding JWT key strength.

---

## 🏗️ What Was Built

1.  **Dual Security Schemes**: Support for both `OAuth2PasswordBearer` and `HTTPBearer`.
2.  **`get_current_user` Dependency**: A centralized gatekeeper that validates tokens and returns the user object.
3.  **Database Schema Update**: Linked the `notes` table to the `users` table via a Foreign Key.
4.  **Authenticated CRUD**: Refactored the entire Notes service to filter by the logged-in user's ID.
5.  **Auth Debug Endpoint**: Added `/auth/me` to quickly verify "Who am I?" via a token.

---

## 📦 Feature 1 — Multi-Scheme Authentication

We discovered that using only `OAuth2PasswordBearer` was difficult because our standardized "Wrapped" response format confused Swagger UI's automatic login.

### 🔐 The Solution: `HTTPBearer`
We added `HTTPBearer` to `services/auth_service.py`. 
- **Benefit**: It provides a simple "Paste Token" box in Swagger. 
- **Why?**: Since we manually get the token from `/auth/login`, we just need a place to paste it without Swagger trying to do a background login.

---

## 📦 Feature 2 — Data Ownership (user_id)

Before today, any user could see all notes. We changed this by adding a relationship between Users and Notes.

### Schema Changes (`models/note_orm.py`):
```python
user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
owner = relationship("UserORM", back_populates="notes")
```

### Filtering Logic (`services/note_service.py`):
We updated every database query to include a `.filter(NoteORM.user_id == user_id)` clause.
- **Signup** → Create User.
- **Login** → Get Token.
- **Create Note** → Automatically tagged with your ID.
- **List Notes** → Only shows your ID's notes.

---

## 📦 Feature 3 — Security Hardening

### 1. Insecure Key Warning
We were using a short 20-character secret key, which triggered an `InsecureKeyLengthWarning`.  
**Fix:** Generated a cryptographically secure 32-byte (64 hex characters) key using `openssl rand -hex 32` and updated the `.env` file.

### 2. Token Validation Logic
We added a check for the `type` claim in the JWT.
- **Access Token**: Allowed for API calls.
- **Refresh Token**: Rejected for API calls (only used to get new access tokens).

---

## 🧠 Smart Strategies Followed

### 1. The "Authorize" Gatekeeper
Instead of writing validation code in every route, we created a single `get_current_user` dependency. 
- **Code Reuse**: Any route can be protected by just adding `current_user: UserORM = Depends(get_current_user)`.
- **Security**: If the token is invalid, the request is stopped before it even touches your business logic.

### 2. Standardized 401 Responses
Even authentication errors now follow our `APIResponse` format:
```json
{
  "status_code": 401,
  "message": "Could not validate credentials",
  "data": null
}
```

---

## 🔄 The New Authenticated Flow

```
1. Client  → POST /auth/login
2. Server  → Returns JWT (starts with 'ey...')
3. Client  → GET /notes/  +  Header: Authorization: Bearer <token>
4. Dependency (get_current_user)
   - Decodes JWT 🔑
   - Checks expiry ⏰
   - Fetches User from DB 👤
5. Route Handler
   - Uses user_id to fetch ONLY that user's notes 📝
6. Client  → Receives their private data ✅
```

---

## 🐛 Problems Encountered & Fixed

### 1. `OperationalError: no such column: notes.user_id`
**Problem:** We added `user_id` to the Python code, but the old `notes.db` file didn't have that column.  
**Fix:** Deleted `notes.db` since we're in the initial stages of development. Then restarted the server. SQLAlchemy recreated the table with the new column automatically.

---

## ✅ End of Day 05 — What Works

| Feature | Status |
|---------|--------|
| `OAuth2PasswordBearer` Integration | ✅ Works |
| `HTTPBearer` (Simple Paste) | ✅ Works |
| Access Token Validation | ✅ Works |
| User Profile Discovery (`/auth/me`) | ✅ Works |
| User-Specific Note Creation | ✅ Works |
| Privacy (User A cannot see User B's notes) | ✅ Works |
| Secure 32-byte Secret Key | ✅ Works |

---

## 📌 Concepts Introduced on Day 05

| Concept | Introduced in |
|---------|--------------|
| `HTTPBearer` | `services/auth_service.py` |
| Foreign Key Relationships | `models/note_orm.py` |
| Relationship Back-populates | `models/user_orm.py` |
| `current_user` Dependency | `routers/notes.py` |
| Token Payload (`sub` & `type`) | `auth_service.py` |
| DB Schema Mismatches | Troubleshooting |
| Secure Secret Key Generation | `.env` configuration |
