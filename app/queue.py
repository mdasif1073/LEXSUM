from __future__ import annotations

from redis import Redis
from rq import Queue

from .config import settings


def get_redis() -> Redis:
    # REDIS_URL like: redis://localhost:6379/0
    return Redis.from_url(settings.REDIS_URL)


def get_queue(name: str = "default") -> Queue:
    return Queue(name, connection=get_redis(), default_timeout=60 * 60)  # 1 hour jobs
