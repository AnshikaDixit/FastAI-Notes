from pydantic import BaseModel, EmailStr, ConfigDict
from datetime import datetime

class UserCreate(BaseModel):
    """Schema for user signup. Password will be hashed before storing."""
    email: EmailStr
    password: str
    full_name: str | None = None

    model_config = ConfigDict(extra="forbid")

class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    """Schema returned after user creation (no password)."""
    id: int
    email: EmailStr
    full_name: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    """JWT access & refresh token pair returned on login."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

    model_config = ConfigDict()
