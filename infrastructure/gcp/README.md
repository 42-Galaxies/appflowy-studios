# 42 Galaxies Workspace GCP Infrastructure Setup

This directory contains automated scripts for setting up and managing the Google Cloud Platform (GCP) infrastructure for 42 Galaxies Workspace.

## 📁 Directory Structure

```
infrastructure/gcp/
├── setup.sh             # Main orchestration script
├── config/              
│   ├── env.sh           # Environment configuration (create from template)
│   └── env.sh.template  # Configuration template
├── scripts/             
│   ├── 01-create-project.sh      # GCP project creation
│   ├── 02-link-billing.sh        # Billing account linking
│   ├── 03-enable-apis.sh         # API enablement
│   ├── 04-setup-billing-alerts.sh # Billing alerts configuration
│   ├── 05-create-vm.sh           # Create Compute Engine VM
│   ├── 06-configure-firewall.sh  # Configure firewall rules
│   ├── 07-install-docker.sh      # Install Docker on VM
│   └── 08-deploy-appflowy.sh     # Deploy AppFlowy stack
├── docker/              
│   ├── docker-compose.yml        # Docker Compose configuration
│   ├── nginx.conf                # Nginx reverse proxy config
│   ├── startup-script.sh         # VM startup script
│   └── .env                      # Docker environment variables
└── monitoring/          # Monitoring configurations (future use)
```

## 🚀 Quick Start

### Prerequisites

1. **Google Cloud SDK**: Install the gcloud CLI
   ```bash
   # For Linux/macOS
   curl https://sdk.cloud.google.com | bash
   
   # For specific distributions, see:
   # https://cloud.google.com/sdk/docs/install
   ```

2. **Authentication**: Login to your Google Cloud account
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

3. **Billing Account**: You need an active GCP billing account. Find your billing account ID:
   ```bash
   gcloud billing accounts list
   ```

### Initial Setup

1. **Configure Environment Variables**
   ```bash
   cd infrastructure/gcp/config
   cp env.sh.template env.sh
   
   # Edit env.sh with your values
   nano env.sh
   ```
   
   **Important:** Generate secure passwords for PostgreSQL and JWT secret:
   ```bash
   # Generate secure passwords
   openssl rand -base64 32  # For POSTGRES_PASSWORD
   openssl rand -base64 32  # For GOTRUE_JWT_SECRET
   ```

2. **Run the GCP Project Setup**
   ```bash
   cd infrastructure/gcp
   
   # Make scripts executable
   chmod +x setup.sh scripts/*.sh
   
   # Run full GCP setup (project, billing, APIs)
   ./setup.sh --full
   ```

3. **Deploy AppFlowy on VM**
   ```bash
   # Run VM deployment (creates VM, installs Docker, deploys AppFlowy)
   ./setup.sh
   # Select option 10 for full VM deployment
   
   # Or run directly:
   ./scripts/05-create-vm.sh
   ./scripts/06-configure-firewall.sh
   ./scripts/07-install-docker.sh
   ./scripts/08-deploy-appflowy.sh
   ```

## 📋 Configuration

### Required Environment Variables

Edit `config/env.sh` with your values:

```bash
# Project Configuration
PROJECT_ID="galaxies-workspace-42"          # Must be globally unique
PROJECT_NAME="42 Galaxies Workspace"        # Display name

# Billing Configuration
BILLING_ACCOUNT_ID="XXXXXX-XXXXXX-XXXXXX"  # Your billing account ID

# Alert Configuration
ALERT_EMAIL="your-email@example.com"        # Email for billing alerts
BUDGET_AMOUNT="100"                         # Monthly budget in USD
THRESHOLD_PERCENT="50"                      # Alert threshold percentage

# VM Configuration
VM_NAME="appflowy-workspace"              # VM instance name
VM_ZONE="us-central1-a"                   # VM zone
VM_MACHINE_TYPE="e2-medium"               # VM size (e2-medium recommended)

# AppFlowy Configuration
POSTGRES_PASSWORD="<secure-password>"     # Database password
GOTRUE_JWT_SECRET="<secure-secret>"       # JWT secret for auth
APPFLOWY_PORT="8000"                      # AppFlowy API port
SITE_URL=""                                # Your domain (optional)

# Google OAuth (optional)
GOOGLE_CLIENT_ID=""                       # From Google Cloud Console
GOOGLE_CLIENT_SECRET=""                   # From Google Cloud Console

# Security
SSH_SOURCE_RANGES="YOUR_IP/32"            # Restrict SSH access

# Optional Settings
ORGANIZATION_ID=""                          # If using organization
FOLDER_ID=""                               # If using folders
ENABLE_OPTIONAL_APIS="true"               # Enable additional useful APIs
ENABLE_MONITORING_ALERTS="true"           # Enable Cloud Monitoring alerts
VERBOSE="true"                             # Show detailed output
```

