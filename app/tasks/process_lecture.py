from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import SessionLocal
from ..models import Lecture, Quiz
from ..storage_supabase import SupabaseStorage
from ..pipeline.asr_whisper import transcribe_audio_bytes
from ..pipeline.summarizer import summarize_lecture
from ..pipeline.quiz_gen import generate_quiz_json


def process_lecture_job(lecture_id: str) -> dict:
    """
    RQ job entrypoint (sync function).
    """
    db: Session = SessionLocal()
    try:
        print(f"[worker] start lecture_id={lecture_id}")
        lecture = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
        if not lecture:
            print(f"[worker] lecture not found: {lecture_id}")
            return {"ok": False, "error": "Lecture not found"}

        if not lecture.audio_object_path:
            print(f"[worker] no audio_object_path for lecture_id={lecture_id}")
            lecture.status = "failed"
            db.add(lecture)
            db.commit()
            return {"ok": False, "error": "No audio uploaded"}

        # set processing
        lecture.status = "processing"
        db.add(lecture)
        db.commit()

        storage = SupabaseStorage()
        if settings.SUPABASE_URL:
            print(f"[worker] supabase_url={settings.SUPABASE_URL}")
        print(f"[worker] downloading audio: {lecture.audio_object_path}")

        # download audio bytes
        audio = _run_async(storage.download_bytes(bucket="lecture-audio", object_path=lecture.audio_object_path))
        print(f"[worker] audio bytes={len(audio)} head={audio[:16].hex()}")

        # ASR
        print(f"[worker] transcribing with {settings.WHISPER_MODEL}")
        transcript = transcribe_audio_bytes(
            audio,
            settings.WHISPER_MODEL,
            input_name=lecture.audio_object_path or "input.m4a",
        )

        # Summarize
        print(f"[worker] summarizing with {settings.LLM_MODEL}")
        summ = summarize_lecture(transcript, settings.LLM_MODEL)

        # Save results first: make lecture usable even if quiz generation fails
        lecture.transcript_text = transcript
        lecture.notes_md = summ.notes_md
        lecture.summary_md = summ.summary_md
        lecture.status = "ready"
        db.add(lecture)
        db.commit()

        # Quiz from notes (best-effort)
        try:
            print("[worker] generating quiz")
            quiz_json = generate_quiz_json(summ.notes_md, lecture.id, settings.LLM_MODEL, n_mcq=5)
            quiz = Quiz(lecture_id=lecture.id, quiz_json=quiz_json)
            db.add(quiz)
            db.commit()
        except Exception as e:
            import traceback

            print(f"[worker] quiz generation failed lecture_id={lecture.id}: {e}")
            print(traceback.format_exc())

        print(f"[worker] done lecture_id={lecture.id}")
        return {"ok": True, "lecture_id": lecture.id}

    except Exception as e:
        import traceback
        print(f"[worker] ERROR lecture_id={lecture_id}: {e}")
        print(traceback.format_exc())
        try:
            lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
            if lec:
                lec.status = "failed"
                db.add(lec)
                db.commit()
        except Exception:
            pass
        raise
    finally:
        db.close()


# -------- helper to call async methods from sync RQ job --------
def _run_async(coro):
    import asyncio

    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = None

    if loop and loop.is_running():
        # running inside existing loop -> create a new one in thread-safe way
        return asyncio.run(coro)
    return asyncio.run(coro)
