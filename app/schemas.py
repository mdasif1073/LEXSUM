from datetime import datetime
from pydantic import BaseModel, Field, EmailStr
import json
from typing import Literal


# =========================
# Auth Schemas
# =========================
class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6)
    role: Literal["teacher", "student"] = "teacher"


class RegisterSimple(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6)


class LoginIn(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    id: str
    name: str
    email: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


# =========================
# Subject Schemas
# =========================
class SubjectCreateIn(BaseModel):
    name: str = Field(min_length=2, max_length=200)


class SubjectJoinIn(BaseModel):
    invite_code: str = Field(min_length=5, max_length=10)


class SubjectCardOut(BaseModel):
    id: str
    name: str
    invite_code: str | None = None  # None for students
    is_owner: bool  # True if teacher, False if student
    role_in_subject: str | None = None  # "student" | "rep" | None
    created_at: datetime

    class Config:
        from_attributes = True


class SubjectsListOut(BaseModel):
    subjects: list[SubjectCardOut]


# =========================
# Students
# =========================
class StudentOut(BaseModel):
    id: str
    name: str
    is_representative: bool = False

    class Config:
        from_attributes = True


# =========================
# Lecture Schemas
# =========================
class QuizOut(BaseModel):
    id: str
    lecture_id: str
    quiz_json: str  # stored JSON string (frontend can jsonDecode)
    created_at: datetime

    class Config:
        from_attributes = True


class QuizGenerateOut(BaseModel):
    ok: bool
    quiz_id: str


class QuizAttemptIn(BaseModel):
    # Example payload:
    # {
    #   "answers": {"q1":"C","q2":"A","q3":"free text here"}
    # }
    answers: dict[str, str] = Field(default_factory=dict)


class QuizAttemptOut(BaseModel):
    id: str
    quiz_id: str
    user_id: str
    score: int
    answers_json: str
    created_at: datetime

    class Config:
        from_attributes = True


class QuizTeacherStatsOut(BaseModel):
    lecture_id: str
    quiz_id: str | None = None
    total_students: int
    attempted_students: int
    not_attempted_students: int
    average_score: float | None = None
    latest_attempt_at: datetime | None = None


class SearchOutItem(BaseModel):
    lecture_id: str
    lecture_at: datetime
    status: str
    snippet: str

    class Config:
        from_attributes = True


class SearchOut(BaseModel):
    subject_id: str
    query: str
    results: list[SearchOutItem]


class SearchIn(BaseModel):
    query: str = Field(min_length=2, max_length=120)


class LecturePhotoOut(BaseModel):
    id: str
    lecture_id: str
    object_path: str
    signed_url: str
    uploaded_by_name: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class LectureCreateIn(BaseModel):
    # frontend sends date+time of class; if not provided, backend uses now()
    lecture_at: datetime | None = None


class LectureOut(BaseModel):
    id: str
    subject_id: str
    lecture_at: datetime
    status: str  # uploaded | processing | ready | failed
    preview: str | None = None  # short preview from summary/notes
    created_at: datetime

    class Config:
        from_attributes = True


class LectureDetailOut(BaseModel):
    id: str
    subject_id: str
    lecture_at: datetime
    status: str

    transcript_text: str | None = None
    notes_md: str | None = None
    summary_md: str | None = None

    created_at: datetime

    class Config:
        from_attributes = True
