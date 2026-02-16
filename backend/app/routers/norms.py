from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from .. import models, schemas, auth

router = APIRouter()

@router.get("/norms", response_model=List[schemas.Norm])
def read_norms(db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    return db.query(models.Norm).all()

@router.post("/norms", response_model=schemas.Norm)
def create_norm(norm: schemas.NormBase, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    # Assuming only teachers or admins can create norms?
    # Requirement: "API for Teacher -> CRUD for Norms"
    if current_user.role != models.UserRole.teacher and current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_norm = models.Norm(name=norm.name)
    db.add(db_norm)
    db.commit()
    db.refresh(db_norm)
    return db_norm

@router.delete("/norms/{norm_id}")
def delete_norm(norm_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != models.UserRole.teacher and current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")
    db.query(models.Norm).filter(models.Norm.id == norm_id).delete()
    db.commit()
    return {"ok": True}
