# 🌌 42 Galaxies Workspace

A self-hosted AppFlowy platform with Google Workspace integration, providing collaborative document editing for the 42galaxies.studio team.

## 🚀 Project Overview

**42 Galaxies Workspace** (formerly AppFlowy Studios) is a comprehensive platform that combines:
- Self-hosted AppFlowy for document collaboration
- Google Workspace authentication
- CLI tool for local file synchronization
- Mobile client support
- GCP-based infrastructure

## 📊 Project Progress

### Overall Completion: █░░░░░░░░░ 12.5% (1/8 tasks)

### Milestone 1: GCP Foundation & User Authentication
**Status:** 🟡 In Progress (20% Complete)

| Task | Description | Status |
|------|-------------|--------|
| T1.1 | Set up GCP project and billing alerts | ✅ **Complete** |
| T1.2 | Write Terraform scripts for GKE, Cloud SQL, and Cloud Storage | ⏳ To Do |
| T1.3 | Create the Authentication Service microservice | ⏳ To Do |
| T1.4 | Integrate Authentication Service with Google Workspace OAuth | ⏳ To Do |
| T1.5 | Set up a basic CI/CD pipeline for the Authentication Service | ⏳ To Do |

### Upcoming Milestones
- **M2:** AppFlowy Cloud Deployment (0% - Not Started)
- **M3:** Local Development with CLI Sync (0% - Not Started)
- **M4:** Mobile Client Integration (0% - Not Started)

## 🏗️ Infrastructure

### GCP Project Details
- **Project ID:** `galaxies-workspace-42`
- **Region:** us-central1
- **Budget:** $10 USD/month with alerts at 50%, 90%, 100%

### Enabled Services
- ✅ Compute Engine API
- ✅ Cloud Build API
- ✅ Secret Manager API
- ✅ Artifact Registry API
- ✅ Billing Budgets API

## 🛠️ Quick Setup

### Prerequisites
- Google Cloud SDK (`gcloud` CLI)
- Active GCP billing account
- Google Workspace domain (42galaxies.studio)

### Infrastructure Setup
```bash
# Navigate to infrastructure directory
cd infrastructure/gcp

# Run interactive setup guide
./guide.sh

# Or run automated setup
./setup.sh --full
```

### Verify Setup
```bash
# Check project status
gcloud projects describe galaxies-workspace-42

# Verify all components
./setup.sh --verify
```

## 📁 Project Structure

```
42-galaxies-workspace/
├── README.md                       # This file
├── .gitignore
├── docs/                          # Documentation
│   ├── roadmap/                  # Project roadmap and milestones
│   │   ├── roadmap.md           # Main roadmap document
│   │   └── tasks.json           # Task tracking
│   └── specifications/          # Technical specifications
│       ├── prd.md              # Product requirements
│       └── technical-spec.md   # Technical architecture
├── infrastructure/               # Infrastructure as Code
│   └── gcp/                    # GCP setup scripts
│       ├── guide.sh           # Interactive setup guide
│       ├── setup.sh           # Automated setup
│       ├── scripts/           # Modular setup scripts
│       └── config/            # Configuration templates
├── src/                         # Source code (coming soon)
│   ├── auth-service/           # Authentication microservice
│   ├── appflowy-fork/          # Forked AppFlowy
│   └── cli-tool/               # Local sync CLI
├── tests/                       # Test files
└── tools/                       # Development tools
```

## 🔄 Development Workflow

### Current Focus
Working on **Milestone 1** - Setting up GCP infrastructure and authentication service.

### Next Steps
1. ✅ ~~Set up GCP project and billing~~ **COMPLETE**
2. 🔄 Write Terraform scripts for infrastructure
3. ⏳ Develop authentication service
4. ⏳ Integrate Google Workspace OAuth

## 🤝 Contributing

This is a private project for 42 Galaxies. Team members should:
1. Check the roadmap in `/docs/roadmap/`
2. Pick a task marked as "To Do"
3. Create a feature branch
4. Submit a pull request when complete

## 📈 Recent Updates

### Latest Commit
- **feat:** Complete GCP infrastructure setup for 42 Galaxies Workspace
- Task T1.1 complete: GCP project and billing alerts configured
- Added comprehensive automation scripts and interactive guide

## 📝 License

Private - 42 Galaxies Internal Use Only

## 🔗 Links

- **Console:** [GCP Project Dashboard](https://console.cloud.google.com/home/dashboard?project=galaxies-workspace-42)
- **Domain:** workspace.42galaxies.studio (coming soon)
- **Documentation:** See `/docs` directory

---

*Last Updated: 2025-08-25*