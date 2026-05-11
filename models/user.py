from pydantic import BaseModel, EmailStr, ConfigDict, field_validator
from datetime import datetime
from typing import Optional

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
    has_pin: bool = False
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    """JWT access & refresh token pair returned on login."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

    model_config = ConfigDict()

class PinRequest(BaseModel):
    """Schema for setting or verifying a PIN."""
    pin: str

    @field_validator("pin")
    @classmethod
    def validate_pin(cls, v):
        if not v.isdigit() or len(v) != 4:
            raise ValueError("PIN must be exactly 4 digits")
        return v

class PinUpdate(BaseModel):
    """Schema for changing a PIN."""
    old_pin: Optional[str] = None
    new_pin: str

    @field_validator("new_pin")
    @classmethod
    def validate_pin(cls, v):
        if not v.isdigit() or len(v) != 4:
            raise ValueError("PIN must be exactly 4 digits")
        return v
