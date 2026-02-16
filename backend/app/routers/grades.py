from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from .. import models, schemas, auth
from datetime import datetime

router = APIRouter()

@router.post("/grades", response_model=schemas.Grade)
def create_grade(grade: schemas.GradeCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.teacher:
         raise HTTPException(status_code=403, detail="Not authorized")
    
    db_grade = models.Grade(
        student_id=grade.student_id,
        teacher_id=current_user.id,
        norm_id=grade.norm_id,
        score=grade.score,
        comment=grade.comment,
        date=datetime.utcnow(),
        history=[{"score": grade.score, "date": datetime.utcnow().isoformat(), "comment": grade.comment}]
    )
    db.add(db_grade)
    db.commit()
    db.refresh(db_grade)
    return db_grade

@router.get("/grades", response_model=List[schemas.Grade])
def read_grades(student_id: str = None, norm_id: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    q = db.query(models.Grade)
    
    if current_user.role == models.UserRole.student:
        q = q.filter(models.Grade.student_id == current_user.id)
    
    if student_id:
        q = q.filter(models.Grade.student_id == student_id)
    if norm_id:
        q = q.filter(models.Grade.norm_id == norm_id)
        
    return q.all()

@router.get("/grades/me", response_model=List[schemas.Grade])
def read_my_grades(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.student:
         raise HTTPException(status_code=403, detail="Not authorized for non-students")
    return db.query(models.Grade).filter(models.Grade.student_id == current_user.id).all()
