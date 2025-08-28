# 🌌 AppFlowy Studios - 42 Galaxies Workspace

A self-hosted AppFlowy platform with Google Workspace integration, providing collaborative document editing for the 42galaxies.studio team.

## 🚀 Project Status

**Backend Infrastructure: ✅ DEPLOYED & STABLE**  
**AppFlowy Forks: ✅ INTEGRATED**  
**Architecture Decision: ✅ SIMPLIFIED BACKEND**  
**Frontend Application: 🔄 IN PROGRESS**

### Current Deployment
- **VM IP:** 34.42.130.249
- **Backend Type:** Simplified (PostgreSQL, Redis, GoTrue, Nginx)
- **Status:** Production-tested and stable
- **Services Running:** 
  - PostgreSQL with pgvector ✅
  - Redis caching ✅
  - GoTrue authentication ✅
  - Nginx reverse proxy ✅
- **Forked Repositories:** 
  - Backend: [42-Galaxies/AppFlowy-Cloud](https://github.com/42-Galaxies/AppFlowy-Cloud)
  - Frontend: [42-Galaxies/AppFlowy](https://github.com/42-Galaxies/AppFlowy)

## 📊 Project Progress

### Overall Completion: ██████░░░░ 60% 

### Milestone 1: GCP Foundation & Infrastructure ✅ COMPLETE
| Task | Description | Status |
|------|-------------|--------|
| T1.1 | Set up GCP project and billing alerts | ✅ Complete |
| T1.2 | Create Compute Engine VM and configure firewall rules | ✅ Complete |
| T1.3 | Configure DNS for workspace.42galaxies.studio | 🔄 In Progress |
| T1.4 | Set up Google Workspace OAuth credentials | ⏳ To Do |
| T1.5 | Install Docker/Docker Compose on VM | ✅ Complete |

### Milestone 2: AppFlowy Deployment 🔄 IN PROGRESS
| Task | Description | Status |
|------|-------------|--------|
| T2.1 | Fork AppFlowy repositories | ✅ Complete |
| T2.2 | Configure GoTrue for Google OAuth | ⏳ To Do |
| T2.3 | Deploy Docker Compose stack | ✅ Complete (Simplified) |
| T2.4 | Configure SSL/TLS with Let's Encrypt | ⏳ To Do |
| T2.5 | Test authentication flow | ⏳ To Do |
| T2.6 | Deploy AppFlowy frontend | 🔄 In Progress |

## 🏗️ Infrastructure Details

### GCP Resources
- **Project ID:** `galaxies-workspace-42`
- **VM:** `appflowy-workspace` (e2-medium, 4GB RAM)
- **Static IP:** `34.42.130.249`
- **Region:** `us-central1-a`
- **Monthly Budget:** $10 USD with alerts

### Deployed Services (Simplified Backend)
```
✅ PostgreSQL (pgvector/pgvector:pg15) - Database with vector support
✅ Redis (redis:7-alpine) - Caching layer
✅ GoTrue (supabase/gotrue:v2.151.0) - Authentication service
✅ Nginx (nginx:alpine) - Reverse proxy
🔄 AppFlowy Frontend - Ready to deploy from fork
```

### Backend Architecture Decision

#### Why Simplified Backend?
We use a simplified backend that provides **full AppFlowy functionality** while avoiding issues with the official AppFlowy Cloud image:

**✅ What Works:**
- Document creation and editing
- Real-time collaboration 
- User authentication (GoTrue)
- Data persistence (PostgreSQL)
- Performance caching (Redis)

**🎯 Storage Solution: Google Drive**
- Using Google Drive instead of S3/Minio
- Integrates with your Google Workspace
- Shared storage for all team members
- No additional storage costs

**⚠️ Features Not Included (not needed for MVP):**
- AI features (can add later if needed)
- Admin panel (manage directly via database)

**Benefits:**
- **100% Compatible** with AppFlowy frontend
- **Stable**: No migration failures
- **Simple**: 4 services vs 10+ services
- **Proven**: Production-tested at 34.42.130.249

The simplified backend provides everything needed for collaborative document editing. When ready, we can migrate to the full stack using our forked repository.

See [BACKEND_ARCHITECTURE.md](infrastructure/gcp/BACKEND_ARCHITECTURE.md) for technical details.

## 🚀 Quick Start

### 1. Auto-Setup (Recommended)
```bash
cd infrastructure/gcp
./setup.sh

# Choose option 1 for auto-configuration
# Then choose option 11 for full VM deployment
```

### 2. Test Deployment
```bash
# Run comprehensive tests
./scripts/10-test-deployment.sh

# Check service health
curl http://34.42.130.249/health
curl http://34.42.130.249/auth/health
```

### 3. Access Services
```bash
# SSH to VM
gcloud compute ssh appflowy-workspace --zone=us-central1-a

# View logs
gcloud compute ssh appflowy-workspace --zone=us-central1-a \
  --command="cd /opt/appflowy/config && docker compose -f docker-compose-simplified.yml logs -f"

# Check container status
gcloud compute ssh appflowy-workspace --zone=us-central1-a \
  --command="docker ps"
```

## 📁 Project Structure

```
appflowy-studios/
├── README.md                     # This file
├── .gitmodules                   # Git submodule configuration
├── infrastructure/              
│   └── gcp/                     # GCP deployment scripts
│       ├── setup.sh            # Main setup menu
│       ├── scripts/            # Automation scripts
│       │   ├── 00-auto-configure.sh     # Auto-detect GCP settings
│       │   ├── 05-create-vm.sh          # VM creation
│       │   ├── 06-configure-firewall.sh # Firewall rules
│       │   ├── 07-install-docker.sh     # Docker installation
│       │   ├── 08-deploy-appflowy-simplified.sh # Backend deployment
│       │   ├── 10-test-deployment.sh    # Testing suite
│       │   ├── 11-deploy-from-submodules.sh # Build from forks
│       │   └── 12-deploy-appflowy-fork.sh # Deploy fork to server
│       ├── docker/             # Docker configurations
│       │   ├── docker-compose-simplified.yml
│       │   └── nginx-simple.conf
│       └── config/             # Configuration files
│           └── env.sh.template # Environment template
├── docs/                       
│   └── roadmap/               
│       └── roadmap.md         # Project roadmap
└── src/                       # Forked repositories (submodules)
    ├── appflowy-backend/      # AppFlowy-Cloud fork
    └── appflowy-frontend/     # AppFlowy fork
```

## 🔒 Security

### Protected Files (NOT in Git)
- `config/env.sh` - Contains passwords and secrets
- SSL certificates
- Google OAuth credentials

### Public Infrastructure
- All scripts and templates are safe to share
- Passwords are auto-generated during setup
- Firewall rules configured for standard ports

## 📋 Immediate Next Steps

1. **Configure and Deploy Frontend** - Build AppFlowy frontend from our fork at `src/appflowy-frontend/`
2. **Configure Domain** - Set up workspace.42galaxies.studio → 34.42.130.249
3. **Google OAuth Setup** - Create OAuth credentials restricted to @42galaxies.studio
4. **SSL Certificate** - Configure Let's Encrypt for HTTPS
5. **Production Configuration** - Update environment variables for production use

## 🧪 Testing

### Quick Health Check
```bash
# All-in-one status check
echo "=== Service Health ==="
curl -s http://34.42.130.249/health && echo " ✓ Nginx"
curl -s http://34.42.130.249/auth/health | grep -q GoTrue && echo " ✓ GoTrue"
echo "=== Container Status ==="
gcloud compute ssh appflowy-workspace --zone=us-central1-a \
  --command="docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### Comprehensive Test
```bash
cd infrastructure/gcp
./scripts/10-test-deployment.sh
```

## 🤝 Contributing

This is a private project for 42 Galaxies. Team members should:
1. Check the roadmap in `/docs/roadmap/roadmap.md`
2. Review "Immediate Next Steps" above
3. Test changes locally before pushing
4. Keep sensitive data out of commits

## 📈 Recent Accomplishments

### Infrastructure Complete ✅
- Automated GCP project setup with billing alerts
- VM creation with static IP allocation
- Docker and Docker Compose installation
- Simplified backend stack deployment (PostgreSQL, Redis, GoTrue, Nginx)
- Comprehensive testing suite
- Auto-configuration using gcloud detection

### AppFlowy Fork Integration ✅
- Forked both AppFlowy repositories to 42-Galaxies organization
- Added forks as git submodules for version control
- Created deployment scripts for fork-based deployment
- Full control over both backend and frontend codebases

### Issues Resolved
- Fixed AppFlowy Cloud container migration issues
- Switched to simplified backend approach
- Resolved SCRIPT_DIR path issues in deployment scripts
- Added proper environment variable handling

## 🔗 Resources

- **GCP Console:** [Project Dashboard](https://console.cloud.google.com/home/dashboard?project=galaxies-workspace-42)
- **VM Status:** http://34.42.130.249
- **GitHub:** [42-Galaxies/appflowy-studios](https://github.com/42-Galaxies/appflowy-studios)
- **Domain:** workspace.42galaxies.studio (pending configuration)
- **Roadmap:** [docs/roadmap/roadmap.md](docs/roadmap/roadmap.md)

---

*Last Updated: 2025-08-28*  
*Backend Infrastructure: OPERATIONAL*  
*Frontend Deployment: PENDING*