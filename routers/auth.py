from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from models.user import UserCreate, UserResponse, Token, UserLogin, PinRequest, PinUpdate
from models.user_orm import UserORM
from services import auth_service
from database import get_db
from models.response_schema import APIResponse
from utils.messages import SuccessMessages, ErrorMessages

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
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    user = auth_service.authenticate_user(db, login_data.email, login_data.password)
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
    
@router.get("/me", response_model=APIResponse[UserResponse])
def get_me(current_user: UserORM = Depends(auth_service.get_current_user)):
    """Retrieve the current logged-in user's profile."""
    return APIResponse(
        status_code=200,
        message="User profile retrieved",
        data=UserResponse.model_validate(current_user)
    )

# --- PIN Management Endpoints ---

@router.post("/pin/set", response_model=APIResponse[UserResponse])
def set_pin(
    pin_data: PinRequest, 
    db: Session = Depends(get_db), 
    current_user: UserORM = Depends(auth_service.get_current_user)
):
    """Set the initial PIN for a user."""
    auth_service.set_user_pin(db, current_user, pin_data.pin)
    return APIResponse(
        status_code=200,
        message="PIN set successfully",
        data=UserResponse.model_validate(current_user)
    )

@router.post("/pin/verify", response_model=APIResponse[bool])
def verify_pin(
    pin_data: PinRequest, 
    current_user: UserORM = Depends(auth_service.get_current_user)
):
    """Verify if the provided PIN is correct."""
    is_valid = auth_service.verify_user_pin(current_user, pin_data.pin)
    if not is_valid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect PIN")
    return APIResponse(
        status_code=200,
        message="PIN verified successfully",
        data=True
    )

@router.post("/pin/reset", response_model=APIResponse[UserResponse])
def reset_pin(
    reset_data: PinUpdate, 
    db: Session = Depends(get_db), 
    current_user: UserORM = Depends(auth_service.get_current_user)
):
    """Change PIN. Requires verification if old_pin is provided, otherwise acts as force reset."""
    if reset_data.old_pin:
        if not auth_service.verify_user_pin(current_user, reset_data.old_pin):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Old PIN is incorrect")
    
    auth_service.set_user_pin(db, current_user, reset_data.new_pin)
    return APIResponse(
        status_code=200,
        message="PIN updated successfully",
        data=UserResponse.model_validate(current_user)
    )

@router.post("/pin/forgot", response_model=APIResponse[UserResponse])
def forgot_pin(
    login_data: UserLogin, 
    db: Session = Depends(get_db),
    # Note: No current_user dependency here as user might be logged out or forgot PIN
):
    """Reset PIN by verifying user's password."""
    user = auth_service.authenticate_user(db, login_data.email, login_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=ErrorMessages.INVALID_CREDENTIALS)
    
    # We clear the PIN so they can set a new one
    user.hashed_pin = None
    db.commit()
    db.refresh(user)
    return APIResponse(
        status_code=200,
        message="PIN has been reset. Please set a new one.",
        data=UserResponse.model_validate(user)
    )
