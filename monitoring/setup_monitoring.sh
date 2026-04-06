#!/bin/bash
##############################################################################
# LEXSUM Monitoring Stack Setup Script
# Purpose: Install and configure Prometheus, Grafana, and exporters
# Supports: Linux (Debian/Ubuntu, RHEL), macOS
# Author: DevOps Team
# Last Updated: 2024
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if command -v apt-get &> /dev/null; then
            DISTRO="debian"
        elif command -v yum &> /dev/null; then
            DISTRO="rhel"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    log_info "OS: $OS (Distro: $DISTRO)"
    
    if [ "$OS" == "linux" ]; then
        if [ "$DISTRO" == "debian" ]; then
            log_info "Updating package manager..."
            sudo apt-get update > /dev/null
            
            # Install required tools
            sudo apt-get install -y wget curl net-tools > /dev/null
            log_success "Linux prerequisites installed"
        elif [ "$DISTRO" == "rhel" ]; then
            log_info "Installing RHEL prerequisites..."
            sudo yum install -y wget curl net-tools > /dev/null
            log_success "RHEL prerequisites installed"
        fi
    elif [ "$OS" == "macos" ]; then
        log_info "Checking Homebrew..."
        if ! command -v brew &> /dev/null; then
            log_error "Homebrew not installed. Please install it first."
            exit 1
        fi
        log_success "Homebrew found"
    fi
}

##############################################################################
# NODE EXPORTER INSTALLATION
##############################################################################

install_node_exporter() {
    print_header "INSTALLING NODE EXPORTER"
    
    EXPORTER_VERSION="1.7.0"
    
    if command -v node_exporter &> /dev/null; then
        log_warning "Node Exporter already installed"
        return
    fi
    
    log_info "Downloading Node Exporter v${EXPORTER_VERSION}..."
    
    if [ "$OS" == "linux" ]; then
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            ARCH="amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            ARCH="arm64"
        fi
        
        cd /tmp
        wget -q https://github.com/prometheus/node_exporter/releases/download/v${EXPORTER_VERSION}/node_exporter-${EXPORTER_VERSION}.linux-${ARCH}.tar.gz
        tar xzf node_exporter-${EXPORTER_VERSION}.linux-${ARCH}.tar.gz
        sudo cp node_exporter-${EXPORTER_VERSION}.linux-${ARCH}/node_exporter /usr/local/bin/
        sudo chmod +x /usr/local/bin/node_exporter
        sudo useradd -rs /bin/false node_exporter 2>/dev/null || true
        
        log_success "Node Exporter installed"
        
        # Create systemd service
        log_info "Creating Node Exporter systemd service..."
        sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
    --collector.filesystem.mount-points-exclude=^/(dev|proc|sys)($|/) \
    --collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$

SyslogIdentifier=node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable node_exporter
        sudo systemctl start node_exporter
        log_success "Node Exporter systemd service configured"
        
    elif [ "$OS" == "macos" ]; then
        log_info "Installing Node Exporter via Homebrew..."
        brew install prometheus-node-exporter
        log_success "Node Exporter installed"
    fi
}

##############################################################################
# PROMETHEUS INSTALLATION
##############################################################################

