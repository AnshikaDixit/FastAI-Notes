# models/activity_log_orm.py
# ORM model for the activity logs table — tracks background job results.
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class ActivityLogORM(Base):
    """SQLAlchemy ORM model for the 'activity_logs' table.

    Each row represents a fire-and-forget background task that was executed
    on behalf of a user (e.g., note export, email notification, etc.).
    """

    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action = Column(String, nullable=False)           # e.g., "note_export"
    status = Column(String, default="pending")         # pending → completed / failed
    detail = Column(Text, nullable=True)               # human-readable result or error
    file_path = Column(String, nullable=True)          # path to generated export file, if any

    owner = relationship("UserORM", back_populates="activity_logs")

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
