import random
import string
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import get_current_user
from ..models import User, Subject, Enrollment
from ..schemas import SubjectCreateIn, SubjectJoinIn, SubjectCardOut, StudentOut

router = APIRouter(prefix="/subjects", tags=["subjects"])


def _make_invite_code(prefix: str = "CL", length: int = 4) -> str:
    # Example: OS-9214 style (prefix + "-" + 4 digits)
    digits = "".join(random.choices(string.digits, k=length))
    return f"{prefix}-{digits}"


def _require_teacher(user: User) -> None:
    if user.role != "teacher":
        raise HTTPException(status_code=403, detail="Teacher only")


@router.post("", response_model=SubjectCardOut)
def create_subject(
    payload: SubjectCreateIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_teacher(current_user)

    # generate a unique invite code
    invite_code = _make_invite_code("CL", 4)
    for _ in range(10):
        exists = db.execute(select(Subject).where(Subject.invite_code == invite_code)).scalar_one_or_none()
        if not exists:
            break
        invite_code = _make_invite_code("CL", 4)
    else:
        raise HTTPException(status_code=500, detail="Failed to generate invite code")

    subject = Subject(
        teacher_id=current_user.id,
        name=payload.name.strip(),
        invite_code=invite_code,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)

    # Teacher owns the subject -> show invite code
    return SubjectCardOut(
        id=subject.id,
        name=subject.name,
        invite_code=subject.invite_code,
        is_owner=True,
        role_in_subject=None,
        created_at=subject.created_at,
    )


@router.post("/join", response_model=SubjectCardOut)
def join_subject(
    payload: SubjectJoinIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    code = payload.invite_code.strip().upper()
    subject = db.execute(select(Subject).where(Subject.invite_code == code)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Invalid invite code")

    # If teacher tries to join: allow but no need (they already own)
    if current_user.role == "teacher" and subject.teacher_id == current_user.id:
        return SubjectCardOut(
            id=subject.id,
            name=subject.name,
            invite_code=subject.invite_code,
            is_owner=True,
            role_in_subject=None,
            created_at=subject.created_at,
        )

    # check already enrolled
    existing = db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject.id,
            Enrollment.user_id == current_user.id,
        )
    ).scalar_one_or_none()

    if not existing:
        enrollment = Enrollment(subject_id=subject.id, user_id=current_user.id, role_in_subject="student")
        db.add(enrollment)
        db.commit()
        db.refresh(enrollment)
        role_in_subject = enrollment.role_in_subject
    else:
        role_in_subject = existing.role_in_subject

    return SubjectCardOut(
        id=subject.id,
        name=subject.name,
        invite_code=None,  # students don’t need invite code
        is_owner=False,
        role_in_subject=role_in_subject,
        created_at=subject.created_at,
    )


@router.get("", response_model=list[SubjectCardOut])
def list_subjects(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    results: list[SubjectCardOut] = []

    # 1) Teacher-owned subjects
    owned = db.execute(select(Subject).where(Subject.teacher_id == current_user.id).order_by(Subject.created_at.desc()))
    for s in owned.scalars().all():
        results.append(
            SubjectCardOut(
                id=s.id,
                name=s.name,
                invite_code=s.invite_code,  # teacher sees
                is_owner=True,
                role_in_subject=None,
                created_at=s.created_at,
            )
        )

    # 2) Joined subjects (students / reps)
    enrolled = db.execute(
        select(Subject, Enrollment)
        .join(Enrollment, Enrollment.subject_id == Subject.id)
        .where(Enrollment.user_id == current_user.id)
        .order_by(Enrollment.joined_at.desc())
    )
    for s, e in enrolled.all():
        results.append(
            SubjectCardOut(
                id=s.id,
                name=s.name,
                invite_code=None,  # not shown to students
                is_owner=False,
                role_in_subject=e.role_in_subject,
                created_at=s.created_at,
            )
        )

    return results


@router.get("/my", response_model=list[SubjectCardOut])
def my_subjects(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    results: list[SubjectCardOut] = []

    # 1) Teacher-owned subjects
    owned = db.execute(select(Subject).where(Subject.teacher_id == current_user.id).order_by(Subject.created_at.desc()))
    for s in owned.scalars().all():
        results.append(
            SubjectCardOut(
                id=s.id,
                name=s.name,
                invite_code=s.invite_code,  # teacher sees
                is_owner=True,
                role_in_subject=None,
                created_at=s.created_at,
            )
        )

    # 2) Joined subjects (students / reps)
    enrolled = db.execute(
        select(Subject, Enrollment)
        .join(Enrollment, Enrollment.subject_id == Subject.id)
        .where(Enrollment.user_id == current_user.id)
        .order_by(Enrollment.joined_at.desc())
    )
    for s, e in enrolled.all():
        results.append(
            SubjectCardOut(
                id=s.id,
                name=s.name,
                invite_code=None,  # not shown to students
                is_owner=False,
                role_in_subject=e.role_in_subject,
                created_at=s.created_at,
            )
        )

    return results


@router.get("/{subject_id}", response_model=SubjectCardOut)
def get_subject(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    # Teacher owner
    if current_user.role == "teacher" and subject.teacher_id == current_user.id:
        return SubjectCardOut(
            id=subject.id,
            name=subject.name,
            invite_code=subject.invite_code,
            is_owner=True,
            role_in_subject=None,
            created_at=subject.created_at,
        )

    # Student must be enrolled
    enrollment = db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject_id,
            Enrollment.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if not enrollment:
        raise HTTPException(status_code=403, detail="Not enrolled in this subject")

    return SubjectCardOut(
        id=subject.id,
        name=subject.name,
        invite_code=None,
        is_owner=False,
        role_in_subject=enrollment.role_in_subject,
        created_at=subject.created_at,
    )


@router.get("/{subject_id}/students", response_model=list[StudentOut])
def list_subject_students(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    # Access: teacher owner or enrolled student
    if not (current_user.role == "teacher" and subject.teacher_id == current_user.id):
        enrolled = db.execute(
            select(Enrollment).where(
                Enrollment.subject_id == subject_id,
                Enrollment.user_id == current_user.id,
            )
        ).scalar_one_or_none()
        if not enrolled:
            raise HTTPException(status_code=403, detail="Not allowed")

    rows = (
        db.execute(
            select(User, Enrollment)
            .join(Enrollment, Enrollment.user_id == User.id)
            .where(Enrollment.subject_id == subject_id)
            .order_by(User.name.asc())
        )
        .all()
    )

    return [
        StudentOut(
            id=u.id,
            name=u.name,
            is_representative=(e.role_in_subject == "rep"),
        )
        for (u, e) in rows
    ]


@router.post("/{subject_id}/reps/{student_user_id}")
def make_class_rep(
    subject_id: str,
    student_user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_teacher(current_user)

    subject = db.execute(select(Subject).where(Subject.id == subject_id)).scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    if subject.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your subject")

    enrollment = db.execute(
        select(Enrollment).where(
            Enrollment.subject_id == subject_id,
            Enrollment.user_id == student_user_id,
        )
    ).scalar_one_or_none()

    if not enrollment:
        raise HTTPException(status_code=404, detail="Student not enrolled")

    # Toggle rep status
    if enrollment.role_in_subject == "rep":
        enrollment.role_in_subject = "student"
    else:
        enrollment.role_in_subject = "rep"
    db.add(enrollment)
    db.commit()

    return {
        "ok": True,
        "subject_id": subject_id,
        "rep_user_id": student_user_id,
        "role_in_subject": enrollment.role_in_subject,
    }
