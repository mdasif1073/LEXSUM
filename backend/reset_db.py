#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.db import Base, engine
from app.config import settings


def _mask_db_url(url: str) -> str:
    if "@" not in url:
        return url
    return url.split("@", 1)[-1]


def main() -> None:
    print(f"Resetting database at: {_mask_db_url(settings.DATABASE_URL)}")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    print("Done. All tables dropped and re-created.")


if __name__ == "__main__":
    main()
