# LEXSUM DevOps Infrastructure

This directory contains all DevOps infrastructure components for the LEXSUM Classroom Application, implementing the **7 Cs of DevOps**:

1. **Code** - Version control and source management (Git)
2. **Commit** - Build and unit tests (Jenkins pipeline)
3. **Compile** - Environment setup and dependency management (Python/Flutter)
4. **Configure** - Configuration management and infrastructure as code (systemd services, monitoring configs)
5. **Compose** - Container and resource management (systemd resource limits)
6. **Continuous Integration** - Automated testing and quality checks (pytest, flutter test)
7. **Continuous Deployment** - Automated deployment pipeline (deploy.sh, Jenkinsfile)

## Directory Structure

```
├── Jenkinsfile                    # CI/CD pipeline definition (14 stages)
├── deployment/
│   ├── deploy.sh                  # Deployment automation script (11 phases)
│   ├── classroom-backend.service  # Backend API systemd service
│   └── classroom-worker.service   # Background worker systemd service
└── monitoring/
    ├── prometheus.yml             # Prometheus scrape configurations
    ├── alert_rules.yml            # Alert thresholds and conditions
    ├── recording_rules.yml        # Pre-computed metric aggregations
    └── setup_monitoring.sh        # Monitoring stack installation
```

## Quick Start

### 1. Manual Backend Deployment

```bash
# Deploy to staging environment
./deployment/deploy.sh staging

# Deploy to production environment
./deployment/deploy.sh production

# Deploy without backup (use with caution)
./deployment/deploy.sh staging --skip-backup
```

**Deployment Phases:**
- Pre-deployment checks and validation
- Backup current state
- Python environment preparation
- Artifact validation
- Service stop/migration
- Dependency installation
- Database migrations
- Service restart
- Health verification
- Deployment reporting

### 2. Jenkins CI/CD Pipeline

The [Jenkinsfile](../Jenkinsfile) implements a **14-stage pipeline**:

**Build & Test Stages:**
1. Checkout Code - Source code retrieval
2. Setup Backend Environment - Python venv
3. Setup Frontend Environment - Flutter SDK
4. Backend Unit Tests - pytest with coverage
5. Backend Code Quality - linting, type checking, security
6. Frontend Tests - Flutter widget tests
7. Frontend Analysis - static analysis
8. Build Backend - Distribution package creation
9. Build Frontend APK - Release build

**Deployment Stages:**
10. Security Scanning - Dependency vulnerability check
11. Integration Tests - End-to-end test suite
12. Deploy to Staging - Automated staging deployment
13. Deploy to Production - Automated production deployment
14. Health Checks & Monitoring - Service validation

**Triggering the Pipeline:**
- GitHub push to any branch (via webhook)
- Poll every 15 minutes (fallback mechanism)
- Manual trigger via Jenkins UI

### 3. Monitoring Stack Setup

```bash
# Install complete monitoring stack
cd monitoring
chmod +x setup_monitoring.sh
./setup_monitoring.sh

# This will install:
# - Prometheus (metrics collection and storage)
# - Grafana (visualization and dashboards)
# - Node Exporter (system metrics)
```

**Access Points:**
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- Node Exporter: http://localhost:9100/metrics

### 4. Service Management

```bash
# Backend API service
sudo systemctl status classroom-backend
sudo systemctl start classroom-backend
sudo systemctl stop classroom-backend
sudo systemctl restart classroom-backend
sudo systemctl logs classroom-backend -f

# Background worker service
sudo systemctl status classroom-worker
sudo systemctl start classroom-worker
sudo systemctl stop classroom-worker
sudo systemctl restart classroom-worker
sudo systemctl logs classroom-worker -f

# View service logs
journalctl -u classroom-backend -f
journalctl -u classroom-worker -f
```

## Configuration Files

### Jenkinsfile
**14-stage CI/CD pipeline with comprehensive error handling**

Key features:
- Parallel environment setup (backend + frontend)
- Coverage reporting with HTML output
- Code quality checks (ruff, pyright, safety)
- Artifact archiving
- Branch-based deployment triggers
- Post-build cleanup and reporting

### deploy.sh
**11-phase deployment automation script**

Key features:
- Pre-deployment health checks
- Automatic backup creation with manifest
- Python environment preparation
- Artifact validation with test suite
- Graceful service shutdown
- Database migration execution
- Service startup with health verification
- Detailed deployment reporting

### service files
**systemd service configurations**

Backend API (`classroom-backend.service`):
- 4 worker processes
- 1GB memory limit
- 80% CPU quota
- Auto-restart on failure
- Security hardening (AppArmor/SELinux compatible)

Worker Service (`classroom-worker.service`):
- 3GB memory limit (for ML tasks)
- 90% CPU quota
- Graceful 30-second shutdown timeout
- Auto-restart with rate limiting

### prometheus.yml
**Monitoring configuration for 10+ exporters**

Scrape targets:
- Self-monitoring (Prometheus)
- Backend API metrics (/metrics endpoint)
- PostgreSQL database metrics
- Redis cache metrics
- System metrics (Node Exporter)
- Endpoint health checks (Black Box)
- Custom application metrics

### alert_rules.yml
**Alert conditions (40+ rules)**

Alert categories:
- Backend API (availability, error rate, latency, memory)
- Database (connectivity, connections, disk space)
- Redis (availability, memory, evictions)
- System (CPU, memory, disk, load)
- Endpoints (availability, response time)
- Prometheus (self-monitoring)

