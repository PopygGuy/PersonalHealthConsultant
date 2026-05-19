from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, inspect, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from .. import models, schemas, auth
from ..audit import log_event

router = APIRouter()


def _ensure_norm_status_column(db: Session) -> None:
    inspector = inspect(db.bind)
    columns = {c["name"] for c in inspector.get_columns("norms")}
    if "is_active" not in columns:
        db.execute(
            text("ALTER TABLE norms ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT 1")
        )
        db.commit()


@router.get("/norms", response_model=List[schemas.Norm])
def read_norms(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    _ensure_norm_status_column(db)
    return db.query(models.Norm).all()

@router.post("/norms", response_model=schemas.Norm)
def create_norm(norm: schemas.NormBase, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    _ensure_norm_status_column(db)
    # Assuming only teachers or admins can create norms?
    # Requirement: "API for Teacher -> CRUD for Norms"
    if current_user.role != models.UserRole.teacher and current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    name = norm.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Название норматива не может быть пустым")

    existing = (
        db.query(models.Norm)
        .filter(func.lower(models.Norm.name) == name.lower())
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=400, detail="Норматив с таким названием уже существует")

    db_norm = models.Norm(name=name, is_active=True)
    db.add(db_norm)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Норматив с таким названием уже существует")
    db.refresh(db_norm)
    log_event(
        "norm_created",
        actor=current_user.login,
        role=current_user.role.value,
        norm_id=db_norm.id,
        norm_name=db_norm.name,
        is_active=db_norm.is_active,
    )
    return db_norm

@router.delete("/norms/{norm_id}")
def delete_norm(norm_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.teacher and current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_norm = db.query(models.Norm).filter(models.Norm.id == norm_id).first()
    if db_norm is None:
        raise HTTPException(status_code=404, detail="Норматив не найден")
    db.delete(db_norm)
    db.commit()
    log_event(
        "norm_deleted",
        actor=current_user.login,
        role=current_user.role.value,
        norm_id=norm_id,
        norm_name=db_norm.name,
    )
    return {"ok": True}


@router.put("/norms/{norm_id}/status", response_model=schemas.Norm)
def update_norm_status(
    norm_id: str,
    payload: schemas.NormStatusUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.role != models.UserRole.teacher and current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    _ensure_norm_status_column(db)

    db_norm = db.query(models.Norm).filter(models.Norm.id == norm_id).first()
    if db_norm is None:
        raise HTTPException(status_code=404, detail="Норматив не найден")

    db_norm.is_active = bool(payload.is_active)
    db.commit()
    db.refresh(db_norm)
    log_event(
        "norm_status_updated",
        actor=current_user.login,
        role=current_user.role.value,
        norm_id=db_norm.id,
        norm_name=db_norm.name,
        is_active=db_norm.is_active,
    )
    return db_norm
