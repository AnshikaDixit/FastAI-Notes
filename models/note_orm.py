# models/note_orm.py
#4. What a Note looks like in the DB
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class NoteORM(Base):
    """SQLAlchemy ORM model for the 'notes' table."""

    __tablename__ = "notes" 
    # Whats Happening?: We are telling SQLAlchemy that this Python class (NoteORM) corresponds to the 'notes' table in the database. 
    # Why?: This is needed so that SQLAlchemy knows which table in the database this class is related to.

    id = Column(Integer, primary_key=True, index=True) 
    title = Column(String, nullable=False) 
    description = Column(String, nullable=False) 
    personal = Column(Boolean, default=False, nullable=True) 
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    owner = relationship("UserORM", back_populates="notes")

    # server_default=func.now() lets the DB set these automatically
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
