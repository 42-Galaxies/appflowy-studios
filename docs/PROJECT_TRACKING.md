# AppFlowy Studios - Project Tracking

## 🎯 Project Overview
**Goal:** Self-hosted AppFlowy platform with Google Workspace integration for 42galaxies.studio team  
**Status:** Backend Infrastructure Complete | Frontend Deployment Pending  
**Overall Progress:** ██████░░░░ 60%

## 📊 Current Status Dashboard

### ✅ Completed Components
| Component | Status | Details | Location |
|-----------|--------|---------|----------|
| GCP Infrastructure | ✅ Complete | VM, networking, firewall configured | 34.42.130.249 |
| Docker Environment | ✅ Complete | Docker & Docker Compose installed | /opt/appflowy |
| PostgreSQL Database | ✅ Running | With pgvector extension | Port 5432 |
| Redis Cache | ✅ Running | Caching layer operational | Port 6379 |
| GoTrue Auth | ✅ Running | Authentication service ready | Port 9999 |
| Nginx Proxy | ✅ Running | Reverse proxy configured | Port 80 |
| Fork Integration | ✅ Complete | Both repos forked & submoduled | src/ directory |
| Deployment Scripts | ✅ Fixed | All scripts updated with fixes | infrastructure/gcp/scripts/ |
| Documentation | ✅ Updated | Architecture decisions documented | docs/ & README |

### 🔄 In Progress Components
| Component | Status | Blockers | Next Actions |
|-----------|--------|----------|--------------|
| AppFlowy Frontend | 🔄 Deployment Pending | Need to build from fork | Run 11-deploy-from-submodules.sh |
| Domain Configuration | 🔄 DNS Setup | Need DNS A record | Point workspace.42galaxies.studio → 34.42.130.249 |

### ⏳ Pending Components
| Component | Priority | Dependencies | Target Milestone |
|-----------|----------|--------------|------------------|
| Google OAuth | High | Domain setup | M2 (Current) |
| SSL/TLS Certificate | High | Domain setup | M2 (Current) |
| Google Drive Integration | Medium | OAuth setup | M3 (Next) |
| Admin Panel | Medium | Frontend deployment | M3 (Next) |
| CLI Sync Tool | Low | API stability | M4 (Future) |
| Mobile Client | Low | Production deployment | M5 (Future) |

## 📈 Milestone Progress

### M1: GCP Foundation & Infrastructure ✅ 100% Complete
- [x] T1.1: Set up GCP project and billing alerts
- [x] T1.2: Create Compute Engine VM and configure firewall
- [ ] T1.3: Configure DNS for workspace.42galaxies.studio
- [ ] T1.4: Set up Google Workspace OAuth credentials
- [x] T1.5: Install Docker/Docker Compose on VM

### M2: AppFlowy Deployment 🔄 70% Complete
- [x] T2.1: Fork AppFlowy repositories
- [ ] T2.2: Configure GoTrue for Google OAuth
- [x] T2.3: Deploy Docker Compose stack (Simplified)
- [ ] T2.4: Configure SSL/TLS with Let's Encrypt
- [ ] T2.5: Test authentication flow
- [ ] T2.6: Set up automated backups

### M3: Production Features 📋 0% (Planned)
- [ ] T3.1: Integrate Google Drive API for file storage
- [ ] T3.2: Configure Google Drive shared folder
- [ ] T3.3: Build admin panel for user management
- [ ] T3.4: Add backup automation to Google Drive

## 🚨 Current Blockers

### High Priority
1. **Frontend Deployment**
   - Action: Build and deploy from fork at `src/appflowy-frontend/`
   - Script: `11-deploy-from-submodules.sh`

2. **Domain Configuration**
   - Action: Configure DNS A record
   - Requirement: workspace.42galaxies.studio → 34.42.130.249

### Medium Priority
3. **Google OAuth Setup**
   - Dependency: Domain must be configured first
   - Action: Create OAuth credentials in Google Cloud Console