## 🔧 Usage

### Full Setup (Recommended for First Time)

Runs all setup steps in sequence:
```bash
./setup.sh --full
```

This will:
1. Create the GCP project
2. Link billing account
3. Enable required APIs
4. Setup billing alerts

### Interactive Mode

Choose which steps to run:
```bash
./setup.sh
```

**Initial Setup Options:**
- `1` - Full setup (all GCP steps)
- `2` - Create GCP project only
- `3` - Link billing account only
- `4` - Enable APIs only
- `5` - Setup billing alerts only

**VM & AppFlowy Deployment:**
- `6` - Create VM instance
- `7` - Configure firewall rules
- `8` - Install Docker on VM
- `9` - Deploy AppFlowy stack
- `10` - Full VM deployment (steps 6-9)

**Management:**
- `11` - Verify all configuration
- `12` - Stop AppFlowy services
- `13` - Start AppFlowy services
- `14` - View AppFlowy logs
- `0` - Exit

### Individual Scripts

Run specific setup steps:

**GCP Setup:**
```bash
# Create project
./scripts/01-create-project.sh

# Link billing
./scripts/02-link-billing.sh

# Enable APIs
./scripts/03-enable-apis.sh

# Setup alerts
./scripts/04-setup-billing-alerts.sh
```

**VM & AppFlowy Deployment:**
```bash
# Create VM instance
./scripts/05-create-vm.sh

# Configure firewall rules
./scripts/06-configure-firewall.sh

# Install Docker on VM
./scripts/07-install-docker.sh

# Deploy AppFlowy stack
./scripts/08-deploy-appflowy.sh
```

### Verification

Check your setup status:
```bash
./setup.sh --verify
```

## 🚀 AppFlowy Deployment

### Access AppFlowy

After deployment, access your AppFlowy instance:

```bash
# Get VM external IP
gcloud compute instances describe appflowy-workspace \
  --zone=us-central1-a \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
```

Access URLs:
- **Main Application**: `http://VM_IP`
- **AppFlowy API**: `http://VM_IP:8000`
- **Auth Service**: `http://VM_IP:9999`

### Managing AppFlowy

```bash
# SSH to VM
gcloud compute ssh appflowy-workspace --zone=us-central1-a

# View container status
cd /opt/appflowy/config
docker compose ps

# View logs
docker compose logs -f

# Stop services
docker compose down

# Start services
docker compose up -d

# Backup database
docker compose exec postgres pg_dump -U appflowy appflowy > backup.sql
```

## 🔍 What Gets Created

### 1. GCP Project
- Project ID: `galaxies-workspace-42`
- Linked to your billing account
- Configured for immediate use

### 2. Enabled APIs
**Required APIs:**
- `compute.googleapis.com` - Compute Engine
- `cloudbuild.googleapis.com` - Cloud Build
- `secretmanager.googleapis.com` - Secret Manager
- `artifactregistry.googleapis.com` - Artifact Registry

**Optional APIs (if enabled):**
- `cloudresourcemanager.googleapis.com` - Resource Manager
- `serviceusage.googleapis.com` - Service Usage
- `iam.googleapis.com` - Identity & Access Management
- `monitoring.googleapis.com` - Cloud Monitoring
- `logging.googleapis.com` - Cloud Logging
- `storage.googleapis.com` - Cloud Storage
- `pubsub.googleapis.com` - Pub/Sub

