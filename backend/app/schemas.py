from pydantic import BaseModel
from typing import Optional, List
from .models import UserRole

class UserBase(BaseModel):
    login: str
    role: UserRole
    full_name: str
    faculty_id: Optional[str] = None
    group_id: Optional[str] = None

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: str
    class Config:
        from_attributes = True

class FacultyBase(BaseModel):
    name: str

class Faculty(FacultyBase):
    id: str
    class Config:
        from_attributes = True

class GroupBase(BaseModel):
    name: str
    faculty_id: str

class Group(GroupBase):
    id: str
    class Config:
        from_attributes = True

class NormBase(BaseModel):
    name: str

class Norm(NormBase):
    id: str
    class Config:
        from_attributes = True

class GradeBase(BaseModel):
    student_id: str
    teacher_id: str
    norm_id: str
    score: int
    comment: Optional[str] = None

class GradeCreate(GradeBase):
    pass

class Grade(GradeBase):
    id: str
    date: str
    history: List[dict] = []
    class Config:
        from_attributes = True
