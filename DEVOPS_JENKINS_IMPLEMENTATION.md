# LEXSUM DevOps Implementation - 7 Cs of DevOps

## Executive Summary

This document describes the complete DevOps implementation for the LEXSUM Classroom Application, achieving all 7 Cs of DevOps:

1. **Code** - Git repository with feature branches and commit hooks
2. **Commit** - Automated Jenkins pipeline triggers on every commit
3. **Compile** - Python environment preparation and dependency resolution
4. **Configure** - Infrastructure-as-Code with systemd services and monitoring
5. **Compose** - Resource orchestration and service composition
6. **Continuous Integration** - Automated testing and quality assurance
7. **Continuous Deployment** - Automated deployment with rollback capability

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Git Repository (Main & Develop)             │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Feature Branches → Pull Request → Code Review → Merge   │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────────────┘
                     │ Push Event
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              Jenkins Server (CI/CD Orchestration)                │
│                                                                   │
│  ┌────────────┬───────────────┬─────────────┬────────────────┐  │
│  │   Code    │    Commit      │   Compile   │   Configure    │  │
│  │ Checkout  │ & Test & Build │ Env Setup   │ Security Scan  │  │
│  └────────────┴───────────────┴─────────────┴────────────────┘  │
│                            ↓                                      │
│  ┌────────────┬───────────────┬─────────────┬────────────────┐  │
│  │  Compose   │      CI        │      CD      │   Monitoring   │  │
│  │  Build APK │   Coverage     │   Deploy to  │   Health Check │  │
│  │  Build Pkg │   Reports      │   Staging    │   Alerts       │  │
│  └────────────┴───────────────┴─────────────┴────────────────┘  │
└────────────┬───────────────────────────────────────────┬─────────┘
             │                                           │
    ┌────────▼────────┐                       ┌────────▼────────┐
    │ Staging Server  │                       │ Production      │
    │                 │                       │ Server          │
    │ ┌─────────────┐ │                       │ ┌─────────────┐ │
    │ │Backend API  │ │                       │ │Backend API  │ │
    │ │8000         │ │                       │ │8000         │ │
    │ └─────────────┘ │                       │ └─────────────┘ │
    │ ┌─────────────┐ │                       │ ┌─────────────┐ │
    │ │Worker       │ │                       │ │Worker       │ │
    │ │Modal/Celery │ │                       │ │Modal/Celery │ │
    │ └─────────────┘ │                       │ └─────────────┘ │
    │ ┌─────────────┐ │                       │ ┌─────────────┐ │
    │ │PostgreSQL   │ │                       │ │PostgreSQL   │ │
    │ └─────────────┘ │                       │ └─────────────┘ │
    │ ┌─────────────┐ │                       │ ┌─────────────┐ │
    │ │Redis Cache  │ │                       │ │Redis Cache  │ │
    │ └─────────────┘ │                       │ └─────────────┘ │
    └─────────────────┘                       └─────────────────┘
             │                                           │
             └───────────────────┬──────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Monitoring Stack       │
                    │ ┌──────────────────────┐│
                    │ │ Prometheus (9090)    ││
                    │ │ - Metrics Collection ││
                    │ │ - 30-day Storage     ││
                    │ │ - Alert Evaluation   ││
                    │ └──────────────────────┘│
                    │ ┌──────────────────────┐│
                    │ │ Grafana (3000)       ││
                    │ │ - Dashboards         ││
                    │ │ - Visualization      ││
                    │ │ - User Management    ││
                    │ └──────────────────────┘│
                    │ ┌──────────────────────┐│
                    │ │ Exporters            ││
                    │ │ - Node Exporter      ││
                    │ │ - PostgreSQL         ││
                    │ │ - Redis              ││
                    │ │ - Black Box          ││
                    │ └──────────────────────┘│
                    └─────────────────────────┘
