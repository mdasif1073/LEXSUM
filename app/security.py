from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from jose import jwt
import bcrypt

from .config import settings

ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    # bcrypt has a 72-byte limit on passwords
    password_bytes = password[:72].encode('utf-8')
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password_bytes, salt).decode('utf-8')


def verify_password(password: str, password_hash: str) -> bool:
    # bcrypt has a 72-byte limit on passwords
    password_bytes = password[:72].encode('utf-8')
    return bcrypt.checkpw(password_bytes, password_hash.encode('utf-8'))


def create_access_token(
    subject: str,
    role: str,
    expires_minutes: Optional[int] = None,
    extra: Optional[dict[str, Any]] = None,
) -> str:
    exp_minutes = expires_minutes or settings.JWT_EXPIRES_MINUTES
    expire = datetime.now(timezone.utc) + timedelta(minutes=exp_minutes)

    payload: dict[str, Any] = {"sub": subject, "role": role, "exp": expire}
    if extra:
        payload.update(extra)

    return jwt.encode(payload, settings.JWT_SECRET, algorithm=ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[ALGORITHM])
