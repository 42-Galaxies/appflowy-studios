# 🌌 42 Galaxies Workspace - Interactive Setup Guide

## 🚀 Quick Start

Simply run the interactive guide:

```bash
cd infrastructure/gcp
./guide.sh
```

## ✨ Features

The interactive guide provides:

### 📊 Visual Progress Tracking
- Step-by-step walkthrough with progress indicators
- Automatic progress saving (resume where you left off)
- Clear visual feedback with colors and icons

### 🎯 Guided Configuration
- Interactive prompts for all settings
- Default values provided where applicable
- Validation at each step
- Option to review and modify existing configuration

### 🔄 Smart Workflow
- **Step 1**: Prerequisites check (gcloud CLI, authentication)
- **Step 2**: Environment configuration wizard
- **Step 3**: Project creation with verification
- **Step 4**: Billing account linking
- **Step 5**: API enablement (required + optional)
- **Step 6**: Budget alerts setup
- **Step 7**: Complete verification
- **Step 8**: Summary and next steps

### 💡 User-Friendly Features
- **Beautiful UI**: Color-coded output with Unicode boxes and icons
- **Progress Persistence**: Automatically saves progress between runs
- **Error Recovery**: Continue from where errors occurred
- **Confirmation Prompts**: Review actions before execution
- **Help & Guidance**: Clear instructions at each step

## 📸 What It Looks Like

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  ★ 42 GALAXIES WORKSPACE ★                              │
│  GCP Infrastructure Setup Guide                         │
│                                                          │
└──────────────────────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Step 3/8: Create GCP Project
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • Creating project: galaxies-workspace-42
  • Display name: 42 Galaxies Workspace

  ? Create this project? (y/n)
  > 

Progress: [████████████████────────────────────────] 40% (3/8)
```

## 🔧 Manual Setup Alternative

If you prefer manual control, you can still use the original setup script:

```bash
# Run all steps at once
./setup.sh --full

# Or run interactively
./setup.sh

# Or run individual scripts
./scripts/01-create-project.sh
./scripts/02-link-billing.sh
./scripts/03-enable-apis.sh
./scripts/04-setup-billing-alerts.sh
```

## 📝 Configuration

The guide will create `config/env.sh` with your settings:

- **Project ID**: Your unique GCP project identifier
- **Billing Account**: Your billing account ID
- **Email Alerts**: Where to send budget notifications
- **Budget Amount**: Monthly spending limit
- **Region/Zone**: Default deployment locations

## 🔒 Security

- Configuration file (`env.sh`) is created with restricted permissions (600)
- Sensitive data never hardcoded in scripts
- `.gitignore` prevents accidental commits of secrets
- Guide prompts for confirmation before any changes

## 🆘 Troubleshooting

### Guide won't start
```bash
# Make sure it's executable
chmod +x guide.sh

# Check you're in the right directory
pwd  # Should show .../infrastructure/gcp
```

### Authentication issues
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login
```

### Resume previous session
The guide automatically saves progress. Just run it again:
```bash
./guide.sh
```

### Clear saved progress
```bash
rm .setup_progress
```

## 📚 What Gets Created

After completing the guide:

1. **GCP Project**: `galaxies-workspace-42`
2. **Enabled APIs**:
   - Compute Engine
   - Cloud Build
   - Secret Manager
   - Artifact Registry
   - (Optional) Monitoring, Logging, IAM, etc.
3. **Billing Configuration**: Linked account with budget alerts
4. **Alert System**: Email notifications at spending thresholds

## 🎉 After Setup

The guide will provide you with:
- Direct Console links
- Useful gcloud commands
- Next steps for deployment
- Verification commands

---

**Tip**: Run `./guide.sh` anytime to check your setup status or make changes!