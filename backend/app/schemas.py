from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from .models import UserRole

class UserBase(BaseModel):
    login: str
    role: UserRole
    full_name: str
    faculty_id: Optional[str] = None
    group_id: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    password: Optional[str] = None
    faculty_id: Optional[str] = None
    group_id: Optional[str] = None

class User(UserBase):
    id: str
    faculty: Optional[str] = None
    group: Optional[str] = None
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
    is_active: bool = True
    class Config:
        from_attributes = True


class NormStatusUpdate(BaseModel):
    is_active: bool

class GradeBase(BaseModel):
    student_id: str
    norm_id: str
    academic_year: str = ""
    course: int = 1
    semester: int = 1
    score: int
    comment: Optional[str] = None

class GradeCreate(BaseModel):
    student_id: str
    norm_id: str
    academic_year: str = ""
    course: int = 1
    semester: int = 1
    score: int
    comment: Optional[str] = None

class Grade(GradeBase):
    teacher_id: str
    id: str
    date: datetime
    history: List[dict] = []
    class Config:
        from_attributes = True

