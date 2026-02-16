import os
from sqlalchemy.orm import Session
from app.database import engine, SessionLocal, Base
from app.models import User, UserRole, Faculty, Group
from app.auth import get_password_hash

def init_db():
    print("Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("Tables created.")

    db = SessionLocal()
    try:
        # 1. Create ADMIN
        admin = db.query(User).filter(User.login == "admin").first()
        if not admin:
            admin_user = User(
                login="admin",
                password_hash=get_password_hash("admin"),
                role=UserRole.admin,
                full_name="System Administrator"
            )
            db.add(admin_user)
            print("Admin user created (login: admin, pass: admin)")
        else:
            print("Admin user already exists.")

        # 2. Create TEACHER
        teacher = db.query(User).filter(User.login == "teacher").first()
        if not teacher:
            teacher_user = User(
                login="teacher",
                password_hash=get_password_hash("123"),
                role=UserRole.teacher,
                full_name="Ivan Petrovich (Teacher)"
            )
            db.add(teacher_user)
            print("Teacher user created (login: teacher, pass: 123)")

        # 3. Create FACULTY & GROUP for Student
        faculty = db.query(Faculty).filter(Faculty.name == "CS Faculty").first()
        if not faculty:
            faculty = Faculty(name="CS Faculty")
            db.add(faculty)
            db.commit() # Commit to get ID
            db.refresh(faculty)

        group = db.query(Group).filter(Group.name == "Group A").first()
        if not group:
            group = Group(name="Group A", faculty_id=faculty.id)
            db.add(group)
            db.commit()
            db.refresh(group)

        # 4. Create STUDENT
        student = db.query(User).filter(User.login == "student").first()
        if not student:
            student_user = User(
                login="student",
                password_hash=get_password_hash("123"),
                role=UserRole.student,
                full_name="Alexey Smirnov (Student)",
                faculty_id=faculty.id,
                group_id=group.id
            )
            db.add(student_user)
            print("Student user created (login: student, pass: 123)")

        db.commit()
        print("Database seeded successfully!")
    
    except Exception as e:
        print(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_db()
