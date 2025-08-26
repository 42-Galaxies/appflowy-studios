# AppFlowy-Studios MVP Roadmap

This document outlines the roadmap and tasks required to deliver the AppFlowy-Studios MVP.

## Milestones

### M1: GCP Foundation & User Authentication (1-2 Weeks)

**Goal:** Set up the foundational infrastructure and get authentication working.

**Testable Outcomes:** At the end of this milestone, the authentication service will be running. While there is no user-facing application yet, you can test the authentication flow directly. A developer can make an API call to the service, be redirected to Google to log in, and receive a valid JWT if they are part of the `42galaxies.studio` workspace.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T1.1 | Set up GCP project and billing alerts. | Must Have | ✅ Complete |
| T1.2 | Write Terraform scripts for GKE, Cloud SQL, and Cloud Storage. | Must Have | To Do |
| T1.3 | Create the Authentication Service microservice. | Must Have | To Do |
| T1.4 | Integrate Authentication Service with Google Workspace OAuth. | Must Have | To Do |
| T1.5 | Set up a basic CI/CD pipeline for the Authentication Service. | Should Have | To Do |

### M2: AppFlowy Cloud Deployment (2-3 Weeks)

**Goal:** Deploy a forked version of AppFlowy and make it accessible.

**Testable Outcomes:** This is the first point where a user can interact with the full application. A user can navigate to `workspace.42galaxies.studio`, sign in with their Google account, be redirected to the AppFlowy UI, create a new document, and see that it saves correctly.

| Task ID | Description | Priority | Status |
|---------|-------------|----------|--------|
| T2.1 | Fork the official AppFlowy repository. | Must Have | To Do |
| T2.2 | Dockerize the forked AppFlowy backend. | Must Have | To Do |
| T2.3 | Deploy the AppFlowy backend to the GKE cluster. | Must Have | To Do |
| T2.4 | Connect the AppFlowy backend to the Cloud SQL database. | Must Have | To Do |
| T2.5 | Configure Cloudflare and set up the `workspace.42galaxies.studio` subdomain. | Must Have | To Do |
| T2.6 | Integrate the AppFlowy backend with the Authentication Service. | Must Have | To Do |

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
