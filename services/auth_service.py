import os
import jwt
from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from sqlalchemy.orm import Session
from database import get_db
from utils.messages import ErrorMessages
from models.user import UserCreate, UserResponse, Token
from models.user_orm import UserORM

import bcrypt

# Load environment variables
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

http_bearer = HTTPBearer()

def get_current_user(db: Session = Depends(get_db), auth: Optional[object] = Depends(http_bearer)) -> UserORM: 
    # auth is an HTTPAuthorizationCredentials object if using HTTPBearer
    token = auth.credentials if auth else None
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=ErrorMessages.AUTH_FAILED,
            headers={"WWW-Authenticate": "Bearer"},
        )
    # db: Session is like a temporary box for DB objects, asking for db connection, will last until the request is processed, closed after request is completed
    # token: It will automatically extract the Bearer Token from the request headers. If the token is missing, FastAPI will automatically throw an error.
    """Validate token and return the current authenticated user."""
    # credentials_exception: This is a custom exception that will be raised if the token is invalid. 
    #WWW-Authenticate: This header tells the client that the request has failed due to authentication. 
    # . HTTPException() creates an error response that FastAPI automatically sends to the client when raised.
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=ErrorMessages.AUTH_FAILED,
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # JWT is signed using your private key, so only the server can verify it.
        # payload: The decoded token data
        # token: raw token
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        user_id: str = payload.get("sub") # sub is the subject (user id we said while creating token)
        token_type: str = payload.get("type") # type is the token type (access or refresh)
        if user_id is None or token_type != "access":
            # If the user_id or token_type is missing or invalid, raise the credentials_exception.
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        # jwt.ExpiredSignatureError: This exception is raised when the token has expired.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=ErrorMessages.TOKEN_EXPIRED,
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        # jwt.PyJWTError: This exception is raised when the token is invalid.
        raise credentials_exception

    user = db.query(UserORM).filter(UserORM.id == int(user_id)).first() # query(UserORM): This tells SQLAlchemy to look into the UserORM table.
                                                                        # .filter(...): This applies a WHERE clause.
                                                                        # .first(): This executes the query and returns only the first result (or None if no rows match).
    if user is None:
        raise credentials_exception # If the user_id is not found in the database, raise the credentials_exception.
    return user

def get_password_hash(password: str) -> str:
    """Return a bcrypt hash of the given password."""
    # bcrypt.hashpw expects bytes
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against its bcrypt hash."""
    pwd_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(pwd_bytes, hashed_bytes)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS))
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def authenticate_user(db: Session, email: str, password: str) -> Optional[UserORM]:
    user = db.query(UserORM).filter(UserORM.email == email).first()
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user

def create_user(db: Session, user_in: UserCreate) -> UserORM:
    hashed_password = get_password_hash(user_in.password)
    db_user = UserORM(email=user_in.email, hashed_password=hashed_password, full_name=user_in.full_name)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user
