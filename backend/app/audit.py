import logging
from typing import Tuple

from fastapi import Request
from jose import JWTError, jwt

from .config import settings

audit_logger = logging.getLogger("phc.audit")


def resolve_actor_from_request(request: Request) -> Tuple[str, str]:
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return "anonymous", "-"

    token = header[len("Bearer ") :].strip()
    if not token:
        return "anonymous", "-"

    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        login = str(payload.get("sub") or "anonymous")
        role = str(payload.get("role") or "-")
        return login, role
    except JWTError:
        return "anonymous", "-"


def _serialize_details(details: dict) -> str:
    items = []
    for key, value in details.items():
        if value is None:
            continue
        normalized = str(value).replace("\n", " ").strip()
        items.append(f"{key}={normalized}")
    return " ".join(items)


def log_event(event: str, **details) -> None:
    suffix = _serialize_details(details)
    if suffix:
        audit_logger.info("AUDIT event=%s %s", event, suffix)
    else:
        audit_logger.info("AUDIT event=%s", event)

