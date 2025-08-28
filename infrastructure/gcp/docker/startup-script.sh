#!/bin/bash

# VM Startup Script for AppFlowy Deployment
# This script runs automatically when the VM starts

set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/startup-script.log
}

log "Starting VM initialization for AppFlowy deployment..."

# Wait for network to be ready
log "Waiting for network..."
sleep 10

# Update system packages
log "Updating system packages..."
apt-get update

# Install required packages
log "Installing prerequisites..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    net-tools \
    htop \
    vim \
    jq

# Add Docker's official GPG key
log "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
log "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
log "Installing Docker..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker to start on boot
log "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# Configure Docker daemon
log "Configuring Docker daemon..."
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF

# Restart Docker with new configuration
systemctl restart docker

# Create appflowy user (if not exists)
if ! id -u appflowy >/dev/null 2>&1; then
    log "Creating appflowy user..."
    useradd -m -s /bin/bash appflowy
fi

# Add appflowy user to docker group
log "Adding appflowy user to docker group..."
usermod -aG docker appflowy

# Create AppFlowy directory structure
log "Creating AppFlowy directory structure..."
mkdir -p /opt/appflowy/{config,data,backups,logs,ssl}
chown -R appflowy:appflowy /opt/appflowy

# Set up log rotation for AppFlowy
log "Setting up log rotation..."
cat > /etc/logrotate.d/appflowy << 'EOF'
/opt/appflowy/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 appflowy appflowy
    sharedscripts
    postrotate
        docker exec appflowy-cloud kill -USR1 1
    endscript
}
EOF

# Create a simple health check script
log "Creating health check script..."
cat > /usr/local/bin/appflowy-health << 'EOF'
#!/bin/bash
echo "AppFlowy Health Status:"
echo "----------------------"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Disk Usage:"
df -h /opt/appflowy
echo ""
echo "Memory Usage:"
free -h
EOF
chmod +x /usr/local/bin/appflowy-health

# Create a backup script
log "Creating backup script..."
cat > /usr/local/bin/appflowy-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/appflowy/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/appflowy_backup_${TIMESTAMP}.tar.gz"

echo "Starting AppFlowy backup..."

# Create backup directory if not exists
mkdir -p ${BACKUP_DIR}

# Backup Docker volumes
cd /opt/appflowy/config
docker compose exec -T postgres pg_dump -U appflowy appflowy > ${BACKUP_DIR}/db_${TIMESTAMP}.sql

# Compress backup
tar -czf ${BACKUP_FILE} -C ${BACKUP_DIR} db_${TIMESTAMP}.sql
rm ${BACKUP_DIR}/db_${TIMESTAMP}.sql

# Keep only last 7 backups
ls -t ${BACKUP_DIR}/appflowy_backup_*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup completed: ${BACKUP_FILE}"
EOF
chmod +x /usr/local/bin/appflowy-backup

# Set up daily backup cron job
log "Setting up backup cron job..."
echo "0 2 * * * /usr/local/bin/appflowy-backup > /opt/appflowy/logs/backup.log 2>&1" | crontab -u appflowy -

# Configure firewall (ufw)
log "Configuring local firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8000/tcp
ufw allow 8001/tcp
ufw allow 9999/tcp
ufw reload

# Install fail2ban for basic security
log "Installing fail2ban..."
apt-get install -y fail2ban

# Configure fail2ban for SSH
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
EOF

systemctl restart fail2ban

# Set up swap file (useful for small VMs)
log "Setting up swap file..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

# Install Docker Compose standalone (for compatibility)
log "Installing Docker Compose standalone..."
DOCKER_COMPOSE_VERSION="2.24.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create systemd service for AppFlowy
log "Creating AppFlowy systemd service..."
cat > /etc/systemd/system/appflowy.service << 'EOF'
[Unit]
Description=AppFlowy Docker Compose Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/opt/appflowy/config
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=appflowy
Group=appflowy

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service (but don't start yet)
systemctl daemon-reload
systemctl enable appflowy

# Set kernel parameters for better performance
log "Optimizing kernel parameters..."
cat >> /etc/sysctl.conf << 'EOF'

# AppFlowy optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
fs.file-max = 100000
EOF
sysctl -p

# Create a welcome message
cat > /etc/motd << 'EOF'
=====================================
    AppFlowy Workspace Server
=====================================
  
  Useful commands:
  - appflowy-health    : Check service health
  - appflowy-backup    : Create backup
  
  Docker commands:
  - cd /opt/appflowy/config
  - docker compose ps  : View containers
  - docker compose logs: View logs
  
=====================================
EOF

# Log completion
log "Startup script completed successfully"
echo "$(date)" > /var/log/startup-complete.log

# Final message
log "VM initialization complete. AppFlowy is ready for deployment."
log "Run the deployment script to start AppFlowy services."