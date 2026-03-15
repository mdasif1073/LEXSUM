from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, distinct
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import get_current_user
from ..models import User, Subject, Enrollment, Lecture, Quiz, QuizAttempt
from ..schemas import (
    QuizOut,
    QuizGenerateOut,
    QuizAttemptIn,
    QuizAttemptOut,
    QuizTeacherStatsOut,
)

router = APIRouter(tags=["quizzes"])


def _get_lecture(db: Session, lecture_id: str) -> Lecture:
    lec = db.execute(select(Lecture).where(Lecture.id == lecture_id)).scalar_one_or_none()
    if not lec:
        raise HTTPException(status_code=404, detail="Lecture not found")
    return lec


def _get_subject(db: Session, subject_id: str) -> Subject:
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    return subject


def _enrollment(db: Session, subject_id: str, user_id: str) -> Enrollment | None:
    return db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject_id,
            Enrollment.user_id == user_id,
        )
    ).scalar_one_or_none()


def _require_teacher_owner(subject: Subject, user: User) -> None:
    if not (user.role == "teacher" and subject.teacher_id == user.id):
        raise HTTPException(status_code=403, detail="Teacher only")


def _require_student_enrolled(db: Session, subject: Subject, user: User) -> Enrollment:
    if user.role == "teacher" and subject.teacher_id == user.id:
        raise HTTPException(status_code=403, detail="Teachers cannot attempt quizzes")
    enr = _enrollment(db, subject.id, user.id)
    if not enr:
        raise HTTPException(status_code=403, detail="Not enrolled")
    return enr


def _build_simple_quiz_from_text(lecture: Lecture, n: int = 5) -> dict:
    """
    Temporary quiz generator (no AI yet).
    Uses lecture summary/notes and creates simple MCQs.

    Later we will replace this with the LLM-based generator in the worker.
    """
    base_text = (lecture.summary_md or lecture.notes_md or "").strip()
    if len(base_text) < 40:
        raise HTTPException(status_code=400, detail="Lecture has no summary/notes to generate quiz")

    # pick 5 key lines as “concepts”
    lines = [ln.strip("-• ").strip() for ln in base_text.splitlines() if ln.strip()]
    concepts = []
    for ln in lines:
        if 12 <= len(ln) <= 120:
            concepts.append(ln)
        if len(concepts) >= n:
            break
    if not concepts:
        # fallback: slice text
        concepts = [base_text[:120]]

    questions = []
    for i, concept in enumerate(concepts, start=1):
        qid = f"q{i}"
        # Simple MCQ template. Correct is always option C (placeholder),
        # but the question still helps for UI + flow.
        questions.append(
            {
                "id": qid,
                "type": "mcq",
                "prompt": f"Which statement best matches this lecture point?\n\n{concept}",
                "options": [
                    "Unrelated option (placeholder)",
                    "Opposite meaning (placeholder)",
                    concept,
                    "Different topic (placeholder)",
                ],
                "answer_index": 2,  # option C is correct
                "explanation": "Based on the lecture notes/summary.",
            }
        )

    return {
        "version": 1,
        "lecture_id": lecture.id,
        "generated_by": "backend-simple",
        "questions": questions,
    }