### 3. Billing Alerts
- Budget alerts at: 50%, 75%, 90%, 100%, 120% of threshold
- Email notifications to configured address
- Pub/Sub topic for programmatic integration

### 4. Compute Engine VM
- Instance type: e2-medium (4GB RAM, 2 vCPU)
- Ubuntu 22.04 LTS
- Docker and Docker Compose installed
- Static IP address reserved
- Firewall rules for HTTP/HTTPS/SSH

### 5. AppFlowy Stack (Docker Containers)
- **AppFlowy Cloud**: Main application server
- **PostgreSQL**: Database for AppFlowy data
- **GoTrue**: Authentication service (Google OAuth support)
- **Redis**: Cache and session storage
- **Nginx**: Reverse proxy for routing

## 🔄 Idempotency

All scripts are idempotent - safe to run multiple times:
- Existing resources are detected and preserved
- Scripts continue from where they left off
- No duplicate resources are created
- Configuration updates are handled gracefully

## 🛡️ Security Best Practices

1. **Never commit `env.sh`** - It contains sensitive configuration
2. **Use environment variables** for sensitive data
3. **Enable least privilege** - Grant minimal required permissions
4. **Regular audits** - Review billing and access logs
5. **Use Secret Manager** - For storing application secrets

## 🧪 Testing & Verification

### Verify Project Creation
```bash
gcloud projects describe galaxies-workspace-42
```

### Check Billing Status
```bash
gcloud billing projects describe galaxies-workspace-42
```

### List Enabled APIs
```bash
gcloud services list --enabled --project=galaxies-workspace-42
```

### View Budget Alerts
```bash
gcloud billing budgets list --billing-account=YOUR_BILLING_ACCOUNT_ID
```

## 🔧 Troubleshooting

### Common Issues

1. **"Project ID already exists"**
   - Choose a different, globally unique PROJECT_ID
   - Or use the existing project

2. **"Billing account not found"**
   - Verify BILLING_ACCOUNT_ID is correct
   - Ensure you have access to the billing account
   - Run: `gcloud billing accounts list`

3. **"Permission denied"**
   - Ensure you have necessary IAM roles
   - Required roles: Project Creator, Billing Account User
   - Contact your organization admin if needed

4. **"API not enabled"**
   - The script will attempt to enable required APIs
   - If it fails, manually enable: `gcloud services enable API_NAME`

### Getting Help

- Review script output for specific error messages
- Check GCP Console for visual confirmation
- Consult GCP documentation for specific services

## 🔄 Recreating Setup

To completely recreate the setup on a new machine:

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd 42-galaxies-workspace/infrastructure/gcp
   ```

2. **Install prerequisites**
   ```bash
   # Install gcloud SDK
   curl https://sdk.cloud.google.com | bash
   
   # Authenticate
   gcloud auth login
   ```

3. **Configure environment**
   ```bash
   cp config/env.sh.template config/env.sh
   # Edit config/env.sh with your values
   ```

4. **Run setup**
   ```bash
   chmod +x setup.sh scripts/*.sh
   ./setup.sh --full
   ```

## 📊 Monitoring & Maintenance

### Check Costs
```bash
# View current month costs
gcloud billing accounts get-iam-policy BILLING_ACCOUNT_ID

# Or visit
# https://console.cloud.google.com/billing
```

### Update Budget
```bash
# Edit config/env.sh to update BUDGET_AMOUNT
# Then run:
./scripts/04-setup-billing-alerts.sh
```

### Add New APIs
```bash
# Edit scripts/03-enable-apis.sh to add APIs to REQUIRED_APIS array
# Then run:
./scripts/03-enable-apis.sh
```

## 📝 Notes

- All scripts include comprehensive error handling
- Detailed logging for troubleshooting
- Automatic rollback on critical failures
- Progress saved between runs
- Safe to interrupt and resume

## 🚨 Important Reminders

1. **Billing**: You will be charged for GCP resources created
2. **Cleanup**: Delete unused resources to avoid charges
3. **Security**: Regularly review IAM permissions and API access
4. **Monitoring**: Set up appropriate alerts for your use case

---

For issues or questions, consult the script output or GCP documentation.