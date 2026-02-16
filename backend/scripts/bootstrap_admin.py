"""Create or update the initial admin account (root/root).

Usage (from project root):
    python backend/scripts/bootstrap_admin.py
"""

from pathlib import Path
import sys

# Make imports work when running this file directly.
PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend.app import auth, models
from backend.app.database import Base, SessionLocal, engine


def bootstrap_admin(login: str = "root", password: str = "root") -> None:
    # Ensure DB schema exists before querying users table.
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        user = db.query(models.User).filter(models.User.login == login).first()
        if user is None:
            user = models.User(
                login=login,
                password_hash=auth.get_password_hash(password),
                role=models.UserRole.admin,
                full_name="Администратор",
            )
            db.add(user)
            db.commit()
            print(f"Admin created: {login}/{password}")
        else:
            user.password_hash = auth.get_password_hash(password)
            user.role = models.UserRole.admin
            if not user.full_name:
                user.full_name = "Администратор"
            db.commit()
            print(f"Admin updated: {login}/{password}")
    finally:
        db.close()


if __name__ == "__main__":
    bootstrap_admin()
