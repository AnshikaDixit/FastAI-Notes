class SuccessMessages:
    # Auth messages
    USER_CREATED = "User created successfully"
    LOGIN_SUCCESS = "Login successful"
    
    # Note messages
    NOTE_CREATED = "Note created successfully"
    NOTES_RETRIEVED = "Notes retrieved successfully"
    NOTE_RETRIEVED = "Note retrieved successfully"
    NOTE_UPDATED = "Note updated successfully"
    NOTE_DELETED = "Note deleted successfully"
    
    # Export messages
    EXPORT_STARTED = "Export job started — processing in the background"
    EXPORT_HISTORY_RETRIEVED = "Export history retrieved successfully"

    # General messages
    ROOT_MESSAGE = "Notes API is running!"

class ErrorMessages:
    # Auth errors
    EMAIL_EXISTS = "Email already registered"
    INVALID_CREDENTIALS = "Incorrect email or password"
    
    # Note errors
    NOTE_NOT_FOUND = "Note not found"
    
    # Global errors
    VALIDATION_ERROR = "Validation error"
    AUTH_FAILED = "Could not validate credentials"
    TOKEN_EXPIRED = "Token has expired"
    INACTIVE_USER = "Inactive user"
