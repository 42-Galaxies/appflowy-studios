# PROJECT: appflowy-studios

> **AI Reference**: This file should be referenced as `@PROJECT.md` in all AI interactions.
> It provides essential context for both Gemini (planning) and Claude (implementation).

## Project Overview

**Name**: appflowy-studios
**Type**: empty
**Created**: 2025-08-24
**Status**: {{PROJECT_STATUS}}

### Mission Statement
{{PROJECT_MISSION}}

### Problem Statement
{{PROBLEM_DESCRIPTION}}

### Target Users
{{TARGET_USERS}}

## Technical Architecture

### Technology Stack
- **Language**: {{PRIMARY_LANGUAGE}}
- **Framework**: {{FRAMEWORK}}
- **Database**: {{DATABASE}}
- **Container**: {{CONTAINER_TYPE}}
- **Build System**: {{BUILD_SYSTEM}}

### Architecture Pattern
{{ARCHITECTURE_PATTERN}}

### Key Components
1. {{COMPONENT_1}}
2. {{COMPONENT_2}}
3. {{COMPONENT_3}}

### External Dependencies
- {{DEPENDENCY_1}}
- {{DEPENDENCY_2}}

## Development Guidelines

### Code Standards
- Style Guide: `@docs/guides/naming-conventions.md`
- Performance: `@docs/guides/performance-guidelines.md`
- Testing: Minimum {{TEST_COVERAGE}}% coverage required

### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: Feature branches
- `bugfix/*`: Bug fix branches

### Commit Message Format
```
type(scope): description

[optional body]
[optional footer]
```
Types: feat, fix, docs, style, refactor, test, chore

## Feature Roadmap

### Current Milestone: {{CURRENT_MILESTONE}}
See roadmap: `~/workspace/roadmap.sh list -p appflowy-studios -v`

### Core Features (MVP)
- [ ] Host appflow a forked version we use that can be hosted on GCP and only allows people in the 42 galaxies workspace to sign in
- [ ] We should be hosting on the sub domain workspace.42galaxies.studio and any one can use the website or mobiles apps to look and edit files
- [ ] Local dev machines can use command line tools to edit and update and sync files so they can modify them easy.

### Future Enhancements
- {{FUTURE_FEATURE_1}}
- {{FUTURE_FEATURE_2}}

## API Design

### Public API
```{{LANGUAGE}}
// Main entry points
{{API_EXAMPLE}}
```

### Internal APIs
Reference: `@docs/specifications/api-design.md`

## Testing Strategy

### Unit Tests
- Location: `tests/unit/`
- Runner: {{TEST_RUNNER}}
- Command: `{{TEST_COMMAND}}`

### Integration Tests
- Location: `tests/integration/`
- Command: `{{INTEGRATION_TEST_COMMAND}}`

### Performance Benchmarks
- Location: `benchmarks/`
- Targets: {{PERFORMANCE_TARGETS}}

## Build & Deployment

### Local Development
```bash
# Setup
{{SETUP_COMMANDS}}

# Build
{{BUILD_COMMAND}}

# Run
{{RUN_COMMAND}}

# Test
{{TEST_COMMAND}}
```

### Docker Development
```bash
# Using Docker
./build.sh
./run.sh
./debug.sh  # For IDE attachment
```

### Production Deployment
{{DEPLOYMENT_NOTES}}

## Integration Points

### Workspace Integration
- Roadmap: Tasks tracked in workspace roadmap system
- Artifacts: Output to `~/workspace/artifacts/appflowy-studios/`
- Shared Data: Access via `~/workspace/shared-data/`

### External Services
- {{SERVICE_1}}
- {{SERVICE_2}}

## AI Collaboration Notes

### For Gemini (Product Planning)
- Feature specs go in: `docs/specifications/`
- Create tasks with milestone: `appflowy-studios-{{MILESTONE}}`
- Priority features listed in roadmap
- Reference this file as `@PROJECT.md` when creating PRDs

### For Claude (Implementation)
- Check assigned tasks: `roadmap.sh list -p appflowy-studios`
- Implementation follows patterns in `src/examples/`
- Test requirements in task descriptions
- Update task status as you work
- Reference this file as `@PROJECT.md` for context

### Key Decisions Log
1. **{{DECISION_DATE}}**: {{DECISION_1}}
2. **{{DECISION_DATE}}**: {{DECISION_2}}

## Project-Specific Conventions

### Naming Conventions
- {{NAMING_CONVENTION_1}}
- {{NAMING_CONVENTION_2}}

### File Organization
```
appflowy-studios/
├── src/           # {{SRC_DESCRIPTION}}
├── tests/         # {{TESTS_DESCRIPTION}}
├── docs/          # {{DOCS_DESCRIPTION}}
├── data/          # {{DATA_DESCRIPTION}}
└── scripts/       # {{SCRIPTS_DESCRIPTION}}
```

### Error Handling
{{ERROR_HANDLING_APPROACH}}

### Logging
- Level: {{LOG_LEVEL}}
- Format: {{LOG_FORMAT}}
- Location: {{LOG_LOCATION}}

## Performance Requirements

### Response Times
- API calls: < {{API_RESPONSE_TIME}}ms
- Page loads: < {{PAGE_LOAD_TIME}}s
- Background tasks: < {{BACKGROUND_TASK_TIME}}

### Resource Limits
- Memory: {{MEMORY_LIMIT}}
- CPU: {{CPU_LIMIT}}
- Storage: {{STORAGE_LIMIT}}

## Security Considerations

### Authentication
{{AUTH_METHOD}}

### Authorization
{{AUTHZ_METHOD}}

### Data Protection
- Encryption: {{ENCRYPTION_STANDARD}}
- Sensitive data: {{SENSITIVE_DATA_HANDLING}}

## Monitoring & Metrics

### Key Metrics
- {{METRIC_1}}
- {{METRIC_2}}
- {{METRIC_3}}

### Alerts
- {{ALERT_CONDITION_1}}
- {{ALERT_CONDITION_2}}

## Support & Documentation

### User Documentation
Location: `docs/user-guide/`

### API Documentation
Location: `docs/api/`
Generator: {{DOC_GENERATOR}}

### Developer Setup
See: `docs/guides/setup.md`

## Contact & Ownership

**Project Lead**: {{PROJECT_LEAD}}
**Repository**: https://github.com/42Galaxies/appflowy-studios
**Issue Tracker**: GitHub Issues
**Discussion**: GitHub Discussions

---

## Quick Links

- 📋 [View Tasks](~/workspace/roadmap.sh list -p appflowy-studios)
- 📊 [TUI Dashboard](~/workspace/roadmap.sh tui)
- 🏗️ [Build Project](./build.sh)
- 🧪 [Run Tests]({{TEST_COMMAND}})
- 📚 [Documentation](docs/)

---

*This file is the single source of truth for project context. Update it when making architectural decisions or changing project direction.*