install_prometheus() {
    print_header "INSTALLING PROMETHEUS"
    
    PROMETHEUS_VERSION="2.45.0"
    
    if [ -d "/opt/prometheus" ] || command -v prometheus &> /dev/null; then
        log_warning "Prometheus already installed"
        return
    fi
    
    log_info "Downloading Prometheus v${PROMETHEUS_VERSION}..."
    
    if [ "$OS" == "linux" ]; then
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            ARCH="amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            ARCH="arm64"
        fi
        
        cd /tmp
        wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz
        tar xzf prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz
        sudo mkdir -p /opt/prometheus
        sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/* /opt/prometheus/
        sudo useradd -rs /bin/false prometheus 2>/dev/null || true
        
        log_success "Prometheus binary installed"
        
        # Copy configuration
        log_info "Copying Prometheus configuration..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        sudo mkdir -p /etc/prometheus
        sudo cp "${SCRIPT_DIR}/monitoring/prometheus.yml" /etc/prometheus/
        sudo cp "${SCRIPT_DIR}/monitoring/alert_rules.yml" /etc/prometheus/ 2>/dev/null || log_warning "Alert rules not found"
        sudo cp "${SCRIPT_DIR}/monitoring/recording_rules.yml" /etc/prometheus/ 2>/dev/null || log_warning "Recording rules not found"
        sudo mkdir -p /var/lib/prometheus
        sudo chown -R prometheus:prometheus /opt/prometheus /etc/prometheus /var/lib/prometheus
        
        log_success "Prometheus configuration deployed"
        
        # Create systemd service
        log_info "Creating Prometheus systemd service..."
        sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/opt/prometheus/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --storage.tsdb.retention.time=30d \
    --web.listen-address=:9090 \
    --web.enable-lifecycle

SyslogIdentifier=prometheus
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable prometheus
        sudo systemctl start prometheus
        log_success "Prometheus systemd service configured"
        
    elif [ "$OS" == "macos" ]; then
        log_info "Installing Prometheus via Homebrew..."
        brew install prometheus
        log_success "Prometheus installed"
    fi
}

##############################################################################
# GRAFANA INSTALLATION
##############################################################################

install_grafana() {
    print_header "INSTALLING GRAFANA"
    
    if command -v grafana-server &> /dev/null; then
        log_warning "Grafana already installed"
        return
    fi
    
    if [ "$OS" == "linux" ]; then
        if [ "$DISTRO" == "debian" ]; then
            log_info "Installing Grafana repository..."
            sudo apt-get install -y software-properties-common 2>/dev/null
            sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" 2>/dev/null
            sudo apt-get update > /dev/null
            
            log_info "Installing Grafana..."
            sudo apt-get install -y grafana > /dev/null
            log_success "Grafana installed"
            
        elif [ "$DISTRO" == "rhel" ]; then
            log_info "Installing Grafana repository..."
            sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
            
            log_info "Installing Grafana..."
            sudo yum install -y grafana > /dev/null
            log_success "Grafana installed"
        fi
        
        sudo systemctl daemon-reload
        sudo systemctl enable grafana-server
        sudo systemctl start grafana-server
        log_success "Grafana systemd service configured"
        
    elif [ "$OS" == "macos" ]; then
        log_info "Installing Grafana via Homebrew..."
        brew install grafana
        log_success "Grafana installed"
    fi
}

##############################################################################
# ADDITIONAL EXPORTERS
##############################################################################

install_postgres_exporter() {
    print_header "INSTALLING POSTGRES EXPORTER"
    
    log_info "PostgreSQL exporter can be installed separately if needed"
    log_info "See: https://github.com/prometheus-community/postgres_exporter"
}

install_redis_exporter() {
    print_header "INSTALLING REDIS EXPORTER"
    
    log_info "Redis exporter can be installed separately if needed"
    log_info "See: https://github.com/oliver006/redis_exporter"
}

##############################################################################
# VERIFICATION
##############################################################################

verify_installation() {
    print_header "VERIFYING INSTALLATION"
    
    if command -v node_exporter &> /dev/null; then
        log_success "Node Exporter: $(node_exporter --version | head -1)"
    else
        log_warning "Node Exporter: Not in PATH"
    fi
    
    if command -v prometheus &> /dev/null; then
        log_success "Prometheus: $(prometheus --version)"
    elif [ -f "/opt/prometheus/prometheus" ]; then
        log_success "Prometheus: /opt/prometheus/prometheus"
    else
        log_warning "Prometheus: Not found"
    fi
    
    if command -v grafana-server &> /dev/null; then
        log_success "Grafana: Installed"
    else
        log_warning "Grafana: Not in PATH"
    fi
}

##############################################################################
# MAIN EXECUTION
##############################################################################

main() {
    print_header "LEXSUM MONITORING STACK SETUP"
    
    log_info "Starting monitoring stack installation..."
    
    detect_os
    check_prerequisites
    install_node_exporter
    install_prometheus
    install_grafana
    install_postgres_exporter
    install_redis_exporter
    verify_installation
    
    print_header "INSTALLATION COMPLETE"
    
    log_success "Monitoring stack installation complete!"
    echo ""
    echo "Access Points:"
    echo "  Prometheus:  http://localhost:9090"
    echo "  Grafana:     http://localhost:3000 (admin/admin)"
    echo "  Node Exporter: http://localhost:9100/metrics"
    echo ""
    echo "Next Steps:"
    echo "  1. Login to Grafana with admin/admin"
    echo "  2. Add Prometheus as a data source"
    echo "  3. Import dashboards from: https://grafana.com/grafana/dashboards"
    echo "  4. Configure alerts in Prometheus"
    echo ""
    echo "Logs:"
    echo "  Prometheus: journalctl -u prometheus -f"
    echo "  Grafana: journalctl -u grafana-server -f"
    echo "  Node Exporter: journalctl -u node_exporter -f"
    echo ""
    
}

# Run main
main
