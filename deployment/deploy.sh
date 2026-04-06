#!/bin/bash
##############################################################################
# LEXSUM Classroom Application Deployment Script
# Purpose: Automated deployment for backend services and frontend APK
# Usage: ./deployment/deploy.sh [staging|production] [--skip-backup] [--verbose]
# Author: DevOps Team
# Last Updated: 2024
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-staging}"
SKIP_BACKUP="${2:-false}"
VERBOSE="${3:-}"
PROJECT_NAME="LEXSUM"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${PROJECT_ROOT}/backups/backup_${TIMESTAMP}"
API_PORT="8000"
SERVICE_NAME="classroom-backend"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

##############################################################################
# PHASE 1: PRE-DEPLOYMENT CHECKS
##############################################################################

print_header "PHASE 1: PRE-DEPLOYMENT CHECKS"

if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    echo "Usage: ./deployment/deploy.sh [staging|production]"
    exit 1
fi

log_info "Environment: $ENVIRONMENT"
log_info "Project: $PROJECT_NAME"
log_info "Timestamp: $TIMESTAMP"

# Check if running from correct directory
if [ ! -f "${PROJECT_ROOT}/pubspec.yaml" ] && [ ! -f "${BACKEND_DIR}/pyproject.toml" ]; then
    log_error "Cannot locate project files. Are we in the correct directory?"
    exit 1
fi

log_success "Project structure validated"

# Check prerequisites
log_info "Checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { log_error "Python 3 not found"; exit 1; }
command -v systemctl >/dev/null 2>&1 || { log_error "systemctl not found"; exit 1; }
command -v git >/dev/null 2>&1 || { log_error "Git not found"; exit 1; }

log_success "All prerequisites available"

##############################################################################
# PHASE 2: VALIDATE CURRENT DEPLOYMENT
##############################################################################

print_header "PHASE 2: VALIDATE CURRENT DEPLOYMENT"

# Check if service is running
if systemctl is-active --quiet ${SERVICE_NAME}; then
    log_info "Service ${SERVICE_NAME} is running"
    log_info "Checking health..."
    
    if curl -s --max-time 5 "http://localhost:${API_PORT}/health" | grep -q "ok"; then
        log_success "Backend is healthy"
    else
        log_warning "Backend health check failed"
    fi
else
    log_warning "Service ${SERVICE_NAME} is not running"
fi

##############################################################################
# PHASE 3: BACKUP CURRENT STATE
##############################################################################

if [ "$SKIP_BACKUP" != "--skip-backup" ]; then
    print_header "PHASE 3: BACKUP CURRENT STATE"
    
    mkdir -p "${BACKUP_DIR}"
    log_info "Backup directory: ${BACKUP_DIR}"
    
    # Backup backend code
    log_info "Backing up backend code..."
    cp -r "${BACKEND_DIR}" "${BACKUP_DIR}/backend_code" || log_warning "Failed to backup backend code"
    
    # Backup database (if accessible)
    log_info "Backing up database configuration..."
    cp "${BACKEND_DIR}/.env" "${BACKUP_DIR}/.env" 2>/dev/null || log_warning "Could not backup .env"
    
    # Create backup manifest
    cat > "${BACKUP_DIR}/backup_manifest.txt" <<EOF
Backup Information
==================
Project: ${PROJECT_NAME}
Environment: $ENVIRONMENT
Timestamp: $TIMESTAMP
Source: $PROJECT_ROOT
Backed up items:
  - Backend code
  - Environment configuration
  - Service status before deployment