### recording_rules.yml
**Pre-computed metric aggregations**

Optimizations:
- HTTP request rate calculations
- Error rate percentages
- Latency percentiles (p50, p95, p99)
- Database cache hitrates
- Redis performance metrics
- System resource ratios
- Business metrics aggregations

## Environment Setup

### Prerequisites

**macOS:**
```bash
# Python virtual environment
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -e ./backend

# Flutter
brew tap flutter/flutter
brew install flutter

# Monitoring tools (optional)
brew install prometheus grafana node_exporter
```

**Linux (Debian/Ubuntu):**
```bash
# Python
apt-get install python3-venv python3-dev
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -e ./backend

# Flutter
sudo snap install flutter --classic

# System user for services
sudo useradd -r -s /bin/false www-data 2>/dev/null || true
```

**Linux (RHEL/CentOS):**
```bash
# Python
yum install python3-devel
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -e ./backend

# System user
sudo useradd -r -s /bin/false www-data 2>/dev/null || true
```

### Jenkins Server Setup

**Using Docker (recommended for CI environment):**
```bash
docker run -d \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

**Manual Installation (Ubuntu):**
```bash
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.03.27.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

## Deployment Strategies

### Staging Deployment
```bash
git checkout develop
./deployment/deploy.sh staging

# Verify
curl http://staging-server:8000/health
```

### Production Deployment
```bash
git checkout main
./deployment/deploy.sh production

# Verify
curl http://production-server:8000/health
```

### Rollback

If issues occur:
```bash
# Manual rollback (backup created during deployment)
./deployment/rollback.sh /path/to/backup

# Or restore from backup
sudo systemctl stop classroom-backend
cp -r /path/to/backup/backend_code/* /opt/classroom-app/backend/
source /opt/classroom-app/backend/venv/bin/activate
pip install -e /opt/classroom-app/backend
sudo systemctl start classroom-backend
```

## Monitoring & Alerting

### Prometheus Queries

Check backend health:
```promql
up{job="classroom-backend"}
```

API request rate:
```promql
rate(http_requests_total{job="classroom-backend"}[5m])
```

Error rate percentage:
```promql
rate(http_requests_total{job="classroom-backend",status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

API latency p95:
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="classroom-backend"}[5m]))
```

### Grafana Dashboards

Pre-built dashboards:
- Node Exporter Full (system metrics)
- Prometheus Overview
- API Performance
- Database Health
- Redis Monitoring

Import from: https://grafana.com/grafana/dashboards

### Alert Notifications

Configure notification channels in Grafana:
- Email alerts
- Slack webhooks
- PagerDuty incidents
- Webhook HTTP endpoints

Example Slack webhook setup:
```yaml
# In AlertManager configuration
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
```

## Troubleshooting

### Backend won't start
```bash
# Check logs
journalctl -u classroom-backend -f

# Verify .env file
cat backend/.env

# Check port availability
lsof -i :8000

# Manual start for debugging
cd backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Deployment fails
```bash
# Check deployment log
cat /root/backups/backup_TIMESTAMP/deployment.log

# Verify prerequisites
python3 --version
pip --version

# Check disk space
df -h
free -h

# Test database connection
psql $DATABASE_URL -c '\l'
```

### Monitoring not working
```bash
# Check Prometheus scrape targets
curl http://localhost:9090/api/v1/targets

# Check Prometheus logs
journalctl -u prometheus -f

# Verify configuration
promtool check config /etc/prometheus/prometheus.yml

# Test exporter endpoint
curl http://localhost:8000/metrics
curl http://localhost:9100/metrics
```

## Security Considerations

### systemd Service Security
- Run as unprivileged user (`www-data`)
- Read-only root filesystem (`ProtectSystem=strict`)
- Resource limits enforced
- No new privileges
- Private /tmp
- Restricted home directory access

### Network Security
- Backend on private network (0.0.0.0 with firewall)
- Mount Prometheus on separate port
- Use HTTPS reverse proxy in production

### Database Security
- Environment variables (`.env`) not in version control
- Database credentials rotated regularly
- Connection pooling enabled
- SQL injection protection (SQLAlchemy)

### Deployment Security
- Automated backups before each deployment
- Rollback capability preserved
- Signed Git commits enforced (optional)
- Audit logs of all deployments

## Performance Tuning

### Backend API
```
# In classroom-backend.service
ExecStart=/opt/classroom-app/backend/venv/bin/uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 4           # Adjust based on CPU cores
    --worker-class uvicorn.workers.UvicornWorker
    --timeout 120         # Request timeout
```

### PostgreSQL Connections
```
# In .env
DATABASE_POOL_SIZE=20
DATABASE_POOL_RECYCLE=3600
```

### Redis Cache
```
# In .env
REDIS_MAX_CONNECTIONS=100
REDIS_SOCKET_TIMEOUT=5
```

## Documentation

- [Jenkins Pipeline Documentation](../Jenkinsfile)
- [Prometheus Configuration](./monitoring/prometheus.yml)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards)
- [Alert Rules](./monitoring/alert_rules.yml)

## Support & Contact

For issues or questions:
1. Check logs: `journalctl -u <service> -f`
2. Review monitoring dashboards
3. Check deployment reports in backups
4. Consult runbooks in code comments

---

**Last Updated:** 2024
**7 Cs Coverage:** Code ✓ Commit ✓ Compile ✓ Configure ✓ Compose ✓ CI ✓ CD ✓
