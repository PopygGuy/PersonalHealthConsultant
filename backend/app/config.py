import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Default to SQLite for easy local dev without Docker
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./phc.db")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "supersecretkey")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

settings = Settings()
