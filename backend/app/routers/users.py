from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from typing import List
import re
from ..database import get_db
from .. import models, schemas, auth
from ..audit import log_event

router = APIRouter()
LOGIN_RE = re.compile(r"^[a-zA-Z0-9._]{3,32}$")


def _user_to_schema(db_user: models.User, db: Session) -> schemas.User:
    faculty_name = None
    group_name = None

    if db_user.faculty_id:
        faculty = (
            db.query(models.Faculty)
            .filter(models.Faculty.id == db_user.faculty_id)
            .first()
        )
        faculty_name = faculty.name if faculty else None

    if db_user.group_id:
        group = (
            db.query(models.Group)
            .filter(models.Group.id == db_user.group_id)
            .first()
        )
        group_name = group.name if group else None

    return schemas.User(
        id=db_user.id,
        login=db_user.login,
        role=db_user.role,
        full_name=db_user.full_name,
        faculty_id=db_user.faculty_id,
        group_id=db_user.group_id,
        faculty=faculty_name,
        group=group_name,
    )

@router.get("/users/me", response_model=schemas.User)
def read_users_me(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    return _user_to_schema(current_user, db)

@router.get("/users", response_model=List[schemas.User])
def read_users(role: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin and current_user.role != models.UserRole.teacher:
         raise HTTPException(status_code=403, detail="Not authorized")
    
    q = db.query(models.User)
    if role:
        q = q.filter(models.User.role == role)

    users = q.all()
    return [_user_to_schema(user, db) for user in users]

@router.post("/users", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    login = user.login.strip()
    if not login:
        raise HTTPException(status_code=400, detail="Логин не может быть пустым")
    if not LOGIN_RE.fullmatch(login):
        raise HTTPException(
            status_code=400,
            detail="Логин: 3-32 символа, только латинские буквы, цифры, точка и нижнее подчеркивание",
        )

    existing = (
        db.query(models.User)
        .filter(func.lower(models.User.login) == login.lower())
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=400, detail="Пользователь с таким логином уже существует")

    full_name = user.full_name.strip()
    if not full_name:
        raise HTTPException(status_code=400, detail="ФИО не может быть пустым")

    password = user.password.strip()
    if len(password) < 4:
        raise HTTPException(status_code=400, detail="Пароль должен быть не короче 4 символов")

    db_user = models.User(
        login=login,
        password_hash=auth.get_password_hash(password),
        role=user.role,
        full_name=full_name,
        faculty_id=user.faculty_id,
        group_id=user.group_id
    )
    db.add(db_user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Пользователь с таким логином уже существует")
    db.refresh(db_user)
    log_event(
        "user_created",
        actor=current_user.login,
        user_id=db_user.id,
        user_login=db_user.login,
        user_role=db_user.role.value,
    )
    return _user_to_schema(db_user, db)

@router.put("/users/{user_id}", response_model=schemas.User)
def update_user(
    user_id: str,
    payload: schemas.UserUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.full_name is not None:
        full_name = payload.full_name.strip()
        if not full_name:
            raise HTTPException(status_code=400, detail="Full name cannot be empty")
        db_user.full_name = full_name

    if payload.password is not None:
        password = payload.password.strip()
        if len(password) < 4:
            raise HTTPException(status_code=400, detail="Password must be at least 4 characters")
        db_user.password_hash = auth.get_password_hash(password)

    if db_user.role == models.UserRole.student:
        if payload.faculty_id is not None:
            db_user.faculty_id = payload.faculty_id or None
        if payload.group_id is not None:
            db_user.group_id = payload.group_id or None

    db.commit()
    db.refresh(db_user)
    log_event(
        "user_updated",
        actor=current_user.login,
        user_id=db_user.id,
        user_login=db_user.login,
    )
    return _user_to_schema(db_user, db)

@router.delete("/users/{user_id}")
def delete_user(user_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(db_user)
    db.commit()
    log_event(
        "user_deleted",
        actor=current_user.login,
        user_id=user_id,
        user_login=db_user.login,
    )
    return {"ok": True}
