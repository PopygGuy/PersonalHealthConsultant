import os
import re
from pathlib import Path
from typing import List
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def _default_sqlite_path() -> Path:
    return Path(__file__).resolve().parents[1] / "phc.db"


def _default_database_url() -> str:
    # Always use a deterministic project-local SQLite path.
    return f"sqlite:///{_default_sqlite_path().as_posix()}"


def _normalize_sqlite_database_url(database_url: str) -> str:
    sqlite_prefix = "sqlite:///"
    if not database_url.startswith(sqlite_prefix):
        return database_url

    raw_path = database_url[len(sqlite_prefix) :].strip()
    if raw_path in {"", ":memory:"}:
        return database_url

    normalized_path = raw_path.replace("\\", "/")
    is_absolute = bool(
        normalized_path.startswith("/")
        or re.match(r"^[a-zA-Z]:/", normalized_path)
    )
    if is_absolute:
        return f"{sqlite_prefix}{Path(normalized_path).as_posix()}"

    # For any relative SQLite path (./phc.db, phc.db, backend/phc.db),
    # force a single canonical file to avoid DB duplication.
    return _default_database_url()


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Default to SQLite for easy local dev without Docker.
    # Relative sqlite URLs are normalized to backend/phc.db.
    DATABASE_URL: str = _default_database_url()
    SECRET_KEY: str = os.getenv("SECRET_KEY", "supersecretkey")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    CORS_ORIGINS: str = os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173,http://localhost:8000,http://127.0.0.1:8000",
    )
    CORS_ORIGIN_REGEX: str = os.getenv(
        "CORS_ORIGIN_REGEX",
        r"^https?://((localhost|127\.0\.0\.1)|(10\.\d+\.\d+\.\d+)|(192\.168\.\d+\.\d+)|(172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+))(:\d+)?$",
    )

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def validate_database_url(cls, value: str) -> str:
        raw_value = (value or "").strip()
        if not raw_value:
            return _default_database_url()
        if raw_value.startswith("sqlite"):
            return _normalize_sqlite_database_url(raw_value)
        return raw_value

    def cors_origins(self) -> List[str]:
        origins = [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]
        return origins if origins else ["http://localhost:3000"]

settings = Settings()
