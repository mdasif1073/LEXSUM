# LEXSUM

Flutter + FastAPI classroom app with DevOps pipeline.

## Architecture

- **Frontend:** Flutter multiplatform (iOS, Android, Web)
- **Backend:** FastAPI with SQLAlchemy ORM
- **Database:** PostgreSQL
- **Cache/Queue:** Redis
- **ML Processing:** Background workers with Whisper ASR and Mistral LLM
- **DevOps:** Jenkins CI/CD, systemd deployment, Prometheus monitoring

## Features

- User authentication with JWT
- Subject management
- Lecture recording and processing
- Automatic quiz generation
- Photo sharing
- Search functionality

## Quick Start

### Local Development

#### Backend Setup
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```

#### Database Setup
```bash
# Install PostgreSQL and Redis locally
# macOS
brew install postgresql redis
brew services start postgresql
brew services start redis

# Create database
createdb classroom_dev
```

#### Frontend Setup
```bash
flutter pub get
flutter run -d <device>
```

### Production Deployment

#### Server Requirements
- Ubuntu 20.04+ or similar Linux distribution
- Python 3.10+
- PostgreSQL
- Redis
- Nginx

#### Deployment Steps
```bash
# On server
sudo ./deployment/deploy.sh production

# Setup monitoring
sudo ./monitoring/setup_monitoring.sh
```

## CI/CD Pipeline

The project includes a complete Jenkins pipeline for:

- Automated testing (backend + frontend)
- Code quality checks
- Security scanning
- Deployment to staging/production
- APK building and archiving

### Jenkins Setup

1. Install Jenkins on a server
2. Create a new pipeline job
3. Use the `Jenkinsfile` in the repository root
4. Configure SSH credentials for deployment servers
5. Set up GitHub webhooks for automatic builds

## Monitoring

- **Prometheus**: Metrics collection at `/metrics`
- **Grafana**: Dashboards (default: admin/admin)
- **Node Exporter**: System metrics
- **Health Checks**: `/health` endpoint

### Setup Monitoring
```bash
sudo ./monitoring/setup_monitoring.sh
```

## Operations

See [OPERATIONS.md](OPERATIONS.md) for detailed operational procedures, troubleshooting, and deployment guides.

## Development

### Testing

```bash
# Backend tests
cd backend
source venv/bin/activate
pytest tests/ -v --cov=app

# Frontend tests
flutter test
```

### Code Quality

- Backend: Ruff linting, type checking
- Frontend: Flutter analyze
- Security: Safety dependency scanning
