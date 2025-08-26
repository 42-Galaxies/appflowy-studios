# Product Requirements Document (PRD): AppFlowy-Studios MVP

## Document Information
| Field | Details |
|-------|---------|
| **Status** | Draft |
| **Author** | Gemini |
| **Created** | 2025-08-24 |
| **Last Updated** | 2025-08-24 |
| **Version** | 1.0 |

## Executive Summary
This document outlines the requirements for the Minimum Viable Product (MVP) of AppFlowy-Studios. The project aims to provide a self-hosted version of AppFlowy, integrated with 42 Galaxies' user authentication, accessible via web and mobile, with local file sync capabilities. This will provide a secure, collaborative environment for our users.

## Problem Statement

### Current State
Currently, there is no centralized, secure, and company-managed platform for collaborative document and project management that is deeply integrated with our existing user infrastructure. Teams resort to a mix of external tools, leading to data fragmentation and security concerns.

### User Problems
- **Problem 1:** Lack of a single, trusted platform for project documentation and notes.
- **Problem 2:** Difficulty in collaborating on documents with internal team members securely.
- **Problem 3:** Inefficient workflows due to switching between multiple applications.
- **Problem 4:** No easy way to sync and edit documents from a local development environment.

### Business Impact
The lack of a unified solution leads to decreased productivity, potential security risks with sensitive data stored on third-party platforms, and a disjointed user experience for our team members.

## Solution Overview

### Proposed Solution
We will host the official AppFlowy-Cloud service on our own infrastructure (GCP). Access will be restricted to users within the 42 Galaxies Google Workspace by leveraging the built-in Google Authentication provider. The application will be available at `workspace.42galaxies.studio`.

### Key Benefits
1. **Centralized & Secure:** A single, secure platform for all project-related documents.
2. **Improved Collaboration:** Seamless collaboration for all authenticated users.
3. **Enhanced Productivity:** A unified environment reduces context switching and streamlines workflows.
4. **Simplified Maintenance:** Using the official, pre-built AppFlowy-Cloud container simplifies deployment and reduces long-term maintenance overhead.

## User Stories

### Primary User Stories
```
As a developer,
I want to sign in to the AppFlowy instance using my 42 Galaxies Google account,
So that I can access my documents securely.
```
```
As a project manager,
I want to access our AppFlowy instance through a dedicated subdomain,
So that I can easily find and manage our team's workspace.
```

### Acceptance Criteria
- [ ] Users can log in using their 42 Galaxies Google Workspace credentials.
- [ ] The AppFlowy instance is accessible at `workspace.42galaxies.studio`.
- [ ] Web and mobile clients can connect to the hosted instance.

## Functional Requirements

### Core Features
| ID | Feature | Priority | Description |
|----|---------|----------|-------------|
| F1 | GCP Hosting for AppFlowy | Must Have | Deploy the official `AppFlowy-Cloud` container on GCP. [task-id: T1.2][priority: Must Have][status: To Do] |
| F2 | Google Workspace Authentication | Must Have | Configure the built-in Google Authentication provider to restrict access to the `42galaxies.studio` domain. [task-id: T1.3][priority: Must Have][status: To Do] |
| F3 | Subdomain Access | Must Have | Host the application on `workspace.42galaxies.studio`. [task-id: T1.5][priority: Must Have][status: To Do] |

### User Flow
1. User navigates to `workspace.42galaxies.studio`.
2. User is redirected to a Google login page.
3. User logs in with their 42 Galaxies Google account.
4. Upon successful authentication, the user is redirected to the AppFlowy web application.
5. The user can create, edit, and view documents.
6. The user can download and install the CLI tool.
7. Using the CLI tool, the user can authenticate and sync their files to their local machine.

## Non-Functional Requirements

### Performance
- **Response time:** API calls should respond in < 300ms.
- **Concurrent users:** The system should support at least 100 concurrent users for the MVP.

### Security
- **Authentication:** All access must be authenticated via 42 Galaxies Google Workspace OAuth.
- **Data Encryption:** All data must be encrypted at rest and in transit.

### Scalability
- The architecture should be designed to scale horizontally to accommodate future growth.

## Technical Constraints
- Must be hosted on Google Cloud Platform (GCP).
- Authentication must be tied to the 42 Galaxies Google Workspace.

## Success Metrics

### Key Performance Indicators (KPIs)
| Metric | Current | Target | Measurement Method |
|--------|---------|--------|-------------------|
| User Adoption | 0 | 75% of the team | Weekly active users |
| User Satisfaction | N/A | >80% | User surveys |

### Success Criteria
- [ ] The AppFlowy instance is successfully deployed and accessible.
- [ ] At least 50% of the target users have logged in and created a document within the first month.

## Timeline & Milestones
See `docs/roadmap.md` for a detailed breakdown.

## Risks & Mitigation

### Identified Risks
| Risk | Probability | Impact | Mitigation Strategy |
|------|------------|--------|-------------------|
| AppFlowy fork becomes difficult to maintain | Medium | High | Regularly sync with the upstream repository and contribute back where possible. |
| GCP cost overruns | Low | Medium | Implement billing alerts and regularly monitor resource usage. |
| CLI tool is complex to build | Medium | Medium | Start with basic sync functionality and iterate. |

## Out of Scope
- Public registration or access for users outside of the 42 Galaxies workspace.
- Any features not present in the forked version of AppFlowy.
- Advanced CLI features beyond basic file sync.

## Open Questions
- [ ] What are the specific requirements for the mobile app experience?
- [ ] Are there any existing AppFlowy forks we should consider?
