# routers/export.py
# Routes for note export — demonstrates FastAPI BackgroundTasks (fire-and-forget).
from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from database import get_db
from services.auth_service import get_current_user
from services.export_service import export_notes_task
from models.user_orm import UserORM
from models.activity_log_orm import ActivityLogORM
from models.activity_log import ActivityLogResponse
from models.response_schema import APIResponse
from utils.messages import SuccessMessages

router = APIRouter(
    prefix="/export",
    tags=["Export (Background Tasks)"]   # groups them nicely in /docs
)


@router.post("/notes", status_code=202, response_model=APIResponse[ActivityLogResponse])
def trigger_notes_export(
    background_tasks: BackgroundTasks,
    # BackgroundTasks is injected by FastAPI automatically.
    # It gives us an .add_task() method to schedule work AFTER the response is sent.
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user),
):
    """Trigger an async export of all the user's notes to a Markdown file.

    How BackgroundTasks works:
        1. FastAPI receives the request and runs this function.
        2. We create an activity log (status="pending") and add a task to the queue.
        3. FastAPI sends the 202 response IMMEDIATELY to the client.
        4. AFTER the response is sent, FastAPI runs export_notes_task() in the background.
        5. The client can poll GET /export/history to check when it's done.

    Why 202 Accepted?
        HTTP 202 means "I've accepted your request, but it's not done yet."
        This is the correct status code for fire-and-forget operations.
    """
    # Step 1: Create a "pending" activity log entry in the DB
    log_entry = ActivityLogORM(
        user_id=current_user.id,
        action="note_export",
        status="pending",
        detail="Export job queued — processing in the background.",
    )
    db.add(log_entry)
    db.commit()
    db.refresh(log_entry)

    # Step 2: Schedule the heavy work to run AFTER the response is sent
    # background_tasks.add_task(func, *args)
    #   - func: the function to run in the background
    #   - *args: arguments passed to that function
    # Important: the background task gets its OWN db session to avoid conflicts
    background_tasks.add_task(
        export_notes_task,
        user_id=current_user.id,
        user_email=current_user.email,
        log_id=log_entry.id,
        db=db,
    )

    # Step 3: Return immediately — the client doesn't wait for the export!
    return APIResponse(
        status_code=202,
        message=SuccessMessages.EXPORT_STARTED,
        data=ActivityLogResponse.model_validate(log_entry),
    )


@router.get("/history", response_model=APIResponse[list[ActivityLogResponse]])
def get_export_history(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user),
):
    """Retrieve all export activity logs for the current user.

    The client can poll this endpoint to check if their export has completed.
    Each log entry has a `status` field: pending → completed / failed.
    """
    logs = (
        db.query(ActivityLogORM)
        .filter(ActivityLogORM.user_id == current_user.id)
        .order_by(ActivityLogORM.created_at.desc())
        .all()
    )
    return APIResponse(
        status_code=200,
        message=SuccessMessages.EXPORT_HISTORY_RETRIEVED,
        data=[ActivityLogResponse.model_validate(log) for log in logs],
    )