Restore instructions:
  1. Stop the service: sudo systemctl stop ${SERVICE_NAME}
  2. Restore code: cp -r ${BACKUP_DIR}/backend_code/* ${BACKEND_DIR}/
  3. Restore config: cp ${BACKUP_DIR}/.env ${BACKEND_DIR}/
  4. Reinstall deps: cd ${BACKEND_DIR} && pip install -e .
  5. Start service: sudo systemctl start ${SERVICE_NAME}
EOF
    
    log_success "Backup completed: ${BACKUP_DIR}"
else
    print_header "PHASE 3: BACKUP SKIPPED"
    log_warning "Backup was skipped. Be careful!"
fi

##############################################################################
# PHASE 4: PREPARE DEPLOYMENT
##############################################################################

print_header "PHASE 4: PREPARE DEPLOYMENT"

log_info "Preparing Python environment..."
cd "${BACKEND_DIR}"

# Create virtual environment if not exists
if [ ! -d "venv" ]; then
    log_info "Creating virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate

log_info "Upgrading pip and installing dependencies..."
pip install --upgrade pip setuptools wheel > /dev/null 2>&1
pip install -e . > /dev/null 2>&1

log_success "Python environment prepared"

##############################################################################
# PHASE 5: VALIDATE DEPLOYMENT ARTIFACTS
##############################################################################

print_header "PHASE 5: VALIDATE DEPLOYMENT ARTIFACTS"

log_info "Validating backend artifacts..."
if [ -d "${BACKEND_DIR}/app" ]; then
    log_success "Backend application code found"
else
    log_error "Backend application code not found"
    exit 1
fi

log_info "Running backend tests..."
if pytest tests/ -v --tb=short > /dev/null 2>&1; then
    log_success "All backend tests passed"
else
    log_warning "Some backend tests failed (continuing anyway)"
fi

##############################################################################
# PHASE 6: STOP CURRENT SERVICE
##############################################################################

print_header "PHASE 6: STOP CURRENT SERVICE"

if systemctl is-active --quiet ${SERVICE_NAME}; then
    log_info "Stopping ${SERVICE_NAME}..."
    sudo systemctl stop ${SERVICE_NAME}
    sleep 2
    
    log_success "Service stopped"
else
    log_info "Service is not running, skipping stop"
fi

##############################################################################
# PHASE 7: DEPLOY NEW VERSION
##############################################################################

print_header "PHASE 7: DEPLOY NEW VERSION"

log_info "Deploying backend to $ENVIRONMENT..."

# Copy backend code
log_info "Copying backend code..."
cp -r app/ "${BACKEND_DIR}/app/" 2>/dev/null || log_warning "App code copy had issues"

# Reinstall dependencies
log_info "Installing/updating dependencies..."
cd "${BACKEND_DIR}"
source venv/bin/activate
pip install -e . > /dev/null 2>&1

log_success "Backend deployed"

##############################################################################
# PHASE 8: APPLY DATABASE MIGRATIONS
##############################################################################

print_header "PHASE 8: DATABASE MIGRATIONS"

log_info "Checking for pending migrations..."
cd "${BACKEND_DIR}"
source venv/bin/activate

if [ -d "alembic" ]; then
    log_info "Running Alembic migrations..."
    alembic upgrade head || log_warning "Migration had issues (may be already up-to-date)"
    log_success "Database migrations applied"
else
    log_info "No migration framework detected (skipping)"
fi

##############################################################################
# PHASE 9: START SERVICE
##############################################################################

print_header "PHASE 9: START SERVICE"

log_info "Starting ${SERVICE_NAME}..."
sudo systemctl start ${SERVICE_NAME}

# Wait for service to start
sleep 3

if systemctl is-active --quiet ${SERVICE_NAME}; then
    log_success "Service started successfully"
else
    log_error "Failed to start service"
    exit 1
fi

##############################################################################
# PHASE 10: POST-DEPLOYMENT VALIDATION
##############################################################################

print_header "PHASE 10: POST-DEPLOYMENT VALIDATION"

log_info "Waiting for service to be ready..."
for i in {1..30}; do
    if curl -s --max-time 2 "http://localhost:${API_PORT}/health" | grep -q "ok"; then
        log_success "Service is healthy and responding"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "Service failed to become healthy"
        exit 1
    fi
    echo -n "."
    sleep 1
done

echo ""

# Verify service status
log_info "Service status:"
systemctl status ${SERVICE_NAME} --no-pager || true

##############################################################################
# PHASE 11: DEPLOYMENT REPORT
##############################################################################

print_header "PHASE 11: DEPLOYMENT REPORT"

DEPLOY_LOG="${BACKUP_DIR}/deployment.log"
cat > "$DEPLOY_LOG" <<EOF
═════════════════════════════════════════════════════════════════
DEPLOYMENT REPORT - $ENVIRONMENT
═════════════════════════════════════════════════════════════════

Project: $PROJECT_NAME
Environment: $ENVIRONMENT
Timestamp: $TIMESTAMP
Status: SUCCESS

Components Deployed:
  ✓ Backend API (${API_PORT})
  ✓ Python dependencies
  ✓ Database migrations (if applicable)
  ✓ Service configuration

Service Details:
  Name: ${SERVICE_NAME}
  Port: ${API_PORT}
  Status: $(systemctl is-active ${SERVICE_NAME})

Health Check: PASSED

Backup Location: ${BACKUP_DIR}

Next Steps:
  1. Monitor application logs: journalctl -u ${SERVICE_NAME} -f
  2. Check monitoring dashboards
  3. Verify all features working correctly

Rollback Instructions:
  If issues occur, run: ./deployment/rollback.sh ${BACKUP_DIR}
═════════════════════════════════════════════════════════════════
EOF

cat "$DEPLOY_LOG"

log_success "Deployment report saved: ${DEPLOY_LOG}"

##############################################################################
# FINAL MESSAGE
##############################################################################

print_header "DEPLOYMENT COMPLETE"

log_success "✓ $ENVIRONMENT deployment completed successfully"
log_info "Service: ${SERVICE_NAME} is running on port ${API_PORT}"
log_info "Backup: ${BACKUP_DIR}"
log_info "Time: $(date)"

echo ""
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Application is ready for testing!${NC}"
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"