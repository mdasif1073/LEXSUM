from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.pool import QueuePool

from .config import settings


class Base(DeclarativeBase):
    pass


# Build connection string
db_url = settings.DATABASE_URL

if db_url.startswith("sqlite"):
    # Use pure SQLite
    engine = create_engine(
        db_url,
        connect_args={"check_same_thread": False},
    )
elif db_url.startswith("postgresql"):
    # PostgreSQL - use psycopg driver with proper SSL settings for Supabase
    connect_args = {
        "sslmode": "require",
        "connect_timeout": 10,  # 10 second timeout for connection
    }
    
    engine = create_engine(
        db_url,
        poolclass=QueuePool,
        pool_size=5,
        max_overflow=10,
        pool_pre_ping=True,
        pool_recycle=3600,  # Recycle connections every hour
        pool_timeout=10,  # Wait up to 10 seconds for a pool connection
        connect_args=connect_args,
        echo=False,
    )
else:
    # Other databases
    engine = create_engine(
        db_url,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
