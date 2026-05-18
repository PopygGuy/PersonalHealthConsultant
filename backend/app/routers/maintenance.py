from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from .. import models, auth

try:
    from scripts.dedupe_faculties import dedupe as dedupe_faculties
    from scripts.seed_initial_catalog import seed_catalog
except ModuleNotFoundError:
    from backend.scripts.dedupe_faculties import dedupe as dedupe_faculties
    from backend.scripts.seed_initial_catalog import seed_catalog


router = APIRouter(prefix="/admin/maintenance")


@router.post("/repair-catalog")
def repair_catalog(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user),
):
    if current_user.role != models.UserRole.admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Ensure DB session can be safely closed before running script-level sessions.
    db.close()

    seed_result = seed_catalog()
    dedupe_result = dedupe_faculties()

    return {
        "ok": True,
        "message": "Справочники факультетов и групп восстановлены",
        "seed": seed_result,
        "dedupe": dedupe_result,
    }
