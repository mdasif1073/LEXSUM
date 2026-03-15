from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, or_
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import get_current_user
from ..models import User, Subject, Enrollment, Lecture
from ..schemas import SearchOut, SearchOutItem

router = APIRouter(prefix="/search", tags=["search"])


def _can_view_subject(db: Session, subject: Subject, user: User) -> bool:
    if user.role == "teacher" and subject.teacher_id == user.id:
        return True

    enrolled = db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject.id,
            Enrollment.user_id == user.id,
        )
    ).scalar_one_or_none()
    return enrolled is not None


def _make_snippet(text: str, q: str, limit: int = 180) -> str:
    t = text.strip().replace("\n", " ")
    idx = t.lower().find(q.lower())
    if idx == -1:
        return (t[:limit] + "…") if len(t) > limit else t

    start = max(0, idx - 60)
    end = min(len(t), idx + 60)
    snippet = t[start:end].strip()
    if start > 0:
        snippet = "… " + snippet
    if end < len(t):
        snippet = snippet + " …"
    return snippet[:limit] + ("…" if len(snippet) > limit else "")


@router.get("/subjects/{subject_id}", response_model=SearchOut)
def search_subject(
    subject_id: str,
    q: str = Query(..., min_length=2, max_length=120),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    if not _can_view_subject(db, subject, current_user):
        raise HTTPException(status_code=403, detail="Not allowed")

    query = q.strip()
    like = f"%{query}%"

    # Simple SQL LIKE search in notes/summary/transcript
    lectures = db.execute(
        select(Lecture)
        .where(
            Lecture.subject_id == subject_id,
            or_(
                Lecture.notes_md.ilike(like),
                Lecture.summary_md.ilike(like),
                Lecture.transcript_text.ilike(like),
            ),
        )
        .order_by(Lecture.lecture_at.desc())
        .limit(25)
    ).scalars().all()

    results: list[SearchOutItem] = []
    for lec in lectures:
        # pick best text field for snippet
        source_text = lec.notes_md or lec.summary_md or lec.transcript_text or ""
        snippet = _make_snippet(source_text, query)
        results.append(
            SearchOutItem(
                lecture_id=lec.id,
                lecture_at=lec.lecture_at,
                status=lec.status,
                snippet=snippet,
            )
        )

    return SearchOut(subject_id=subject_id, query=query, results=results)
