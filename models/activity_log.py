# models/activity_log.py — Pydantic schemas for activity log responses
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class ActivityLogResponse(BaseModel):
    """Schema returned to the client for activity log entries."""
    id: int
    action: str
    status: str
    detail: str | None = None
    file_path: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
