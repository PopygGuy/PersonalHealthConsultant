from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import List
from ..database import get_db
from .. import models, schemas, auth
from ..audit import log_event

router = APIRouter()

@router.get("/faculties", response_model=List[schemas.Faculty])
def read_faculties(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    return db.query(models.Faculty).all()

@router.post("/faculties", response_model=schemas.Faculty)
def create_faculty(faculty: schemas.FacultyBase, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    name = faculty.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Название факультета не может быть пустым")
    if db.query(models.Faculty).filter(models.Faculty.name == name).first():
        raise HTTPException(status_code=400, detail="Факультет с таким названием уже существует")

    db_faculty = models.Faculty(name=name)
    db.add(db_faculty)
    try:
        db.commit()
        db.refresh(db_faculty)
        log_event(
            "faculty_created",
            actor=current_user.login,
            faculty_id=db_faculty.id,
            faculty_name=db_faculty.name,
        )
        return db_faculty
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Факультет с таким названием уже существует")

@router.delete("/faculties/{faculty_id}")
def delete_faculty(faculty_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_faculty = db.query(models.Faculty).filter(models.Faculty.id == faculty_id).first()
    if db_faculty is None:
        raise HTTPException(status_code=404, detail="Факультет не найден")
    db.delete(db_faculty)
    db.commit()
    log_event(
        "faculty_deleted",
        actor=current_user.login,
        faculty_id=faculty_id,
        faculty_name=db_faculty.name,
    )
    return {"ok": True}

@router.get("/groups", response_model=List[schemas.Group])
def read_groups(faculty_id: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    q = db.query(models.Group)
    if faculty_id:
        q = q.filter(models.Group.faculty_id == faculty_id)
    return q.all()

@router.post("/groups", response_model=schemas.Group)
def create_group(group: schemas.GroupBase, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    name = group.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Название группы не может быть пустым")
    if db.query(models.Group).filter(models.Group.name == name).first():
        raise HTTPException(status_code=400, detail="Группа с таким названием уже существует")
    if not db.query(models.Faculty).filter(models.Faculty.id == group.faculty_id).first():
        raise HTTPException(status_code=400, detail="Выбранный факультет не найден")

    db_group = models.Group(name=name, faculty_id=group.faculty_id)
    db.add(db_group)
    try:
        db.commit()
        db.refresh(db_group)
        log_event(
            "group_created",
            actor=current_user.login,
            group_id=db_group.id,
            group_name=db_group.name,
            faculty_id=db_group.faculty_id,
        )
        return db_group
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Группа с таким названием уже существует")

@router.delete("/groups/{group_id}")
def delete_group(group_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_group = db.query(models.Group).filter(models.Group.id == group_id).first()
    if db_group is None:
        raise HTTPException(status_code=404, detail="Группа не найдена")
    db.delete(db_group)
    db.commit()
    log_event(
        "group_deleted",
        actor=current_user.login,
        group_id=group_id,
        group_name=db_group.name,
    )
    return {"ok": True}
