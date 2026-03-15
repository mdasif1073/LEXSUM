from __future__ import annotations

from datetime import datetime, timezone
from ..queue import get_queue

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import get_current_user
from ..models import User, Subject, Enrollment, Lecture
from ..schemas import LectureCreateIn, LectureOut, LectureDetailOut
from ..storage_supabase import SupabaseStorage

router = APIRouter(tags=["lectures"])


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _is_teacher_of_subject(subject: Subject, user: User) -> bool:
    return user.role == "teacher" and subject.teacher_id == user.id


def _is_enrolled(db: Session, subject_id: str, user_id: str) -> Enrollment | None:
    return db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject_id,
            Enrollment.user_id == user_id,
        )
    ).scalar_one_or_none()


def _require_subject_access(db: Session, subject_id: str, user: User) -> Subject:
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    if _is_teacher_of_subject(subject, user):
        return subject

    # student must be enrolled
    enrolled = _is_enrolled(db, subject_id, user.id)
    if not enrolled:
        raise HTTPException(status_code=403, detail="Not enrolled in this subject")

    return subject


@router.post("/subjects/{subject_id}/lectures", response_model=LectureOut)
def create_lecture(
    subject_id: str,
    payload: LectureCreateIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    # Teacher only can create/record lecture
    if not _is_teacher_of_subject(subject, current_user):
        raise HTTPException(status_code=403, detail="Teacher only")

    lecture_at = payload.lecture_at or _utc_now()

    lecture = Lecture(
        subject_id=subject_id,
        created_by_user_id=current_user.id,
        lecture_at=lecture_at,
        status="uploaded",  # will remain uploaded until worker processes
    )
    db.add(lecture)
    db.commit()
    db.refresh(lecture)

    return LectureOut(
        id=lecture.id,
        subject_id=lecture.subject_id,
        lecture_at=lecture.lecture_at,
        status=lecture.status,
        preview=None,
        created_at=lecture.created_at,
    )


@router.get("/subjects/{subject_id}/lectures", response_model=list[LectureOut])
def list_lectures(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # teacher OR enrolled student can view
    _require_subject_access(db, subject_id, current_user)

    q = (
        select(Lecture)
        .where(Lecture.subject_id == subject_id)
        .order_by(Lecture.lecture_at.desc())
    )

    lectures = db.execute(q).scalars().all()

    def _md_preview(md: str, limit: int = 180) -> str:
        """
        Pick the first "meaningful" line from markdown.
        Avoid showing headings like "## Summary" in the lecture list.
        """
        if not md:
            return ""
        for ln in md.splitlines():
            s = (ln or "").strip()
            if not s:
                continue
            if s.startswith("#") or s.startswith("```") or s == "---":
                continue
            s = s.lstrip("-•* ").strip()
            if s:
                return s[:limit]
        # Fallback: first non-empty line (even if heading)
        for ln in md.splitlines():
            s = (ln or "").strip()
            if s:
                return s[:limit]
        return ""

    out: list[LectureOut] = []
    for lec in lectures:
        preview = None
        if lec.summary_md:
            preview = _md_preview(lec.summary_md, limit=180) or None
        elif lec.notes_md:
            preview = _md_preview(lec.notes_md, limit=180) or None

        out.append(
            LectureOut(
                id=lec.id,
                subject_id=lec.subject_id,
                lecture_at=lec.lecture_at,
                status=lec.status,
                preview=preview,
                created_at=lec.created_at,
            )
        )
    return out


@router.get("/lectures/{lecture_id}", response_model=LectureDetailOut)
def lecture_detail(
    lecture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
    if not lec:
        raise HTTPException(status_code=404, detail="Lecture not found")

    # Access check: teacher owner OR enrolled student
    _require_subject_access(db, lec.subject_id, current_user)

    return LectureDetailOut(
        id=lec.id,
        subject_id=lec.subject_id,
        lecture_at=lec.lecture_at,
        status=lec.status,
        transcript_text=lec.transcript_text,
        notes_md=lec.notes_md,
        summary_md=lec.summary_md,
        created_at=lec.created_at,
    )


@router.post("/lectures/{lecture_id}/audio")
async def upload_lecture_audio(
    lecture_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    
    lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
    if not lec:
        raise HTTPException(status_code=404, detail="Lecture not found")

    subject = db.execute(select(Subject).where(Subject.id == lec.subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    # Teacher only upload lecture audio
    if not _is_teacher_of_subject(subject, current_user):
        raise HTTPException(status_code=403, detail="Teacher only")

    # Basic file type checks (keep simple)
    if not file.filename:
        raise HTTPException(status_code=400, detail="Missing filename")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")

    # Store in Supabase Storage bucket: lecture-audio
    # Path layout: {subject_id}/{lecture_id}.ext
    ext = (file.filename.split(".")[-1] or "m4a").lower()
    object_path = f"{lec.subject_id}/{lec.id}.{ext}"

    storage = SupabaseStorage()
    await storage.upload_bytes(
        bucket="lecture-audio",
        object_path=object_path,
        data=content,
        content_type=file.content_type or "application/octet-stream",
        upsert=True,
    )

    # Save path + update status
    lec.audio_object_path = object_path
    # Immediately mark as processing once audio is uploaded and job is enqueued.
    # This avoids the UI sitting in "uploaded" while the job is waiting in Redis.
    lec.status = "processing"

    db.add(lec)
    db.commit()
    # enqueue processing job
    q = get_queue("default")
    q.enqueue("app.tasks.process_lecture.process_lecture_job", lec.id)

    return {"ok": True, "lecture_id": lec.id, "audio_object_path": object_path, "queued": True}
