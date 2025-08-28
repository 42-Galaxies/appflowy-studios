# 🚀 AppFlowy VM Deployment Quick Start Guide

This guide will help you deploy AppFlowy on a GCP VM with Docker in under 10 minutes.

## ✅ Current Implementation Status

### What's Complete
- ✅ **All deployment scripts exist** (05-08 in `/infrastructure/gcp/scripts/`)
- ✅ **Docker Compose configuration** is dynamically generated with:
  - AppFlowy-Cloud container
  - PostgreSQL database
  - GoTrue authentication (with Google OAuth support)
  - Redis cache
  - Nginx reverse proxy
- ✅ **Environment template** updated with all required variables
- ✅ **Fork management script** for customizing AppFlowy
- ✅ **Comprehensive test suite** for validation
- ✅ **Setup menu** fully integrated with options 1-16

### What You Need to Configure
1. **Generate secure passwords** for PostgreSQL and JWT
2. **Set up Google OAuth** (optional but recommended for 42galaxies.studio)
3. **Configure environment variables** in `config/env.sh`

## 📋 Prerequisites

1. **GCP Account** with billing enabled
2. **gcloud CLI** installed and authenticated
3. **Domain** (optional, for production use)

## 🔧 Step-by-Step Deployment

### Step 1: Configure Environment

```bash
cd infrastructure/gcp/config
cp env.sh.template env.sh

# Generate secure passwords
openssl rand -base64 32  # Copy for POSTGRES_PASSWORD
openssl rand -base64 32  # Copy for GOTRUE_JWT_SECRET

# Edit env.sh
nano env.sh
```

**Essential variables to set:**
```bash
# GCP Project
PROJECT_ID="galaxies-workspace-42"
BILLING_ACCOUNT_ID="YOUR-BILLING-ID"

# VM Configuration
VM_NAME="appflowy-workspace"
VM_ZONE="us-central1-a"
VM_MACHINE_TYPE="e2-medium"  # ~$25/month

# Security (IMPORTANT!)
POSTGRES_PASSWORD="<generated-password-here>"
GOTRUE_JWT_SECRET="<generated-secret-here>"

# Optional but recommended
GOOGLE_CLIENT_ID=""     # From Google Cloud Console
GOOGLE_CLIENT_SECRET=""  # From Google Cloud Console
SSH_SOURCE_RANGES="YOUR_IP/32"  # Restrict SSH access
```

### Step 2: Run Initial GCP Setup

```bash
cd infrastructure/gcp

# Make scripts executable
chmod +x setup.sh scripts/*.sh

# Run GCP project setup (creates project, enables APIs, etc.)
./setup.sh --full
```

This will:
- Create GCP project
- Link billing account
- Enable required APIs
- Set up budget alerts

### Step 3: Deploy AppFlowy VM

```bash
# Run interactive menu
./setup.sh

# Choose option 10: Full VM deployment
# This runs scripts 05-08 automatically:
# - Creates VM with static IP
# - Configures firewall rules
# - Installs Docker
# - Deploys AppFlowy stack
```

Or run individually:
```bash
./scripts/05-create-vm.sh        # Create VM
./scripts/06-configure-firewall.sh  # Set up firewall
./scripts/07-install-docker.sh      # Install Docker
./scripts/08-deploy-appflowy.sh     # Deploy AppFlowy
```

### Step 4: Verify Deployment

```bash
# Run comprehensive tests
./setup.sh
# Choose option 15: Test deployment

# Or quick verify
./setup.sh --verify
```

### Step 5: Access AppFlowy

After successful deployment:

```bash
# Get VM IP
gcloud compute instances describe appflowy-workspace \
  --zone=us-central1-a \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
```

Access URLs:
- **Main App**: `http://VM_IP`
- **API**: `http://VM_IP:8000`
- **Auth**: `http://VM_IP:9999`

## 🔐 Setting Up Google OAuth (for 42galaxies.studio)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to APIs & Services → Credentials
3. Create OAuth 2.0 Client ID (Web application)
4. Add authorized redirect URIs:
   - `http://VM_IP/auth/callback`
   - `https://workspace.42galaxies.studio/auth/callback` (for production)
5. Copy Client ID and Secret to `config/env.sh`
6. Redeploy: `./scripts/08-deploy-appflowy.sh`

## 🎨 Customizing AppFlowy (Fork Management)

To create a custom version with 42 Galaxies branding:

```bash
./setup.sh
# Choose option 16: Fork management

# Then select:
# 6) Full setup - Creates fork, applies customizations, builds image
```

This will:
- Fork AppFlowy-Cloud repository
- Apply 42 Galaxies customizations
- Build custom Docker image
- Update deployment to use custom image

## 🛠️ Management Commands

```bash
# Stop services
./setup.sh  # Choose 12

# Start services
./setup.sh  # Choose 13

# View logs
./setup.sh  # Choose 14

# SSH to VM
gcloud compute ssh appflowy-workspace --zone=us-central1-a

# On VM - Docker commands
cd /opt/appflowy/config
docker compose ps           # View containers
docker compose logs -f       # View logs
docker compose down          # Stop all
docker compose up -d         # Start all
```

## 🔍 Troubleshooting

### Common Issues and Fixes

1. **"Project not found"**
   - Ensure PROJECT_ID is globally unique
   - Run: `./scripts/01-create-project.sh`

2. **"Billing not enabled"**
   - Link billing account: `./scripts/02-link-billing.sh`

3. **"VM not accessible"**
   - Check firewall: `./scripts/06-configure-firewall.sh`
   - Verify SSH access: `gcloud compute ssh VM_NAME --zone=ZONE`

4. **"Services not responding"**
   - SSH to VM and check Docker:
     ```bash
     cd /opt/appflowy/config
     docker compose ps
     docker compose logs appflowy-cloud
     ```

5. **"Authentication not working"**
   - Verify POSTGRES_PASSWORD and GOTRUE_JWT_SECRET are set
   - Check Google OAuth credentials if using Google sign-in

### Test Individual Components

```bash
# Test script available
./scripts/10-test-deployment.sh

# This runs comprehensive tests:
# - GCP project configuration
# - VM instance status
# - Firewall rules
# - Docker installation
# - Container health
# - Service endpoints
# - Configuration validation
```

## 📊 Cost Estimate

- **VM (e2-medium)**: ~$25/month
- **Static IP**: ~$7/month if not attached
- **Storage**: ~$4/month for 20GB
- **Total**: ~$30-35/month

💡 **Tip**: Use `e2-micro` for testing (free tier eligible)

## 🔄 Next Steps

1. **Set up HTTPS** with Let's Encrypt
2. **Configure custom domain** (workspace.42galaxies.studio)
3. **Enable automated backups**
4. **Set up monitoring** with Cloud Monitoring
5. **Configure CI/CD** for custom builds

## 📚 Additional Resources

- [Full Documentation](./README.md)
- [Environment Variables Guide](./config/env.sh.template)
- [Fork Management](./scripts/09-fork-appflowy.sh)
- [Test Suite](./scripts/10-test-deployment.sh)

## 🆘 Getting Help

If you encounter issues:
1. Run the test suite: `./scripts/10-test-deployment.sh`
2. Check logs: `./setup.sh` → Option 14
3. Review error messages in script output
4. Check VM logs: `gcloud compute ssh VM_NAME --command="sudo journalctl -xe"`

---

**Ready to deploy?** Start with Step 1 above! The entire process takes about 10 minutes.