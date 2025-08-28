# AppFlowy-Studios MVP Roadmap

This document outlines the roadmap and tasks required to deliver the AppFlowy-Studios MVP.

## Implementation Notes

### Infrastructure Implementation (Completed)
- **Approach Changed**: Instead of Terraform/Kubernetes, we implemented a simpler VM + Docker approach
- **Scripts Created**: Full deployment automation in `/infrastructure/gcp/scripts/`
  - `00-auto-configure.sh`: Auto-detects GCP settings and generates secure passwords
  - `05-create-vm.sh`: Creates Compute Engine VM with static IP (Fixed SCRIPT_DIR issue)
  - `06-configure-firewall.sh`: Sets up firewall rules for all required ports
  - `07-install-docker.sh`: Installs Docker and Docker Compose
  - `08-deploy-appflowy-simplified.sh`: Deploys simplified backend stack
  - `09-fork-appflowy.sh`: Manages AppFlowy fork
  - `10-test-deployment.sh`: Comprehensive testing suite

### Backend Architecture (Simplified)
- **Issue Resolved**: AppFlowy Cloud image had migration/schema issues
- **Solution**: Deployed simplified backend with core services:
  - PostgreSQL with pgvector extension
  - Redis for caching
  - GoTrue for authentication
  - Nginx as reverse proxy
- **Status**: Backend services running at IP 34.42.130.249
- **Next Step**: Deploy AppFlowy frontend application

### Security Considerations
- **env.sh**: Contains sensitive passwords - NOT committed to git (only template)
- **Firewall**: Currently open on standard ports - need to restrict after domain setup
- **OAuth**: Google credentials pending configuration for 42galaxies.studio domain

## Milestones

### M1: GCP Foundation & Infrastructure Setup (1 Week)

**Goal:** Set up the foundational infrastructure with VM and Docker environment.

**Testable Outcomes:** At the end of this milestone, the VM infrastructure will be ready with Docker installed, networking configured, and Google Workspace OAuth credentials prepared for integration.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T1.1 | Set up GCP project and billing alerts. | Must Have | ✅ Complete |
| T1.2 | Create Compute Engine VM and configure firewall rules. | Must Have | ✅ Complete |
| T1.3 | Configure DNS for workspace.42galaxies.studio subdomain. | Must Have | To Do |
| T1.4 | Set up Google Workspace OAuth credentials and domain verification. | Must Have | To Do |
| T1.5 | Install Docker/Docker Compose on VM. | Must Have | ✅ Complete |

### M2: AppFlowy Deployment with Google Workspace Auth (1-2 Weeks)

**Goal:** Deploy a forked version of AppFlowy with Google Workspace authentication.

**Testable Outcomes:** Users can navigate to `workspace.42galaxies.studio`, sign in with their 42galaxies.studio Google account, and access AppFlowy. They can create, edit, and save documents with all changes persisted.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T2.1 | Fork the official AppFlowy-Cloud repository for customization. | Must Have | ✅ Complete |
| T2.2 | Configure GoTrue for Google Workspace OAuth (42galaxies.studio only). | Must Have | To Do |
| T2.3 | Deploy Docker Compose stack (AppFlowy + PostgreSQL + GoTrue). | Must Have | 🔄 In Progress |
| T2.4 | Configure SSL/TLS with Let's Encrypt. | Must Have | To Do |
| T2.5 | Test authentication flow and document access. | Must Have | To Do |
| T2.6 | Set up automated backups for PostgreSQL data. | Should Have | To Do |

### Immediate Next Steps
1. **Deploy AppFlowy Frontend** - Build and deploy actual AppFlowy web application
2. **Configure Domain** - Set up workspace.42galaxies.studio to point to 34.42.130.249
3. **Google OAuth Setup** - Create OAuth credentials restricted to @42galaxies.studio
4. **SSL/HTTPS** - Configure Let's Encrypt once domain is set up
5. **Secure Firewall** - Restrict SSH access to specific IPs

### M3: Local Development with CLI Sync (2-3 Weeks)

**Goal:** Develop a CLI tool for local file synchronization.

**Testable Outcomes:** A developer can install the CLI tool on their local machine. They can use the `appflowy-cli login` command to authenticate. They can then run `appflowy-cli sync` to pull down all their files, edit one locally in their preferred editor, and run `appflowy-cli sync` again to push the changes back to the server. The changes should be visible in the web UI.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T3.1 | Design the CLI tool and its commands. | Must Have | To Do |
| T3.2 | Implement the authentication flow for the CLI tool. | Must Have | To Do |
| T3.3 | Implement the file sync algorithm (three-way merge). | Must Have | To Do |
| T3.4 | Package the CLI tool for different operating systems. | Should Have | To Do |
| T3.5 | Write documentation for the CLI tool. | Nice to Have | To Do |

### M4: Mobile Client Integration (2-3 Weeks)

**Goal:** To ensure the official AppFlowy mobile client can connect to our self-hosted backend and provide a seamless user experience.

**Testable Outcomes:** A user can download the AppFlowy mobile app (iOS or Android), configure it to point to `workspace.42galaxies.studio`, and log in with their Google account. They can create, edit, and view documents, and the changes will be synced with the server and visible on the web UI.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T4.1 | Research AppFlowy mobile client build and configuration. | Must Have | To Do |
| T4.2 | Set up a local build environment for the mobile client (iOS & Android). | Must Have | To Do |
| T4.3 | Configure the mobile client to connect to the production backend. | Must Have | To Do |
| T4.4 | Test the mobile authentication flow with our custom auth service. | Must Have | To Do |
| T4.5 | Test core features (create, edit, sync) on the mobile client. | Must Have | To Do |
| T4.6 | Document the mobile client setup and configuration process. | Should Have | To Do |

### M5: Production Readiness & Monitoring (1 Week)

**Goal:** Ensure the system is production-ready with proper monitoring, backups, and documentation.

**Testable Outcomes:** The system has automated monitoring, alerting for issues, regular backups that can be restored, and comprehensive documentation for operations.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T5.1 | Set up monitoring with Cloud Monitoring/Logging. | Must Have | To Do |
| T5.2 | Configure automated daily backups with retention policy. | Must Have | To Do |
| T5.3 | Create runbooks for common operations and issues. | Must Have | To Do |
| T5.4 | Set up uptime monitoring and alerting. | Should Have | To Do |
| T5.5 | Document disaster recovery procedures. | Should Have | To Do |
