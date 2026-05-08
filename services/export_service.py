# services/export_service.py
# Background task logic for note exports — runs AFTER the response is sent.
import os
import time
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from models.note_orm import NoteORM
from models.activity_log_orm import ActivityLogORM


# Directory where export files are saved
EXPORTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "exports")


def export_notes_task(user_id: int, user_email: str, log_id: int, db: Session):
    """Fire-and-forget task: export all notes for a user to a Markdown file.

    This function is called by FastAPI's BackgroundTasks, meaning it runs
    AFTER the HTTP response has already been sent to the client.

    Steps:
        1. Fetch all notes for the user from the DB.
        2. Generate a Markdown file with the notes.
        3. Update the activity log with the result (completed / failed).
    """
    # Fetch the activity log entry so we can update its status
    log_entry = db.query(ActivityLogORM).filter(ActivityLogORM.id == log_id).first()
    if not log_entry:
        return

    try:
        # Step 1: Fetch all notes for this user
        notes = (
            db.query(NoteORM)
            .filter(NoteORM.user_id == user_id)
            .order_by(NoteORM.created_at.desc())
            .all()
        )

        # Step 2: Build the Markdown content
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")
        filename = f"notes_export_{user_id}_{timestamp}.md"

        lines = [
            f"# 📝 Notes Export",
            f"**User:** {user_email}  ",
            f"**Exported at:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}  ",
            f"**Total Notes:** {len(notes)}",
            "",
            "---",
            "",
        ]

        if not notes:
            lines.append("_No notes found._")
        else:
            for i, note in enumerate(notes, 1):
                personal_badge = " 🔒" if note.personal else ""
                lines.append(f"## {i}. {note.title}{personal_badge}")
                lines.append("")
                lines.append(note.description)
                lines.append("")
                lines.append(f"_Created: {note.created_at} · Updated: {note.updated_at}_")
                lines.append("")
                lines.append("---")
                lines.append("")

        markdown_content = "\n".join(lines)

        # Step 3: Write the file
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        file_path = os.path.join(EXPORTS_DIR, filename)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(markdown_content)

        # Simulate a small delay (as if sending email or uploading to cloud)
        time.sleep(2)

        # Step 4: Update the activity log — mark as completed
        log_entry.status = "completed"
        log_entry.detail = f"Exported {len(notes)} notes to {filename}"
        log_entry.file_path = file_path
        db.commit()

    except Exception as e:
        # If anything goes wrong, mark the log as failed
        log_entry.status = "failed"
        log_entry.detail = f"Export failed: {str(e)}"
        db.commit()