```

## 7 Cs of DevOps Implementation

### 1. CODE - Version Control & Source Management

**Objective:** Maintain clean, well-organized source code with clear commit history

**Implementation:**
- **Git Repository:** Centralized version control with branching strategy
- **Branch Strategy:** 
  - `main` - Production releases (stable)
  - `develop` - Development integration (pre-release)
  - `feature/*` - Individual feature development
- **Commit Hooks:** Enforce code quality standards before committing
- **Pull Requests:** Mandatory code review before merging
- **No Docker:** Implementation compatible with storage-constrained environments

**Files:**
- `.gitignore` - Exclude build artifacts, node_modules, venv
- `README.md` - Project documentation
- `CHANGELOG.md` - Version history (recommended)

**Validation:**
```bash
git log --oneline -10  # Verify clean commit history
git branch -a          # Show all branches
```

---

### 2. COMMIT - Build Triggers & Continuous Integration

**Objective:** Automatically trigger build pipelines on code commits

**Implementation:**
- **GitHub Webhook:** Triggers Jenkins pipeline on push events
- **Poll SCM:** Fallback mechanism (every 15 minutes)
- **Commit Metadata:** Capture author, timestamp, message for audit trail
- **Build Identification:** Jenkins BUILD_NUMBER links to commits

**Pipeline Trigger Conditions:**
```groovy
triggers {
    githubPush()                  // On push event
    pollSCM('H/15 * * * *')      // Every 15 minutes
}
```

**Validation:**
```bash
git log --pretty=oneline master..HEAD  # See pending commits
```

---

### 3. COMPILE - Environment Setup & Dependency Resolution

**Objective:** Prepare clean, consistent build environments

**Implementation:**

**Backend (Python):**
```bash
python3 -m venv venv              # Isolated virtual environment
source venv/bin/activate
pip install --upgrade pip
pip install -e ./backend          # Install with dependencies
```

**Frontend (Flutter):**
```bash
flutter clean                   # Clean previous builds
flutter pub get                # Resolve dependencies
flutter pub outdated           # Check for updates
```

**Dependency Management:**
- `backend/pyproject.toml` - Python dependencies with version pinning
- `pubspec.yaml` - Flutter/Dart dependencies
- `backend/requirements.txt` - Frozen dependencies (optional)

**Build Quality Checks:**
```bash
pytest tests/ -v                              # Unit tests
pytest --cov=app --cov-report=html           # Coverage report
ruff check app/                               # Linting
pyright app/                                  # Type checking
safety check                                  # Security audit
```

**Validation:**
```bash
pip show FastAPI SQLAlchemy pytest           # Verify installations
flutter pub get --dry-run                    # Check pubspec resolution
```

---

### 4. CONFIGURE - Infrastructure as Code & Configuration Management

**Objective:** Define and manage infrastructure declaratively

**Implementation:**

**systemd Service Files:**
- Purpose: Manage service lifecycle (start/stop/restart)
- Location: `/etc/systemd/system/`
- Services:
  - `classroom-backend.service` - FastAPI application
  - `classroom-worker.service` - Background job processor

**Service Configuration:**
```ini
[Unit]
Description=LEXSUM Classroom Backend API
After=network-online.target postgresql.service

[Service]
Type=notify
User=www-data
WorkingDirectory=/opt/classroom-app/backend
ExecStart=uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

**Configuration Files:**
- `.env` - Environment variables (database, API keys, secrets)
- `monitoring/prometheus.yml` - Metric collection rules
- `monitoring/alert_rules.yml` - Alert thresholds
- `Jenkinsfile` - CI/CD pipeline definition

**Resource Limits:**
```
Backend API:
  - Memory: 1GB
  - CPU: 80% quota
  - File descriptors: 65535
  - Processes: 65535

Worker:
  - Memory: 3GB
  - CPU: 90% quota
  - Graceful shutdown: 30 seconds
```

**Validation:**
```bash
systemctl status classroom-backend          # Check service status
systemctl cat classroom-backend.service     # Review configuration
journalctl -u classroom-backend -n 50       # Recent logs
```

---

### 5. COMPOSE - Resource Orchestration & Service Composition

**Objective:** Coordinate multiple services and resources

**Implementation:**

**Service Dependencies:**
```
Frontend (Flutter)
    ↓ depends on
Backend API (port 8000)
    ↓ depends on
PostgreSQL (connection pool)
Database  ↓
Redis Cache (session, queue storage)
    ↓ depends on
Background Workers (Modal/Celery)
    ↓ depends on
External APIs (Whisper ASR, Mistral LLM)
```

**Resource Composition:**
```bash
# Backend API - 4 workers
ExecStart=uvicorn app.main:app --workers 4

# Redis Connection Pool - 100 max
REDIS_MAX_CONNECTIONS=100

# PostgreSQL Connection Pool - 20 default
DATABASE_POOL_SIZE=20

# Worker Pool
Workers can be scaled horizontally
```

**Service Orchestration:**
```bash
# Deploy in order
1. PostgreSQL (database)
2. Redis (cache/queue)
3. classroom-backend.service
4. classroom-worker.service
5. Frontend (APK to devices)

# Teardown in reverse
5. Stop frontend clients
4. Stop workers
3. Stop backend
2. Stop Redis
1. Stop PostgreSQL
```

**Validation:**
```bash
# Check all services
systemctl list-units --type=service
systemctl status classroom-*

# Verify connectivity
curl http://localhost:8000/health
redis-cli ping
psql -c "SELECT 1"
```

---

### 6. CONTINUOUS INTEGRATION - Automated Testing & Quality Assurance

**Objective:** Validate code quality automatically on every commit

**Implementation:**

**14-Stage Jenkins Pipeline:**

**Phase 1: Code Preparation**
```
Stage 1: Checkout Code
  └─ git clone && git log
Stage 2: Setup Backend Environment
  └─ python3 -m venv && pip install
Stage 3: Setup Frontend Environment
  └─ flutter pub get && flutter doctor
```

**Phase 2: Testing**
```
Stage 4: Backend Unit Tests
  └─ pytest with --cov=app --cov-report=html
  └─ Output: backend/htmlcov/index.html
Stage 5: Backend Code Quality
  └─ ruff (linting)
  └─ pyright (type checking)
  └─ safety (security scanning)
Stage 6: Frontend Tests
  └─ flutter test --coverage
  └─ Output: coverage/html/index.html
Stage 7: Frontend Analysis
  └─ flutter analyze
```

**Phase 3: Build & Artifact Creation**
```
Stage 8: Build Backend
  └─ python setup.py sdist bdist_wheel
  └─ Output: artifacts/backend/
Stage 9: Build Frontend APK
  └─ flutter build apk --release
  └─ Output: artifacts/flutter/app-release.apk
```

**Phase 4: Security & Validation**
```
Stage 10: Security Scanning
  └─ safety check (dependencies)
  └─ flutter pub outdated
Stage 11: Integration Tests
  └─ Full API test suite
```

**Test Coverage:**
- **Backend:** pytest with coverage tracking (target: >80%)
- **Frontend:** Flutter widget tests (target: >70%)
- **Integration:** End-to-end API tests
- **Security:** OWASP dependency scanning

**Code Quality Standards:**
- Linting: PEP 8 compliance via ruff
- Type Checking: Python 3.10+ type hints via pyright
- Security: Vulnerability scanning via safety
- Documentation: API docstrings, inline comments

**Validation:**
```bash
# Local testing before push
pytest tests/ -v --cov=app
flutter test
ruff check app/
pyright app/

# Jenkins pipeline logs
# http://jenkins.example.com/job/LEXSUM/lastBuild/
```

---

### 7. CONTINUOUS DEPLOYMENT - Automated Release Pipeline

**Objective:** Reliably deploy tested code to production

**Implementation:**

**Deployment Pipeline:**

**Stage 12: Deploy to Staging** (develop branch)
```
Trigger: Automatic on develop branch push
Actions:
  1. Pre-deployment health checks
  2. Backup current staging code
  3. Deploy backend to staging server
  4. Install dependencies
  5. Run database migrations
  6. Restart services
  7. Verify health (30-second retry loop)
  8. Generate deployment report
```

**Stage 13: Deploy to Production** (main branch)
```
Trigger: Manual approval on main branch push
Actions:
  1. Pre-flight checks (same as staging)
  2. Create production backup
  3. Deploy backend to production
  4. Apply database migrations with rollback plan
  5. Restart backend and worker services
  6. Monitor health (5-minute observation period)
  7. Send notifications
```

**Stage 14: Health Checks & Monitoring**
```
Post-Deployment:
  1. Health endpoint verification (curl /health)
  2. Service status monitoring
  3. Alert configuration validation
  4. Dashboard data validation
  5. Alert any anomalies detected
```

**Deployment Script** (`deployment/deploy.sh`):

**11-Phase Deployment:**
1. **Pre-deployment Checks** - Validate project structure
2. **Current Deployment Validation** - Check existing service health
3. **Backup Creation** - Full code & config backup with manifest
4. **Deployment Preparation** - Set up Python environment
5. **Artifact Validation** - Run test suite before deploying
6. **Service Stop** - Graceful service shutdown
7. **Code Deployment** - Copy new code and dependencies
8. **Database Migrations** - Apply Alembic migrations
9. **Service Start** - Restart with monitoring
10. **Post-Deployment Validation** - Health verification with retry
11. **Deployment Report** - Generate audit log

**Rollback Procedure:**
```bash
# Automatic rollback if health checks fail
If POST health_check FAILS:
  1. Restore backup from /root/backups/backup_TIMESTAMP/
  2. Reinstall dependencies
  3. Restart services
  4. Verify health again
  5. Alert operations team

# Manual rollback
./deployment/rollback.sh /path/to/backup
```

**Zero-Downtime Deployment Strategy:**
```
Option 1: Blue-Green Deployment
  - Run two versions in parallel
  - Switch traffic after new version validates
  - Old version remains as rollback

Option 2: Rolling Deployment
  - Deploy to workers sequentially
  - Load balancer routes around deploying instance
  - No traffic disruption
  - Requires multiple instances

Current Implementation: Single-instance with brief downtime
  - For small deployments
  - Suitable for scheduled maintenance windows
  - Quick restart time (< 5 seconds)
```

**Deployment Frequency:**
- **Staging:** Every commit to develop (multiple per day)
- **Production:** Selected commits to main (1-2 per week)
- **Hotfixes:** Emergency deployments from hotfix/* branches

**Validation:**
```bash
# Test deployment locally
./deployment/deploy.sh staging

# Verify services
curl http://localhost:8000/health     # Backend health
curl http://localhost:8000/api/v1/    # API availability

# Check logs
journalctl -u classroom-backend -f
journalctl -u classroom-worker -f
```

---

## Monitoring & Observability

### Prometheus (Metrics Collection)

**Scrape Targets:**
- Backend API: `/metrics` endpoint
- PostgreSQL: postgres_exporter on 9187
- Redis: redis_exporter on 9121
- System: node_exporter on 9100
- Endpoints: blackbox_exporter on 9115

**Data Retention:**
- Default: 30 days of metrics
- Configurable via `--storage.tsdb.retention.time`

**Key Metrics:**
```
HTTP Requests:
  - http_requests_total (counter)
  - http_request_duration_seconds (histogram)
  - http_requests_errors (counter)

System Resources:
  - node_cpu_seconds_total (gauge)
  - node_memory_MemAvailable_bytes (gauge)
  - node_filesystem_avail_bytes (gauge)

Database:
  - pg_stat_database_connections (gauge)
  - pg_stat_database_cache_hit (counter)
  - pg_statement_mean_exec_time (gauge)

Application:
  - lectures_processed_total (counter)
  - quiz_generated_total (counter)
  - transcription_completed_total (counter)
```

### Grafana (Visualization)

**Built-in Dashboards:**
1. **System Overview** - CPU, memory, disk, network
2. **Backend Performance** - Request rate, latency, errors
3. **Database Health** - Connections, queries, cache hit ratio
4. **Cache Performance** - Redis hits/misses, memory usage
5. **Application Metrics** - Business KPIs, user activity

**Alert Dashboard:**
- Real-time alert status
- Alert history and trends
- Incident management

### Alerting Rules (40+ rules)

**Severity Levels:**
- **Critical** - Immediate action required (paging)
- **Warning** - Should investigate within minutes
- **Info** - Informational for trending

**Alert Categories:**

Critical:
```
- BackendAPIDown              → Service unreachable
- PostgreSQLDown             → Database unavailable
- RedisDown                  → Cache unavailable
- NodeDown                   → System node unavailable  
- DiskSpaceLimitReached      → 90%+ disk utilization
- HighMemoryUsage            → >90% memory utilization
```

Warning:
```
- BackendHighErrorRate       → >5% error rate
- BackendHighLatency         → >1 second p95 latency
- PostgreSQLHighConnections  → >80 connections
- PostgreSQLDiskSpaceLow     → <10% free space
- RedisMemoryUsageHigh       → >90% memory usage
- HighCPUUsage               → >80% CPU utilization
- HighLoadAverage            → >4.0
```

**Alert Notification Channels:**
- Email (system admin)
- Slack (operations channel)
- PagerDuty (on-call rotation)
- Webhooks (custom integrations)

---

## Security & Governance

### Infrastructure Security

**systemd Service Hardening:**
```ini
NoNewPrivileges=true              # Prevent privilege escalation
PrivateTmp=true                   # Isolated /tmp
ProtectSystem=strict              # Read-only / filesystem
ProtectHome=true                  # No access to /home
ReadWritePaths=/opt/classroom/*   # Explicit write paths
```

**Network Security:**
- Backend on private network (127.0.0.1 or internal IP)
- HTTPS reverse proxy required for public access
- API key authentication in headers
- JWT token-based session management

**Database Security:**
- Credentials in `.env`, never in code
- Connection pooling to prevent exhaustion
- SQL parameterization (SQLAlchemy ORM)
- Regular backup encryption

**Deployment Security:**
- Automated backups before each deployment
- Rollback capability preserved
- Audit logs of all changes
- Signed deployment scripts

### Compliance & Auditing

**Deployment Audit Trail:**
```
Deployment logs location:
  /root/backups/backup_TIMESTAMP/deployment.log

Logged information:
  - Deployment timestamp
  - Environment (staging/production)
  - Deployed services/components
  - Health check results
  - Backup file location
  - Rollback instructions
```

**Change Log:**
```bash
git log --oneline           # Code changes
journalctl -u Service       # Service changes
systemctl list-units        # Service status history
```

---

## Performance Optimization

### Backend API Performance

**Uvicorn Configuration:**
```bash
--workers 4                 # 4 worker processes
--worker-class uvicorn.workers.UvicornWorker
--timeout 120              # 2-minute request timeout
--max-requests 1000        # Restart after 1000 requests
--loop uvloop              # High-performance event loop
```

**Database Optimization:**
```env
DATABASE_POOL_SIZE=20              # Connection pool
DATABASE_POOL_RECYCLE=3600         # Recycle after 1 hour
SQLALCHEMY_ECHO=false              # Don't log queries
```

**Caching Strategy:**
```python
# Redis cache for:
- User sessions (TTL: 24 hours)
- Subject/lecture metadata (TTL: 1 hour)
- Quiz generation results (TTL: 7 days)
- API responses (TTL: 15 minutes)
```

### Monitoring Performance
```
High latency diagnosis:
  1. Check slow query logs
  2. Review database query plan (EXPLAIN)
  3. Check Redis evictions
  4. Monitor worker CPU/memory
  5. Review error rates
```

---

## Disaster Recovery

### Backup Strategy

**Backup Frequency:**
- Automatic backup before each deployment
- Daily backup cron job (11 PM)
- Weekly full database snapshot (Saturday)
- Monthly archive backup

**Backup Contents:**
```
backup_TIMESTAMP/
├── backend_code/        # Full backend source
├── .env                 # Configuration
├── database_dump        # PostgreSQL dump
├── backup_manifest.txt  # Restore instructions
└── deployment.log       # What changed
```

**Restoration Procedure:**
```bash
# 1. Stop services
sudo systemctl stop classroom-backend
sudo systemctl stop classroom-worker

# 2. Restore code
cp -r backup_*/backend_code/* /opt/classroom-app/backend/

# 3. Restore configuration
cp backup_*/.env /opt/classroom-app/backend/

