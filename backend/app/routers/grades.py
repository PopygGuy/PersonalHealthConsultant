from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from sqlalchemy import inspect, text
from ..database import get_db
from .. import models, schemas, auth
from datetime import datetime

router = APIRouter()


def _default_academic_year(now: datetime) -> str:
    start_year = now.year if now.month >= 9 else now.year - 1
    return f"{start_year}/{start_year + 1}"


def _ensure_grade_period_columns(db: Session) -> None:
    inspector = inspect(db.bind)
    columns = {c["name"] for c in inspector.get_columns("grades")}
    if "academic_year" not in columns:
        db.execute(text("ALTER TABLE grades ADD COLUMN academic_year TEXT NOT NULL DEFAULT ''"))
    if "course" not in columns:
        db.execute(text("ALTER TABLE grades ADD COLUMN course INTEGER NOT NULL DEFAULT 1"))
    if "semester" not in columns:
        db.execute(text("ALTER TABLE grades ADD COLUMN semester INTEGER NOT NULL DEFAULT 1"))
    db.commit()

@router.post("/grades", response_model=schemas.Grade)
def create_grade(grade: schemas.GradeCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.teacher:
         raise HTTPException(status_code=403, detail="Not authorized")

    _ensure_grade_period_columns(db)

    if grade.course < 1 or grade.course > 6:
        raise HTTPException(status_code=400, detail="Курс должен быть от 1 до 6")
    if grade.semester < 1 or grade.semester > 2:
        raise HTTPException(status_code=400, detail="Семестр должен быть 1 или 2")
    if grade.score < 1 or grade.score > 5:
        raise HTTPException(status_code=400, detail="Оценка должна быть от 1 до 5")
    now = datetime.utcnow()
    academic_year = (grade.academic_year or "").strip() or _default_academic_year(now)

    existing = db.query(models.Grade).filter(
        models.Grade.student_id == grade.student_id,
        models.Grade.norm_id == grade.norm_id,
        models.Grade.academic_year == academic_year,
        models.Grade.course == grade.course,
        models.Grade.semester == grade.semester,
    ).first()

    if existing is not None:
        if grade.score == existing.score:
            raise HTTPException(
                status_code=400,
                detail="Такая же оценка уже выставлена для этого норматива в выбранном учебном периоде",
            )
        if grade.score < existing.score:
            raise HTTPException(
                status_code=400,
                detail="Понижать балл нельзя. Допустимо только повышение или другой учебный период",
            )

        history = list(existing.history or [])
        history.append(
            {
                "score": existing.score,
                "date": existing.date.isoformat() if existing.date else now.isoformat(),
                "comment": existing.comment,
            }
        )
        existing.history = history
        existing.score = grade.score
        existing.comment = grade.comment
        existing.date = now
        existing.teacher_id = current_user.id
        db.commit()
        db.refresh(existing)
        return existing

    db_grade = models.Grade(
        student_id=grade.student_id,
        teacher_id=current_user.id,
        norm_id=grade.norm_id,
        academic_year=academic_year,
        course=grade.course,
        semester=grade.semester,
        score=grade.score,
        comment=grade.comment,
        date=now,
        history=[],
    )
    db.add(db_grade)
    db.commit()
    db.refresh(db_grade)
    return db_grade

@router.get("/grades", response_model=List[schemas.Grade])
def read_grades(
    student_id: str = None,
    norm_id: str = None,
    academic_year: str = None,
    course: int = None,
    semester: int = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    _ensure_grade_period_columns(db)
    q = db.query(models.Grade)
    
    if current_user.role == models.UserRole.student:
        q = q.filter(models.Grade.student_id == current_user.id)
    
    if student_id:
        q = q.filter(models.Grade.student_id == student_id)
    if norm_id:
        q = q.filter(models.Grade.norm_id == norm_id)
    if academic_year:
        q = q.filter(models.Grade.academic_year == academic_year)
    if course is not None:
        q = q.filter(models.Grade.course == course)
    if semester is not None:
        q = q.filter(models.Grade.semester == semester)
        
    return q.all()

@router.get("/grades/me", response_model=List[schemas.Grade])
def read_my_grades(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.student:
         raise HTTPException(status_code=403, detail="Not authorized for non-students")
    _ensure_grade_period_columns(db)
    return db.query(models.Grade).filter(models.Grade.student_id == current_user.id).all()
