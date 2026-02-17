from sqlalchemy import Column, String, Integer, ForeignKey, Enum, DateTime, Text, JSON
from sqlalchemy.orm import relationship
from .database import Base
import enum
from datetime import datetime
import uuid

def generate_uuid():
    return str(uuid.uuid4())

class UserRole(enum.Enum):
    admin = "admin"
    teacher = "teacher"
    student = "student"

class Faculty(Base):
    __tablename__ = "faculties"
    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, unique=True, index=True)
    groups = relationship("Group", back_populates="faculty")

class Group(Base):
    __tablename__ = "groups"
    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, unique=True, index=True)
    faculty_id = Column(String, ForeignKey("faculties.id"))
    faculty = relationship("Faculty", back_populates="groups")

class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, default=generate_uuid)
    login = Column(String, unique=True, index=True)
    password_hash = Column(String)
    role = Column(Enum(UserRole))
    full_name = Column(String)
    faculty_id = Column(String, ForeignKey("faculties.id"), nullable=True)
    group_id = Column(String, ForeignKey("groups.id"), nullable=True)

class Norm(Base):
    __tablename__ = "norms"
    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, unique=True, index=True)

class Grade(Base):
    __tablename__ = "grades"
    id = Column(String, primary_key=True, default=generate_uuid)
    student_id = Column(String, ForeignKey("users.id"))
    teacher_id = Column(String, ForeignKey("users.id"))
    norm_id = Column(String, ForeignKey("norms.id"))
    academic_year = Column(String, default="")
    course = Column(Integer, default=1)
    semester = Column(Integer, default=1)
    score = Column(Integer)
    date = Column(DateTime, default=datetime.utcnow)
    comment = Column(Text, nullable=True)
    history = Column(JSON, default=list)

class StepStats(Base):
    __tablename__ = "step_stats"
    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    date = Column(String, index=True) # Format YYYY-MM-DD
    steps = Column(Integer, default=0)
    goal = Column(Integer, default=10000)
    stride_meters = Column(String) # Store as string to preserve precision or simple float
    height_cm = Column(Integer, nullable=True)
    is_custom_stride = Column(Integer, default=0) # 0 or 1 boolean
