# 🚀 AppFlowy Auto-Setup Guide

Deploy AppFlowy in 5 minutes using auto-configuration!

## Prerequisites

✅ You need:
- gcloud CLI installed
- A Google Cloud account
- Billing enabled on your account

## Step 1: Login to Google Cloud

```bash
# If not already logged in
gcloud auth login
gcloud auth application-default login
```

## Step 2: Run Auto-Setup

```bash
cd infrastructure/gcp

# Make scripts executable
chmod +x setup.sh scripts/*.sh

# Run setup
./setup.sh
```

## Step 3: Choose Option 1 (Auto-Configure)

When the menu appears, choose option `1`:

```
=== Quick Start ===
  1) Auto-configure (detect settings from gcloud)  <-- Choose this
```

The auto-configuration will:
- ✅ Detect your current GCP project (or help create one)
- ✅ Find your billing account automatically
- ✅ Get your email for notifications
- ✅ Detect your default region/zone
- ✅ Find your external IP for SSH security
- ✅ Generate secure passwords automatically
- ✅ Set up VM configuration
- ✅ Configure domain/OAuth (optional)

## Step 4: Deploy AppFlowy

After configuration completes, the menu will appear again.

Choose option `11` for full deployment:

```
=== VM & AppFlowy Deployment ===
 11) Full VM deployment (steps 7-10)  <-- Choose this
```

This will:
1. Create a VM with static IP
2. Configure firewall rules
3. Install Docker
4. Deploy AppFlowy with PostgreSQL, GoTrue, Redis, and Nginx

## Step 5: Access AppFlowy

After deployment (~5-10 minutes), you'll see:

```
Access Information:
  Main URL: http://YOUR_VM_IP
  API: http://YOUR_VM_IP:8000
  Auth: http://YOUR_VM_IP:9999
```

## What Gets Configured Automatically

| Setting | Auto-Detected From |
|---------|-------------------|
| Project ID | Current gcloud project or creates new |
| Project Name | GCP project metadata |
| Billing Account | Active billing accounts |
| User Email | Authenticated gcloud user |
| Default Zone | gcloud config or prompts |
| Default Region | Derived from zone |
| External IP | Your current IP (for SSH) |
| PostgreSQL Password | Generated (32 chars) |
| JWT Secret | Generated (32 chars) |
| VM Name | Prompted (default: appflowy-workspace) |
| Machine Type | Menu selection (default: e2-medium) |

## Quick Commands

```bash
# Start from scratch (if no env.sh exists)
./setup.sh
# Choose 1 (auto-configure), then 11 (deploy)

# If env.sh exists but want to reconfigure
./scripts/00-auto-configure.sh

# Test everything is working
./scripts/10-test-deployment.sh

# View logs
./setup.sh
# Choose 15 (view logs)

# SSH to VM
gcloud compute ssh appflowy-workspace --zone=us-central1-a
```

## Troubleshooting

### "No billing account found"
- Set up billing at: https://console.cloud.google.com/billing
- Then run auto-configure again

### "Project not found"
- The script will offer to create a new project
- Or select from your existing projects

### "Cannot detect external IP"
- The script will default to open SSH (0.0.0.0/0)
- You can restrict it later in config/env.sh

### "Services not responding"
- Run test suite: `./scripts/10-test-deployment.sh`
- Check Docker: `gcloud compute ssh VM_NAME --command="docker ps"`

## Security Notes

🔐 **Important**: 
- Passwords are auto-generated and saved in `config/env.sh`
- A backup is also saved with timestamp in `config/.passwords.TIMESTAMP`
- Never commit these files to git
- Keep them secure!

## Total Time

- Auto-configuration: ~1 minute
- GCP setup: ~2 minutes  
- VM deployment: ~5 minutes
- **Total: ~8 minutes** to fully deployed AppFlowy!

## Next Steps

After deployment:
1. Set up a domain name (optional)
2. Configure Google OAuth for 42galaxies.studio
3. Enable HTTPS with Let's Encrypt
4. Set up automated backups

---

**Ready?** Just run `./setup.sh` and choose option 1!