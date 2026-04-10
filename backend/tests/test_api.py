import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Force test database before importing application modules that initialize DB engine.
TEST_DATABASE_URL = "sqlite:///./test.db"
os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ.setdefault("APP_ENV", "test")

from app.config import settings
from app.db import Base, get_db
from app.main import app

# Create test engine
test_engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

@pytest.fixture(scope="function")
def db():
    # Create tables
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        # Drop tables
        Base.metadata.drop_all(bind=test_engine)

@pytest.fixture(scope="module")
def client():
    # Override settings for testing
    settings.DATABASE_URL = TEST_DATABASE_URL
    settings.REDIS_URL = "redis://localhost:6379/0"  # Mock if needed

    # Create schema once for API tests using the overridden DB dependency.
    Base.metadata.create_all(bind=test_engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=test_engine)

def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"ok": True, "env": settings.APP_ENV}

def test_auth_endpoints(client):
    # Test register
    response = client.post("/auth/register", json={
        "name": "Test User",
        "email": "test@example.com",
        "password": "password123"
    })
    assert response.status_code == 200

    # Test login
    response = client.post("/auth/login/json", json={
        "email": "test@example.com",
        "password": "password123"
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "token_type" in data

def test_subjects_endpoints(client):
    # First register and login
    client.post("/auth/register", json={
        "name": "Teacher",
        "email": "teacher@example.com",
        "password": "password123"
    })
    login_response = client.post("/auth/login/json", json={
        "email": "teacher@example.com",
        "password": "password123"
    })
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create subject
    response = client.post("/subjects/", json={
        "name": "Test Subject",
        "description": "A test subject"
    }, headers=headers)
    assert response.status_code == 200
    subject_data = response.json()
    assert subject_data["name"] == "Test Subject"

    # Get subjects
    response = client.get("/subjects/", headers=headers)
    assert response.status_code == 200
    assert len(response.json()) > 0