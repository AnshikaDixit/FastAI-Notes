# Day 04 — JWT Authentication & Response Standardization

**Date:** 2026-05-05  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Transition the project from a public API to a secure, professional architecture. The goal was to:
- Implement a robust **JWT-based authentication** system (Signup & Login).
- **Standardize API responses** across the entire project for a consistent client experience.
- Centralize all strings and error messages to follow **Clean Code** principles.

---

## 🏗️ What Was Built

By the end of Day 4, the project features:

1. **Full Auth System**: Secure user registration and login with hashed passwords.
2. **Dual-Token Strategy**: Access tokens (short-lived) and Refresh tokens (long-lived).
3. **Uniform Response Wrapper**: Every success and error response follows the exact same JSON shape.
4. **Global Exception Handlers**: Overridden default FastAPI error responses for consistency.
5. **Centralized Constant Management**: A single source of truth for all project messages.

---

## 📦 Phase 1 — JWT Authentication

We implemented authentication using **JSON Web Tokens (JWT)** and direct **bcrypt** hashing.

### 🔐 Why direct bcrypt?
Standard wrappers like `passlib` are currently unmaintained and have compatibility issues with newer Python versions (3.12+). By using the `bcrypt` library directly, we ensured the app is future-proof and high-performance.

### 📁 New Auth Files:
- `models/user_orm.py`: Defines the `users` table.
- `models/user.py`: Pydantic schemas for `UserCreate`, `UserResponse`, and `Token`.
- `services/auth_service.py`: Encapsulates hashing, verification, and token generation logic.
- `routers/auth.py`: Endpoints for `/auth/signup` and `/auth/login`.

### Token Expiration Standards:
- **Access Token**: 30 minutes (short-lived for security).
- **Refresh Token**: 7 days (long-lived for user convenience).

---

## 📦 Phase 2 — Response Standardization

To make the API "market standard," we ensured that every response follows a predictable pattern.

### `models/response_schema.py`
We used **Python Generics** to create a type-safe wrapper:

```python
from typing import Generic, TypeVar, Optional
from pydantic import BaseModel

T = TypeVar("T")

class APIResponse(BaseModel, Generic[T]):
    status_code: int
    message: str
    data: Optional[T] = None
```

### Success Response Example:
```json
{
  "status_code": 201,
  "message": "User created successfully",
  "data": { "id": 1, "email": "alice@example.com", ... }
}
```

---

## 📦 Phase 3 — Global Exception Handling

By default, FastAPI returns errors in its own format. We overrode this in `main.py` using **Exception Handlers** to maintain our uniform response format even when things go wrong.

```python
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=APIResponse(
            status_code=exc.status_code,
            message=str(exc.detail),
            data=None
        ).model_dump()
    )
```

This ensures that whether it's a `404 Not Found` or a `422 Validation Error`, the client receives a structured `APIResponse`.

---

## 🧠 Smart Strategies Followed

### 1. Centralized Message Constants (`utils/messages.py`)
We eliminated hardcoded strings. All success and error messages are now managed in a single class:
```python
class SuccessMessages:
    USER_CREATED = "User created successfully"
    # ...

class ErrorMessages:
    NOTE_NOT_FOUND = "Note not found"
    # ...
```
**Benefit:** Makes localization (adding new languages) or changing a message across the whole app as simple as updating one line.

### 2. Service Layer Pattern
We continued the pattern of keeping routers "thin." All logic for token expiration, password verification, and user lookup lives in `auth_service.py`.

### 3. Early Environment Loading
We moved `load_dotenv()` to the very top of `main.py`.  
**Why?** This ensures that secrets are available before any other module imports or initializes module-level constants (like `JWT_SECRET_KEY`).

---

## 🔄 Request Flow — Authenticated & Standardized

```
Client sends:  POST /auth/signup  { "email": "...", "password": "..." }
                │
                ▼
        main.py (app entry point)
        → loads .env variables first 🔐
        → registers global error handlers 🛡️
                │
                ▼
        routers/auth.py  →  signup()
        1. Checks if email exists in UserORM
        2. Calls auth_service.create_user()
                │
                ▼
        services/auth_service.py
        3. Encodes password to bytes
        4. Generates salt and hashes via bcrypt
        5. Returns new UserORM
                │
                ▼
        Back in routers/auth.py
        6. Wraps UserResponse in APIResponse helper
        7. Returns standardized JSON ✅
```

---

## 🐛 Problems Encountered & Fixed

### 1. `passlib` ValueError in Python 3.14
**Problem:** `passlib` triggered a `ValueError` during internal bug-checks on newer Python/bcrypt versions.  
**Fix:** Switched to using the `bcrypt` library directly in the service layer.

### 2. Undefined `JWT_SECRET_KEY`
**Problem:** `load_dotenv()` was called after router imports, causing env variables to be `None` at initialization.  
**Fix:** Moved `load_dotenv()` to the top of `main.py`.

### 3. Pydantic v2 Compatibility
**Problem:** Used `from_orm` which is deprecated in Pydantic v2.  
**Fix:** Updated all serialization to use `model_validate()`.

---

## ✅ End of Day 04 — What Works

| Feature | Status |
|---------|--------|
| User Signup with Hashing | ✅ Works |
| User Login (JWT Generation) | ✅ Works |
| Access & Refresh Tokens | ✅ Works |
| Standardized Response Structure | ✅ Works (Global) |
| Centralized Success/Error Strings | ✅ Works |
| Custom 404 & 422 Error Formats | ✅ Works |

---

## 📌 Concepts Introduced on Day 04

| Concept | Introduced in |
|---------|--------------|
| JWT Authentication Flow | `services/auth_service.py` |
| Password Salt & Hash | `bcrypt` implementation |
| Access vs Refresh Tokens | `auth_service.py` |
| Generic Response Wrapper | `models/response_schema.py` |
| Python Generic Types (`TypeVar`) | `response_schema.py` |
| Custom Exception Handlers | `main.py` |
| Centralized Message Constants | `utils/messages.py` |
| Early Env Loading | `main.py` |
| Pydantic v2 `model_validate` | `routers/auth.py` |
