from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import timedelta
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
import time
from .database import get_db
from . import models, schemas, auth
from .config import settings
from .routers import structures, users, norms, grades, steps, maintenance
from .audit import audit_logger, resolve_actor_from_request, log_event

app = FastAPI(
    title="PersonalHealthConsultant.API",
    swagger_ui_parameters={
        "docExpansion": "list",
        "defaultModelsExpandDepth": -1,
    },
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins(),
    allow_origin_regex=settings.CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(structures.router, tags=["structures"])
app.include_router(users.router, tags=["users"])
app.include_router(norms.router, tags=["norms"])
app.include_router(grades.router, tags=["grades"])
app.include_router(steps.router, tags=["steps"])
app.include_router(maintenance.router, tags=["maintenance"])

def _configure_audit_logging() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    logs_dir = backend_root / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    audit_file = logs_dir / "audit.log"

    audit_logger.setLevel(logging.INFO)
    audit_logger.propagate = False
    if audit_logger.handlers:
        return

    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    file_handler = RotatingFileHandler(
        audit_file,
        maxBytes=2 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    audit_logger.addHandler(file_handler)
    audit_logger.addHandler(console_handler)


_configure_audit_logging()


def _is_local_request(request: Request) -> bool:
    host = request.client.host if request.client else ""
    return host in {"127.0.0.1", "::1", "localhost"}


@app.post("/token")
async def login_for_access_token(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    login = form_data.username.strip()
    user = (
        db.query(models.User)
        .filter(func.lower(models.User.login) == login.lower())
        .first()
    )
    if not user or not auth.verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Restrict root login to the server machine only.
    if user.login == "root" and not _is_local_request(request):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Login for root is allowed only from the server device",
        )
    client_ip = request.client.host if request.client else "unknown"
    log_event(
        "login_success",
        login=user.login,
        role=user.role.value,
        ip=client_ip,
    )
    access_token_expires = timedelta(minutes=auth.settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.login, "role": user.role.value}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "role": user.role.value, "id": user.id, "full_name": user.full_name}


@app.post("/auth/logout")
def logout_audit(
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
):
    client_ip = request.client.host if request.client else "unknown"
    log_event(
        "logout_success",
        login=current_user.login,
        role=current_user.role.value,
        ip=client_ip,
    )
    return {"ok": True}


@app.middleware("http")
async def audit_http_requests(request: Request, call_next):
    started = time.time()
    response = await call_next(request)

    method = request.method.upper()
    if method in {"GET", "POST", "PUT", "DELETE"}:
        login, role = resolve_actor_from_request(request)
        client_ip = request.client.host if request.client else "unknown"
        duration_ms = int((time.time() - started) * 1000)
        log_event(
            "http_request",
            method=method,
            path=request.url.path,
            status=response.status_code,
            login=login,
            role=role,
            ip=client_ip,
            duration_ms=duration_ms,
        )
    return response

@app.get("/")
def read_root():
    return {"message": "Welcome to PHC API"}