# 4. Reinstall dependencies
cd /opt/classroom-app/backend
source venv/bin/activate
pip install -e .

# 5. Start services
sudo systemctl start classroom-backend
sudo systemctl start classroom-worker

# 6. Verify health
curl http://localhost:8000/health
```

**Recovery Time Objectives (RTO):**
- Backend API: < 5 minutes
- Database: < 10 minutes
- Full system: < 15 minutes

**Recovery Point Objectives (RPO):**
- Code: 0 minutes (every deployment)
- Configuration: < 1 hour
- Database: < 1 hour (daily snapshots)

---

## Metrics & KPIs

### Operational Metrics

**Availability:**
```
Target: 99.5% uptime
Formula: (Total Time - Downtime) / Total Time
Measured: % of successful health checks
```

**Deployment Frequency:**
```
Target: 1-2 deployments per week
Measured: Deployments to production per week
Tracked: Jenkins build history
```

**Deployment Success Rate:**
```
Target: 99% success (1 rollback per 100 deployments)
Formula: Successful Deployments / Total Deployments
Rollback tracked in deployment logs
```

**Mean Time to Detection (MTTD):**
```
Target: < 5 minutes
Measured: Time from issue to alert
Configured in Prometheus scrape intervals
```

**Mean Time to Repair (MTTR):**
```
Target: < 15 minutes
Measured: Time from alert to resolution
Includes: escalation, remediation, verification
```

### Business Metrics

```
Active Users:
  sum(rate(user_session_total[1m]) > 0)