def _score_attempt(quiz_obj: dict, answers: dict[str, str]) -> int:
    """
    Scoring:
    - For mcq: accept either option index ("2") or option letter ("C") or exact option text
    - Score: 20 points per correct mcq (so 5 questions => 100)
    """
    questions = quiz_obj.get("questions", [])
    if not questions:
        return 0

    per_q = max(1, 100 // len(questions))
    score = 0

    for q in questions:
        qid = q.get("id")
        if not qid:
            continue
        correct_index = q.get("answer_index")
        if correct_index is None:
            continue

        user_ans = (answers.get(qid) or "").strip()
        if not user_ans:
            continue

        # Normalize: allow "A/B/C/D"
        letters = {"A": 0, "B": 1, "C": 2, "D": 3}
        if user_ans.upper() in letters:
            ua = letters[user_ans.upper()]
            if ua == correct_index:
                score += per_q
            continue

        # allow numeric string
        if user_ans.isdigit():
            if int(user_ans) == correct_index:
                score += per_q
            continue

        # allow exact option text
        opts = q.get("options") or []
        if 0 <= correct_index < len(opts):
            if user_ans == str(opts[correct_index]).strip():
                score += per_q

    return min(100, score)


@router.post("/lectures/{lecture_id}/quizzes/generate", response_model=QuizGenerateOut)
def generate_quiz_for_lecture(
    lecture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lec = _get_lecture(db, lecture_id)
    subject = _get_subject(db, lec.subject_id)
    _require_teacher_owner(subject, current_user)

    # If lecture not ready, you can still generate from notes/summary
    quiz_obj = _build_simple_quiz_from_text(lec, n=5)
    quiz_json = json.dumps(quiz_obj, ensure_ascii=False)

    quiz = Quiz(lecture_id=lec.id, quiz_json=quiz_json)
    db.add(quiz)
    db.commit()
    db.refresh(quiz)

    return QuizGenerateOut(ok=True, quiz_id=quiz.id)


@router.get("/lectures/{lecture_id}/quizzes/latest", response_model=QuizOut)
def get_latest_quiz(
    lecture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lec = _get_lecture(db, lecture_id)
    subject = _get_subject(db, lec.subject_id)
    _require_student_enrolled(db, subject, current_user)

    quiz = db.execute(
        select(Quiz).where(Quiz.lecture_id == lecture_id).order_by(Quiz.created_at.desc())
    ).scalar_one_or_none()

    if not quiz:
        raise HTTPException(status_code=404, detail="No quiz found")

    return quiz


@router.get("/lectures/{lecture_id}/quizzes/stats", response_model=QuizTeacherStatsOut)
def get_quiz_stats_for_teacher(
    lecture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lec = _get_lecture(db, lecture_id)
    subject = _get_subject(db, lec.subject_id)
    _require_teacher_owner(subject, current_user)

    total_students = (
        db.execute(
            select(func.count())
            .select_from(Enrollment)
            .where(Enrollment.subject_id == subject.id)
        ).scalar_one()
        or 0
    )

    quiz = db.execute(
        select(Quiz).where(Quiz.lecture_id == lecture_id).order_by(Quiz.created_at.desc())
    ).scalar_one_or_none()
    if not quiz:
        return QuizTeacherStatsOut(
            lecture_id=lecture_id,
            quiz_id=None,
            total_students=int(total_students),
            attempted_students=0,
            not_attempted_students=int(total_students),
            average_score=None,
            latest_attempt_at=None,
        )

    attempted_students = (
        db.execute(
            select(func.count(distinct(QuizAttempt.user_id))).where(QuizAttempt.quiz_id == quiz.id)
        ).scalar_one()
        or 0
    )
    avg_score = db.execute(
        select(func.avg(QuizAttempt.score)).where(QuizAttempt.quiz_id == quiz.id)
    ).scalar_one()
    latest_attempt_at = db.execute(
        select(func.max(QuizAttempt.created_at)).where(QuizAttempt.quiz_id == quiz.id)
    ).scalar_one()

    total_students_i = int(total_students)
    attempted_students_i = int(attempted_students)
    return QuizTeacherStatsOut(
        lecture_id=lecture_id,
        quiz_id=quiz.id,
        total_students=total_students_i,
        attempted_students=attempted_students_i,
        not_attempted_students=max(0, total_students_i - attempted_students_i),
        average_score=None if avg_score is None else float(avg_score),
        latest_attempt_at=latest_attempt_at,
    )


@router.post("/quizzes/{quiz_id}/attempt", response_model=QuizAttemptOut)
def submit_quiz_attempt(
    quiz_id: str,
    payload: QuizAttemptIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = db.execute(select(Quiz).where(Quiz.id == quiz_id)).scalar_one_or_none()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")

    lec = _get_lecture(db, quiz.lecture_id)
    subject = _get_subject(db, lec.subject_id)
    _require_student_enrolled(db, subject, current_user)

    # Parse stored quiz JSON
    try:
        quiz_obj = json.loads(quiz.quiz_json)
    except Exception:
        raise HTTPException(status_code=500, detail="Quiz JSON is corrupted")

    answers = payload.answers or {}
    score = _score_attempt(quiz_obj, answers)

    attempt = QuizAttempt(
        quiz_id=quiz.id,
        user_id=current_user.id,
        score=score,
        answers_json=json.dumps(answers, ensure_ascii=False),
    )
    db.add(attempt)
    db.commit()
    db.refresh(attempt)

    return attempt


@router.get("/quizzes/{quiz_id}/attempts/me", response_model=list[QuizAttemptOut])
def my_attempts(
    quiz_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = db.execute(select(Quiz).where(Quiz.id == quiz_id)).scalar_one_or_none()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")

    lec = _get_lecture(db, quiz.lecture_id)
    subject = _get_subject(db, lec.subject_id)
    _require_student_enrolled(db, subject, current_user)

    attempts = db.execute(
        select(QuizAttempt)
        .where(QuizAttempt.quiz_id == quiz_id, QuizAttempt.user_id == current_user.id)
        .order_by(QuizAttempt.created_at.desc())
    ).scalars().all()

    return attempts
