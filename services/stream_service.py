# services/stream_service.py
# Async generator for streaming the note export via SSE (Server-Sent Events).
# Contrast with export_service.py which writes to a file in the background.
import json
import asyncio
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from models.note_orm import NoteORM


async def stream_export_sse(db: Session, user_id: int, user_email: str):
    """Async generator that streams a Markdown note export as SSE events.

    This is the STREAMING counterpart to export_service.py's fire-and-forget approach:
        - Day 06 (export_service): Client fires POST, gets 202, checks back later.
        - Day 07 (stream_service): Client connects, watches the export happen LIVE.

    Each yielded string is one SSE event. The client sees progress in real time:
        1. "progress" event  → "Preparing export..."
        2. "chunk" events    → actual Markdown lines streamed one-by-one
        3. "complete" event  → "Export finished!"

    Why async + await asyncio.sleep()?
        - time.sleep() blocks the entire event loop (freezes the server).
        - asyncio.sleep() only pauses THIS coroutine, letting other requests
          continue being served.
    """
    # Fetch notes
    notes = (
        db.query(NoteORM)
        .filter(NoteORM.user_id == user_id)
        .order_by(NoteORM.created_at.desc())
        .all()
    )

    # --- Event 1: Export starting ---
    yield format_sse_event(
        event="progress",
        data={
            "step": "start",
            "message": f"Preparing export for {user_email}...",
            "total_notes": len(notes),
        },
        event_id="0",
    )
    await asyncio.sleep(0.5)

    # --- Event 2: Stream the Markdown header ---
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    header = (
        f"# 📝 Notes Export\n"
        f"**User:** {user_email}  \n"
        f"**Exported at:** {timestamp}  \n"
        f"**Total Notes:** {len(notes)}\n\n"
        f"---\n\n"
    )
    yield format_sse_event(
        event="chunk",
        data={"content": header},
        event_id="1",
    )
    await asyncio.sleep(0.3)

    # --- Events 3..N: Stream each note as a separate chunk ---
    if not notes:
        yield format_sse_event(
            event="chunk",
            data={"content": "_No notes found._\n"},
            event_id="2",
        )
    else:
        for i, note in enumerate(notes, 1):
            # Progress update
            yield format_sse_event(
                event="progress",
                data={
                    "step": "exporting",
                    "message": f"Exporting note {i} of {len(notes)}: {note.title}",
                    "current": i,
                    "total_notes": len(notes),
                },
                event_id=f"progress-{i}",
            )
            await asyncio.sleep(0.4)

            # The actual Markdown content for this note
            personal_badge = " 🔒" if note.personal else ""
            note_md = (
                f"## {i}. {note.title}{personal_badge}\n\n"
                f"{note.description}\n\n"
                f"_Created: {note.created_at} · Updated: {note.updated_at}_\n\n"
                f"---\n\n"
            )
            yield format_sse_event(
                event="chunk",
                data={"content": note_md},
                event_id=f"chunk-{i}",
            )
            await asyncio.sleep(0.3)

    # --- Final Event: Export complete ---
    yield format_sse_event(
        event="complete",
        data={
            "message": "Export finished!",
            "total_notes": len(notes),
        },
        event_id="done",
    )


def format_sse_event(event: str, data: dict, event_id: str | None = None) -> str:
    """Format a dictionary into a valid SSE text block.

    SSE format spec (each field on its own line):
        event: progress
        id: 3
        data: {"message": "Exporting note 2 of 5..."}

        ← blank line = end of event

    The data field is JSON-serialized so the Dart client can parse it with jsonDecode().
    """
    lines = []
    if event:
        lines.append(f"event: {event}")
    if event_id is not None:
        lines.append(f"id: {event_id}")
    lines.append(f"data: {json.dumps(data)}")
    lines.append("")  # blank line = end of this SSE event
    lines.append("")  # extra newline for separation
    return "\n".join(lines)
