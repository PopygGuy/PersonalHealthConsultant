from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from ..database import get_db
from .. import models, auth

router = APIRouter()

class StepStatsBase(BaseModel):
    date: str
    steps: int
    goal: int
    stride_meters: float
    height_cm: Optional[int] = None
    is_custom_stride: bool

class StepStatsCreate(StepStatsBase):
    pass

class StepStats(StepStatsBase):
    id: str
    user_id: str
    class Config:
        from_attributes = True

@router.get("/steps/{date}", response_model=StepStats)
def read_steps(date: str, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    stats = db.query(models.StepStats).filter(
        models.StepStats.user_id == current_user.id,
        models.StepStats.date == date
    ).first()
    
    if not stats:
        # Return default if not found
        return StepStats(
            id="",
            user_id=current_user.id,
            date=date,
            steps=0,
            goal=10000,
            stride_meters=0.7,
            height_cm=None,
            is_custom_stride=False
        )
    
    # Convert DB types to Pydantic
    return StepStats(
        id=stats.id,
        user_id=stats.user_id,
        date=stats.date,
        steps=stats.steps,
        goal=stats.goal,
        stride_meters=float(stats.stride_meters) if stats.stride_meters else 0.7,
        height_cm=stats.height_cm,
        is_custom_stride=bool(stats.is_custom_stride)
    )

@router.post("/steps", response_model=StepStats)
def update_steps(stats: StepStatsCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    db_stats = db.query(models.StepStats).filter(
        models.StepStats.user_id == current_user.id,
        models.StepStats.date == stats.date
    ).first()
    
    if db_stats:
        db_stats.steps = stats.steps
        db_stats.goal = stats.goal
        db_stats.stride_meters = str(stats.stride_meters)
        db_stats.height_cm = stats.height_cm
        db_stats.is_custom_stride = 1 if stats.is_custom_stride else 0
    else:
        db_stats = models.StepStats(
            user_id=current_user.id,
            date=stats.date,
            steps=stats.steps,
            goal=stats.goal,
            stride_meters=str(stats.stride_meters),
            height_cm=stats.height_cm,
            is_custom_stride=1 if stats.is_custom_stride else 0
        )
        db.add(db_stats)
    
    db.commit()
    db.refresh(db_stats)
    
    return StepStats(
        id=db_stats.id,
        user_id=db_stats.user_id,
        date=db_stats.date,
        steps=db_stats.steps,
        goal=db_stats.goal,
        stride_meters=float(db_stats.stride_meters),
        height_cm=db_stats.height_cm,
        is_custom_stride=bool(db_stats.is_custom_stride)
    )
