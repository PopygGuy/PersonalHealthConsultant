import os
from pathlib import Path
from typing import List
from pydantic_settings import BaseSettings


def _default_database_url() -> str:
    # Use a deterministic project-local SQLite path to avoid
    # cwd-dependent DB splits (./phc.db vs ./backend/phc.db).
    backend_root = Path(__file__).resolve().parents[1]
    sqlite_path = (backend_root / "phc.db").as_posix()
    return f"sqlite:///{sqlite_path}"


class Settings(BaseSettings):
    # Default to SQLite for easy local dev without Docker
    DATABASE_URL: str = os.getenv("DATABASE_URL", _default_database_url())
    SECRET_KEY: str = os.getenv("SECRET_KEY", "supersecretkey")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    CORS_ORIGINS: str = os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173,http://localhost:8000,http://127.0.0.1:8000",
    )
    CORS_ORIGIN_REGEX: str = os.getenv(
        "CORS_ORIGIN_REGEX",
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    )

    def cors_origins(self) -> List[str]:
        origins = [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]
        return origins if origins else ["http://localhost:3000"]

settings = Settings()
