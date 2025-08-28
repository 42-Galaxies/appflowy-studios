# AppFlowy Backend Architecture Decision

## Why We Use a Simplified Backend

After extensive testing and deployment attempts, we've chosen to use a simplified backend architecture instead of the full AppFlowy Cloud stack. This document explains why.

## Issues with AppFlowy Cloud Docker Image

### 1. Database Migration Failures
The official AppFlowy Cloud image (appflowy/appflowy_cloud) fails during PostgreSQL migrations:
- Missing pgvector extension support
- Schema version mismatches
- Migration scripts expect specific database configurations

### 2. Complex Environment Requirements
The AppFlowy Cloud docker-compose.yml requires 50+ environment variables:
- Many undocumented variables (APPFLOWY_BASE_URL, APPFLOWY_WEBSOCKET_BASE_URL, etc.)
- Circular dependencies between services
- Minio S3 storage requirements even for basic deployments

### 3. Service Dependencies
The full stack includes services that may not be needed:
- Minio (S3-compatible storage)
- AI service containers
- Admin frontend
- AppFlowy worker services

## Our Simplified Backend Solution

### Core Services Only
We deploy only the essential services:
```
- PostgreSQL (with pgvector extension)
- Redis (caching)
- GoTrue (authentication)
- Nginx (reverse proxy)
```

### Storage Strategy: Google Drive Integration
Instead of S3/Minio for file storage, we'll use Google Drive:
- **Native Integration**: Works with your existing Google Workspace
- **Shared Storage**: All team members have access through 42galaxies.studio
- **No Extra Cost**: Uses your existing Google Workspace storage
- **Better Collaboration**: Files are accessible in Google Drive directly
- **Simpler Setup**: No need for S3 credentials or Minio containers

### Benefits
1. **Reliability**: Services start consistently without migration issues
2. **Simplicity**: Fewer moving parts means easier debugging
3. **Resource Efficiency**: Uses less memory and CPU
4. **Maintainability**: Clear separation of concerns

### Architecture
```
Internet -> Nginx (port 80/443)
              |
              +-> GoTrue Auth (port 9999)
              |
              +-> AppFlowy Frontend (when deployed)
              |
              +-> PostgreSQL (port 5432)
              |
              +-> Redis (port 6379)
```

## When to Use Each Approach

### Use Simplified Backend (08-deploy-appflowy-simplified.sh) when:
- Setting up development environment
- Testing infrastructure
- Running on resource-constrained VMs
- Need stable, working backend quickly

### Use Full Fork (12-deploy-appflowy-fork.sh) when:
- Need complete AppFlowy Cloud features
- Have resolved environment variable requirements
- Running production workloads with S3 storage
- Need AI features and admin panel

## Migration Path

When ready to move from simplified to full stack:
1. Export data from simplified PostgreSQL
2. Update environment variables in deploy.env
3. Run fork deployment script
4. Import data to new database
5. Verify all services are healthy

## Current Status

As of deployment:
- ✅ Simplified backend: **Working and stable**
- ⚠️ Full fork deployment: **Requires environment configuration**

The simplified backend provides a solid foundation while we work on configuring the full AppFlowy Cloud stack properly.