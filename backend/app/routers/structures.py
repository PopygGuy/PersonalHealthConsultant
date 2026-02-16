from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from .. import models, schemas, auth

router = APIRouter()

@router.get("/faculties", response_model=List[schemas.Faculty])
def read_faculties(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    return db.query(models.Faculty).all()

@router.post("/faculties", response_model=schemas.Faculty)
def create_faculty(faculty: schemas.FacultyBase, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_faculty = models.Faculty(name=faculty.name)
    db.add(db_faculty)
    db.commit()
    db.refresh(db_faculty)
    return db_faculty

@router.delete("/faculties/{faculty_id}")
def delete_faculty(faculty_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db.query(models.Faculty).filter(models.Faculty.id == faculty_id).delete()
    db.commit()
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
    db_group = models.Group(name=group.name, faculty_id=group.faculty_id)
    db.add(db_group)
    db.commit()
    db.refresh(db_group)
    return db_group

@router.delete("/groups/{group_id}")
def delete_group(group_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db.query(models.Group).filter(models.Group.id == group_id).delete()
    db.commit()
    return {"ok": True}
