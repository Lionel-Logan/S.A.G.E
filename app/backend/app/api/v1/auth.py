from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.schemas import UserCreate, Token, UserResponse
from app.core.security import verify_password, get_password_hash, create_access_token
from app.dependencies import get_db, get_current_user
# Import your User model and database operations

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    """
    Register a new user
    
    - Creates account with email & password
    - Returns user details (no password)
    """
    # Check if user exists
    # Create new user with hashed password
    # Return user response
    pass

@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Login and get access token
    
    - Validates credentials
    - Returns JWT token for subsequent requests
    """
    # Verify user credentials
    # Generate JWT token
    # Return token
    pass

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user = Depends(get_current_user)):
    """
    Get current authenticated user's information
    """
    return current_user