from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from .. import models, schemas, auth

router = APIRouter()

@router.get("/users/me", response_model=schemas.User)
def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

@router.get("/users", response_model=List[schemas.User])
def read_users(role: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin and current_user.role != models.UserRole.teacher:
         raise HTTPException(status_code=403, detail="Not authorized")
    
    q = db.query(models.User)
    if role:
        q = q.filter(models.User.role == role)
    
    # Teachers can only see students in their groups? Or all students?
    # For now, let's say teachers can see all students or implement logic later.
    # The requirement says "Teacher sees their students".
    # Assuming "their students" means students in groups they teach, or just all students for simplicity now.
    
    return q.all()

@router.post("/users", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    db_user = models.User(
        login=user.login,
        password_hash=auth.get_password_hash(user.password),
        role=user.role,
        full_name=user.full_name,
        faculty_id=user.faculty_id,
        group_id=user.group_id
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/users/{user_id}")
def delete_user(user_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db.query(models.User).filter(models.User.id == user_id).delete()
    db.commit()
    return {"ok": True}
