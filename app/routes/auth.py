from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import select

from ..db import get_db
from ..models import User
from ..schemas import RegisterIn, UserOut, TokenOut, LoginIn, RegisterSimple
from ..security import hash_password, verify_password, create_access_token
from ..deps import get_current_user

router = APIRouter()


@router.post("/register", response_model=UserOut)
def register(payload: RegisterIn, db: Session = Depends(get_db)):
    existing = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        name=payload.name.strip(),
        email=payload.email.lower().strip(),
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _find_user_by_identifier(db: Session, identifier: str) -> User | None:
    ident = identifier.strip()
    if not ident:
        return None

    # 1) Try email match (case-insensitive)
    email = ident.lower()
    user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    if user:
        return user

    # 2) Fallback: name match (case-insensitive)
    users = db.execute(select(User).where(User.name.ilike(ident))).scalars().all()
    if len(users) == 1:
        return users[0]
    if len(users) > 1:
        raise HTTPException(status_code=409, detail="Multiple users with same name. Use email.")
    return None


def _create_user(db: Session, name: str, email: str, password: str, role: str) -> User:
    existing = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        name=name.strip(),
        email=email.lower().strip(),
        password_hash=hash_password(password),
        role=role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/register/student", response_model=UserOut)
def register_student(payload: RegisterSimple, db: Session = Depends(get_db)):
    return _create_user(db, payload.name, payload.email, payload.password, "student")


@router.post("/register/teacher", response_model=UserOut)
def register_teacher(payload: RegisterSimple, db: Session = Depends(get_db)):
    return _create_user(db, payload.name, payload.email, payload.password, "teacher")


# OAuth2PasswordRequestForm expects: username=EMAIL, password=...
@router.post("/login", response_model=TokenOut)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = _find_user_by_identifier(db, form.username)

    if (not user) or (not verify_password(form.password, user.password_hash)):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token = create_access_token(subject=user.id, role=user.role)
    return TokenOut(access_token=token)


@router.post("/login/json", response_model=TokenOut)
def login_json(payload: LoginIn, db: Session = Depends(get_db)):
    user = _find_user_by_identifier(db, payload.email)

    if (not user) or (not verify_password(payload.password, user.password_hash)):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token = create_access_token(subject=user.id, role=user.role)
    return TokenOut(access_token=token)


@router.post("/login/json/student", response_model=TokenOut)
def login_json_student(payload: LoginIn, db: Session = Depends(get_db)):
    user = _find_user_by_identifier(db, payload.email)

    if (not user) or (not verify_password(payload.password, user.password_hash)):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if user.role != "student":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a student account")

    token = create_access_token(subject=user.id, role=user.role)
    return TokenOut(access_token=token)


@router.post("/login/json/teacher", response_model=TokenOut)
def login_json_teacher(payload: LoginIn, db: Session = Depends(get_db)):
    user = _find_user_by_identifier(db, payload.email)

    if (not user) or (not verify_password(payload.password, user.password_hash)):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if user.role != "teacher":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a teacher account")

    token = create_access_token(subject=user.id, role=user.role)
    return TokenOut(access_token=token)


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)):
    return current_user
