# Operations Guide

## Local Development Setup

### Prerequisites
- Python 3.10+
- Flutter 3.10+
- PostgreSQL
- Redis
- Android SDK (for mobile testing)

### Quick Start
```bash
# Backend setup
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -e .
uvicorn app.main:app --reload

# Frontend setup (new terminal)
flutter pub get
flutter run -d <device>
```

### Manual Service Setup

#### Install PostgreSQL and Redis
```bash
# macOS with Homebrew
brew install postgresql redis
brew services start postgresql
brew services start redis

# Ubuntu/Debian
sudo apt install postgresql redis-server
sudo systemctl start postgresql
sudo systemctl start redis-server
```

#### Database Setup
```bash
# Create database
createdb classroom_dev

# Run migrations
cd backend
source venv/bin/activate
alembic upgrade head
```

## Deployment

### Server Setup
```bash
# Install dependencies
sudo apt update
sudo apt install python3 python3-venv postgresql redis-server nginx

# Create application user
sudo useradd -m -s /bin/bash classroom
sudo usermod -aG www-data classroom

# Setup application directory
sudo mkdir -p /opt/classroom-app
sudo chown classroom:www-data /opt/classroom-app
```

### Application Deployment
```bash
# Copy application files
sudo cp -r . /opt/classroom-app/
cd /opt/classroom-app

# Setup Python environment
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -e ./backend

# Setup systemd services
sudo cp deployment/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable classroom-backend classroom-worker
sudo systemctl start classroom-backend classroom-worker
```

### Nginx Configuration
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /metrics {
        proxy_pass http://127.0.0.1:8000;
        allow 10.0.0.0/8;  # Restrict to internal network
        deny all;
    }
}
```

## Monitoring

### Setup Monitoring
```bash
# Run monitoring setup script
sudo ./monitoring/setup_monitoring.sh

# Access dashboards
# Grafana: http://your-server:3000 (admin/admin)
# Prometheus: http://your-server:9090
```

### Key Metrics to Monitor
- API Response Time (< 500ms)
- Error Rate (< 1%)
- Database Connections
- Memory Usage
- CPU Usage
- Background Job Queue Length

## Troubleshooting

### Common Issues

#### API Returns 500
```bash
# Check logs
sudo journalctl -u classroom-backend -f

# Test database connection
cd /opt/classroom-app/backend
source venv/bin/activate
python test_db.py

# Check environment variables
cat .env
```

#### Services Won't Start
```bash
# Check service status
sudo systemctl status classroom-backend

# View logs
sudo journalctl -u classroom-backend -n 50
```

#### Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
psql -U postgres -d classroom_prod -c "SELECT 1"
```

### Logs Location
- Backend: `sudo journalctl -u classroom-backend`
- Worker: `sudo journalctl -u classroom-worker`
- Nginx: `/var/log/nginx/error.log`
- Application: `/opt/classroom-app/backend/uvicorn.log`

## Backup & Recovery

### Database Backup
```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -U postgres classroom_prod > /opt/backups/classroom_$DATE.sql
find /opt/backups -name "classroom_*.sql" -mtime +7 -delete
```

### Application Backup
```bash
# Backup application files
tar -czf /opt/backups/app_$DATE.tar.gz -C /opt classroom-app
```

### Recovery
```bash
# Stop services
sudo systemctl stop classroom-backend classroom-worker

# Restore database
psql -U postgres classroom_prod < /opt/backups/classroom_20231201.sql

# Restore application
cd /opt
rm -rf classroom-app
tar -xzf /opt/backups/app_20231201.tar.gz

# Restart services
sudo systemctl start classroom-backend classroom-worker
```

## Security

### SSL/TLS Setup
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com
```

### Firewall Configuration
```bash
# UFW rules
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

### Secrets Management
- Store secrets in `.env` files
- Use strong passwords
- Rotate keys regularly
- Restrict file permissions: `chmod 600 .env`

## Performance

### Optimization Tips
- Use database indexes on frequently queried fields
- Enable PostgreSQL connection pooling
- Cache expensive operations with Redis
- Optimize ML model loading
- Use gzip compression in Nginx

### Scaling
- Load balancer for multiple app servers
- Database read replicas
- Redis cluster for caching
- Background job workers scaling

## Jenkins CI/CD Setup

### Install Jenkins
```bash
# Add Jenkins repository
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
```

### Configure Jenkins Pipeline
1. Create new pipeline job
2. Use the `Jenkinsfile` in repository root
3. Configure SSH credentials for deployment servers
4. Set up build triggers (GitHub webhooks)

### Deployment Servers
- **Staging**: `staging-server` (develop branch)
- **Production**: `prod-server` (main branch)

Ensure SSH keys are configured for passwordless deployment.