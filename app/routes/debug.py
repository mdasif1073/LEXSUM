from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Lecture
from ..queue import get_queue
from ..storage_supabase import SupabaseStorage

router = APIRouter(tags=["debug"])


@router.get("/debug/lectures/{lecture_id}/audio-exists")
async def debug_lecture_audio_exists(
    lecture_id: str,
    db: Session = Depends(get_db),
):
    """
    Dev-only helper to check whether a lecture's audio object exists in Supabase Storage.
    This avoids needing to expose secrets locally while debugging worker download issues.
    """
    if settings.APP_ENV != "dev":
        raise HTTPException(status_code=404, detail="Not found")

    lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
    if not lec:
        raise HTTPException(status_code=404, detail="Lecture not found")

    if not lec.audio_object_path:
        return {"ok": True, "exists": False, "reason": "no audio_object_path"}

    storage = SupabaseStorage()
    url = f"{storage.base_url}/storage/v1/object/lecture-audio/{lec.audio_object_path}"
    headers = storage._headers()

    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.head(url, headers=headers)
        if r.status_code == 405:
            # Some setups may not allow HEAD; use a minimal range GET.
            headers2 = dict(headers)
            headers2["Range"] = "bytes=0-0"
            r = await client.get(url, headers=headers2)

    exists = r.status_code in (200, 206)
    out = {
        "ok": True,
        "exists": exists,
        "status_code": r.status_code,
        "bucket": "lecture-audio",
        "object_path": lec.audio_object_path,
    }
    if not exists:
        out["error"] = r.text[:500]
    return out


@router.post("/debug/lectures/{lecture_id}/requeue")
async def debug_requeue_lecture_processing(
    lecture_id: str,
    db: Session = Depends(get_db),
):
    """
    Dev-only helper to re-enqueue a lecture processing job without re-uploading audio.
    Useful after changing worker code or fixing Modal/Redis issues.
    """
    if settings.APP_ENV != "dev":
        raise HTTPException(status_code=404, detail="Not found")

    lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
    if not lec:
        raise HTTPException(status_code=404, detail="Lecture not found")
    if not lec.audio_object_path:
        raise HTTPException(status_code=400, detail="No audio uploaded for this lecture")

    # Reset state so the UI reflects it can be processed again.
    lec.status = "uploaded"
    db.add(lec)
    db.commit()

    q = get_queue("default")
    job = q.enqueue("app.tasks.process_lecture.process_lecture_job", lec.id)
    return {"ok": True, "lecture_id": lec.id, "job_id": job.id}
