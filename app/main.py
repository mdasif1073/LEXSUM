from fastapi import FastAPI
from fastapi.routing import APIRoute
import logging
from fastapi.middleware.cors import CORSMiddleware
from .routes.subjects import router as subjects_router
from .routes.lectures import router as lectures_router
from .routes.photos import router as photos_router
from .routes.search import router as search_router
from .routes.quizzes import router as quizzes_router
from .routes.debug import router as debug_router
from .config import settings
from .db import Base, engine
from .routes.auth import router as auth_router

app = FastAPI(title="Classroom Backend", version="0.1.0")

# Create tables in dev if they don't exist (helps first-time setup)
@app.on_event("startup")
def _startup() -> None:
    if settings.APP_ENV == "dev":
        Base.metadata.create_all(bind=engine)
    # Log whether critical routes are registered (helps debug 404s)
    try:
        paths = {r.path for r in app.routes if isinstance(r, APIRoute)}
        logging.info(
            "Routes check: lectures=%s students=%s",
            "/subjects/{subject_id}/lectures" in paths,
            "/subjects/{subject_id}/students" in paths,
        )
    except Exception:
        pass

# CORS: for Flutter dev/testing (tighten later)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.APP_ENV == "dev" else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(subjects_router)
app.include_router(lectures_router)
app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(photos_router)
app.include_router(quizzes_router)
app.include_router(search_router)
app.include_router(debug_router)


@app.get("/health")
def health():
    return {"ok": True, "env": settings.APP_ENV}
