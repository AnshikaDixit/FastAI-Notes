from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from models.user import UserCreate, UserResponse, Token
from models.user_orm import UserORM
from services import auth_service
from database import get_db
from models.response_schema import APIResponse
from utils.messages import SuccessMessages

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/signup", response_model=APIResponse[UserResponse], status_code=status.HTTP_201_CREATED)
def signup(user: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    existing = db.query(UserORM).filter(UserORM.email == user.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=ErrorMessages.EMAIL_EXISTS)
    db_user = auth_service.create_user(db, user)
    return APIResponse(
        status_code=201,
        message=SuccessMessages.USER_CREATED,
        data=UserResponse.model_validate(db_user)
    )

@router.post("/login", response_model=APIResponse[Token])
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = auth_service.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=ErrorMessages.INVALID_CREDENTIALS,
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = auth_service.create_access_token({"sub": str(user.id)})
    refresh_token = auth_service.create_refresh_token({"sub": str(user.id)})
    return APIResponse(
        status_code=200,
        message=SuccessMessages.LOGIN_SUCCESS,
        data=Token(access_token=access_token, refresh_token=refresh_token)
    )
