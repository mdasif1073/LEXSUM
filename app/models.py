import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    String,
    DateTime,
    ForeignKey,
    Integer,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


# =========================
# Users
# =========================
class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))

    # "teacher" | "student"
    role: Mapped[str] = mapped_column(String(20), index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    # relationships
    subjects_owned: Mapped[list["Subject"]] = relationship(back_populates="teacher")
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="user")


# =========================
# Subjects (classes)
# =========================
class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    teacher_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )

    name: Mapped[str] = mapped_column(String(200))
    invite_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    # relationships
    teacher: Mapped["User"] = relationship(back_populates="subjects_owned")
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="subject")
    lectures: Mapped[list["Lecture"]] = relationship(back_populates="subject")


# =========================
# Enrollment (students joined into subject)
# + class rep role per subject
# =========================
class Enrollment(Base):
    __tablename__ = "enrollments"
    __table_args__ = (
        UniqueConstraint("subject_id", "user_id", name="uq_enrollment_subject_user"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    subject_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("subjects.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )

    # "student" | "rep"
    role_in_subject: Mapped[str] = mapped_column(String(20), default="student", index=True)

    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    # relationships
    subject: Mapped["Subject"] = relationship(back_populates="enrollments")
    user: Mapped["User"] = relationship(back_populates="enrollments")


# =========================
# Lectures (per subject)
# audio is stored in Supabase Storage, we store object path here
# =========================
class Lecture(Base):
    __tablename__ = "lectures"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    subject_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("subjects.id", ondelete="CASCADE"),
        index=True,
    )

    # Who created/recorded (teacher usually)
    created_by_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # lecture date+time (from UI)
    lecture_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)

    # Storage object paths (Supabase buckets)
    audio_object_path: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Processing status: uploaded | processing | ready | failed
    status: Mapped[str] = mapped_column(String(20), default="uploaded", index=True)

    # Text outputs
    transcript_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes_md: Mapped[str | None] = mapped_column(Text, nullable=True)     # structured notes
    summary_md: Mapped[str | None] = mapped_column(Text, nullable=True)   # short summary

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    # relationships
    subject: Mapped["Subject"] = relationship(back_populates="lectures")
    photos: Mapped[list["LecturePhoto"]] = relationship(back_populates="lecture")
    quizzes: Mapped[list["Quiz"]] = relationship(back_populates="lecture")


# =========================
# Lecture Photos (notes images)
# Stored in Supabase Storage
# Upload allowed: teacher OR rep
# =========================
class LecturePhoto(Base):
    __tablename__ = "lecture_photos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    lecture_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("lectures.id", ondelete="CASCADE"),
        index=True,
    )

    uploaded_by_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Supabase Storage object path (bucket: lecture-images)
    object_path: Mapped[str] = mapped_column(String(600))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    lecture: Mapped["Lecture"] = relationship(back_populates="photos")


# =========================
# Quizzes (generated per lecture)
# =========================
class Quiz(Base):
    __tablename__ = "quizzes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    lecture_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("lectures.id", ondelete="CASCADE"),
        index=True,
    )

    # quiz content stored as JSON string for now (simple)
    # later we can convert to JSONB
    quiz_json: Mapped[str] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    lecture: Mapped["Lecture"] = relationship(back_populates="quizzes")
    attempts: Mapped[list["QuizAttempt"]] = relationship(back_populates="quiz")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    quiz_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("quizzes.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )

    score: Mapped[int] = mapped_column(Integer, default=0)
    answers_json: Mapped[str] = mapped_column(Text)  # store user answers as JSON string

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    quiz: Mapped["Quiz"] = relationship(back_populates="attempts")
