from __future__ import annotations

import mimetypes
import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import get_current_user
from ..models import User, Subject, Enrollment, Lecture, LecturePhoto
from ..schemas import LecturePhotoOut
from ..storage_supabase import SupabaseStorage

router = APIRouter(tags=["photos"])
ALLOWED_IMAGE_EXTS = {"jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif"}


def _get_subject(db: Session, subject_id: str) -> Subject:
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    return subject


def _get_lecture(db: Session, lecture_id: str) -> Lecture:
    lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
    if not lec:
        raise HTTPException(status_code=404, detail="Lecture not found")
    return lec


def _enrollment(db: Session, subject_id: str, user_id: str) -> Enrollment | None:
    return db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject_id,
            Enrollment.user_id == user_id,
        )
    ).scalar_one_or_none()


def _can_view_subject(db: Session, subject: Subject, user: User) -> bool:
    if user.role == "teacher" and subject.teacher_id == user.id:
        return True
    return _enrollment(db, subject.id, user.id) is not None


def _can_upload_photos(db: Session, subject: Subject, user: User) -> bool:
    # teacher owner
    if user.role == "teacher" and subject.teacher_id == user.id:
        return True

    # class rep
    enr = _enrollment(db, subject.id, user.id)
    return bool(enr and enr.role_in_subject == "rep")


@router.post("/lectures/{lecture_id}/photos", response_model=list[LecturePhotoOut])
async def upload_lecture_photos(
    lecture_id: str,
    files: list[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lec = _get_lecture(db, lecture_id)
    subject = _get_subject(db, lec.subject_id)

    if not _can_upload_photos(db, subject, current_user):
        raise HTTPException(status_code=403, detail="Only teacher or class rep can upload photos")

    if not files:
        raise HTTPException(status_code=400, detail="No files uploaded")

    storage = SupabaseStorage()
    out: list[LecturePhotoOut] = []

    for f in files:
        if not f.filename:
            continue

        ext = (f.filename.split(".")[-1] or "").lower()
        ct = (f.content_type or "").split(";")[0].strip().lower()

        # Accept normal image mime types and also application/octet-stream
        # when the filename extension is a known image extension.
        is_image_ct = ct.startswith("image/")
        is_image_ext = ext in ALLOWED_IMAGE_EXTS
        if not (is_image_ct or is_image_ext):
            raise HTTPException(status_code=400, detail=f"Only images allowed. Got: {f.content_type}")

        resolved_ct = ct if is_image_ct else (mimetypes.guess_type(f.filename)[0] or "image/jpeg")

        data = await f.read()
        if not data:
            continue

        # object path layout:
        # {subject_id}/{lecture_id}/{uuid}.{ext}
        ext = ext or "jpg"
        photo_id = str(uuid.uuid4())
        object_path = f"{lec.subject_id}/{lec.id}/{photo_id}.{ext}"

        await storage.upload_bytes(
            bucket="lecture-images",
            object_path=object_path,
            data=data,
            content_type=resolved_ct,
            upsert=True,
        )

        row = LecturePhoto(
            lecture_id=lec.id,
            uploaded_by_user_id=current_user.id,
            object_path=object_path,
        )
        db.add(row)
        db.commit()
        db.refresh(row)

        signed_url = await storage.create_signed_url(
            bucket="lecture-images",
            object_path=object_path,
            expires_in=600,  # 10 minutes
        )

        out.append(
            LecturePhotoOut(
                id=row.id,
                lecture_id=row.lecture_id,
                object_path=row.object_path,
                signed_url=signed_url,
                uploaded_by_name=current_user.name,
                created_at=row.created_at,
            )
        )

    if not out:
        raise HTTPException(status_code=400, detail="No valid image files uploaded")

    return out


@router.get("/lectures/{lecture_id}/photos", response_model=list[LecturePhotoOut])
async def list_lecture_photos(
    lecture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lec = _get_lecture(db, lecture_id)
    subject = _get_subject(db, lec.subject_id)

    if not _can_view_subject(db, subject, current_user):
        raise HTTPException(status_code=403, detail="Not allowed")

    storage = SupabaseStorage()

    photos = db.execute(
        select(LecturePhoto, User)
        .join(User, User.id == LecturePhoto.uploaded_by_user_id, isouter=True)
        .where(LecturePhoto.lecture_id == lecture_id)
        .order_by(LecturePhoto.created_at.desc())
    ).all()

    out: list[LecturePhotoOut] = []
    for p, u in photos:
        signed_url = await storage.create_signed_url(
            bucket="lecture-images",
            object_path=p.object_path,
            expires_in=600,
        )
        out.append(
            LecturePhotoOut(
                id=p.id,
                lecture_id=p.lecture_id,
                object_path=p.object_path,
                signed_url=signed_url,
                uploaded_by_name=u.name if u else None,
                created_at=p.created_at,
            )
        )

    return out