Lectures Processed:
  rate(lectures_processed_total[1m])

Quiz Generation Rate:
  rate(quiz_generated_total[1m])

API Success Rate:
  rate(http_requests_total{status=~"2.."}[5m]) /
  rate(http_requests_total[5m])

User Retention:
  (Users from 30 days ago - Inactive users) / Users from 30 days ago
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [x] Application deployment scripts
- [x] systemd service files
- [x] Basic monitoring setup
- [x] Jenkins pipeline configuration

### Phase 2: Automation (Weeks 3-4)
- [x] End-to-end deployment automation
- [x] Automated testing integration
- [x] Coverage reporting
- [x] Security scanning

### Phase 3: Observability (Weeks 5-6)
- [x] Prometheus monitoring
- [x] Grafana dashboards
- [x] Alert rules
- [x] Health check automation

### Phase 4: Optimization (Weeks 7-8)
- [ ] Performance profiling
- [ ] Database query optimization
- [ ] Caching strategy refinement
- [ ] Load testing

### Phase 5: Scaling (Weeks 9-10)
- [ ] Multi-instance deployment
- [ ] Load balancer configuration
- [ ] Horizontal scaling policies
- [ ] Global CDN setup

### Phase 6: Documentation (Ongoing)
- [x] This document
- [x] Deployment runbooks
- [x] Alert response procedures
- [ ] Training materials

---

## Conclusion

The LEXSUM DevOps implementation successfully achieves all **7 Cs of DevOps**:

✅ **Code** - Git-based version control with clean branching strategy
✅ **Commit** - Automatic pipeline triggers on every commit
✅ **Compile** - Consistent environment setup with dependency management
✅ **Configure** - Infrastructure-as-Code with systemd and monitoring
✅ **Compose** - Resource orchestration across multiple services
✅ **Continuous Integration** - 14-stage automated testing pipeline
✅ **Continuous Deployment** - Automated deployment with rollback

The implementation emphasizes:
- **Reliability** - Automated backups, health checks, rollback capability
- **Observability** - Comprehensive monitoring with 40+ alert rules
- **Security** - Service hardening, credential management, audit logging
- **Simplicity** - No Docker, single-instance deployment, easy maintenance
- **Scalability** - Foundation for multi-instance deployment ready

This DevOps infrastructure enables the LEXSUM team to deploy with confidence, monitor with visibility, and respond to issues rapidly.

---

**Document Version:** 1.0
**Last Updated:** 2024
**Status:** Production Ready
