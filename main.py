# main.py 
#2. Where the app starts
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from database import engine, Base
from routers import notes, auth, export
from models.response_schema import APIResponse
from utils.messages import SuccessMessages, ErrorMessages

# Import all ORM models so Base.metadata.create_all() discovers every table
import models.note_orm        # noqa: F401 — registers NoteORM
import models.user_orm        # noqa: F401 — registers UserORM
import models.activity_log_orm  # noqa: F401 — registers ActivityLogORM

Base.metadata.create_all(bind=engine)   
# Whats happening?: This command scans all the classes that inherit from our Base (like our NoteORM) and creates the corresponding tables in the database.
# Why?: This is how we create our database structure (schema) without writing manual SQL commands like CREATE TABLE.

app = FastAPI(
    title="FastAI Notes API",
    description="A simple Notes CRUD API built with FastAPI and SQLite via SQLAlchemy.",
    version="1.0.0",
)

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

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=APIResponse(
            status_code=422,
            message=ErrorMessages.VALIDATION_ERROR,
            data=exc.errors()
        ).model_dump()
    )
# Whats happening?: This creates the main FastAPI application instance.
# Why?: This is the entry point for our entire API. All our routes (GET, POST, PUT, DELETE) will be attached to this app instance.

app.include_router(notes.router)
app.include_router(auth.router)
app.include_router(export.router)
# Whats happening?: This includes all the routes defined in the notes.py file into our main application.
# Why?: This is done to keep our code organized. Instead of putting all the routes in one file, we can put them in different files (e.g., note_routes.py, auth_routes.py) and include them here.

@app.get("/", response_model=APIResponse[None])
def read_root():
    return APIResponse(
        status_code=200,
        message=SuccessMessages.ROOT_MESSAGE,
        data=None
    )