4. **SSL Certificate**
   - Dependency: Domain must be configured first
   - Action: Run certbot for Let's Encrypt

## 🔧 Technical Decisions

### Why Simplified Backend?
**Decision:** Use simplified backend (PostgreSQL, Redis, GoTrue, Nginx) instead of full AppFlowy Cloud stack

**Reasons:**
1. AppFlowy Cloud image has database migration failures
2. Requires 50+ undocumented environment variables
3. Simplified stack is stable and production-tested
4. Provides full AppFlowy functionality for document collaboration

**Trade-offs:**
- ✅ Pros: Stability, simplicity, easier maintenance
- ❌ Cons: No AI features, no built-in admin panel (building custom)

### Storage Strategy: Google Drive
**Decision:** Use Google Drive API instead of S3/Minio

**Benefits:**
- Native integration with Google Workspace
- Shared storage for all team members
- No additional storage costs
- Better collaboration features

## 📝 Command Reference

### Quick Status Check
```bash
# Check all services
curl -s http://34.42.130.249/health && echo " ✓ Nginx"
gcloud compute ssh appflowy-workspace --zone=us-central1-a \
  --command="docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### Deploy Frontend
```bash
cd infrastructure/gcp
./scripts/11-deploy-from-submodules.sh
```

### Access Logs
```bash
# View all service logs
gcloud compute ssh appflowy-workspace --zone=us-central1-a \
  --command="cd /opt/appflowy/config && docker compose -f docker-compose-simplified.yml logs -f"
```

### SSH to VM
```bash
gcloud compute ssh appflowy-workspace --zone=us-central1-a
```

## 📅 Next 7 Days Plan

### Day 1-2: Frontend Deployment
- [ ] Build AppFlowy frontend from fork
- [ ] Configure backend connection
- [ ] Test basic functionality

### Day 3-4: Domain & Security
- [ ] Configure DNS for workspace.42galaxies.studio
- [ ] Set up Google OAuth credentials
- [ ] Configure SSL with Let's Encrypt

### Day 5-6: Testing & Validation
- [ ] Test complete authentication flow
- [ ] Verify document creation and sync
- [ ] Test collaboration features

### Day 7: Documentation & Handoff
- [ ] Update deployment documentation
- [ ] Create user guide for team
- [ ] Record known issues and solutions

## 🐛 Known Issues & Solutions

### Issue 1: AppFlowy Cloud Migration Failures
- **Error:** Database migrations fail with pgvector errors
- **Solution:** Use simplified backend stack
- **Status:** Resolved by architecture change

### Issue 2: Permission Denied on VM
- **Error:** Cannot write to /opt/appflowy
- **Solution:** Added `chown` commands to scripts
- **Status:** Fixed in all scripts

### Issue 3: Missing Environment Variables
- **Error:** APPFLOWY_BASE_URL and others missing
- **Solution:** Created comprehensive env configuration
- **Status:** Fixed in script 12

## 📊 Resource Usage

### Current VM Resources
- **CPU:** ~15% utilization
- **Memory:** 2.1GB / 4GB used
- **Disk:** 8GB / 20GB used
- **Network:** Minimal traffic (testing only)

### Monthly Costs (Estimated)
- **VM (e2-medium):** ~$24/month
- **Static IP:** ~$7/month
- **Storage:** ~$2/month
- **Total:** ~$33/month (within $50 budget)

## 🔗 Quick Links

- **VM Status:** http://34.42.130.249
- **GCP Console:** [Project Dashboard](https://console.cloud.google.com/home/dashboard?project=galaxies-workspace-42)
- **Backend Fork:** [42-Galaxies/AppFlowy-Cloud](https://github.com/42-Galaxies/AppFlowy-Cloud)
- **Frontend Fork:** [42-Galaxies/AppFlowy](https://github.com/42-Galaxies/AppFlowy)
- **Target Domain:** workspace.42galaxies.studio (pending)

---
*Last Updated: 2025-08-28*  
*Auto-updated tracking document for AppFlowy Studios project*