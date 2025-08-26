# Task Management Format for AppFlowy Studios

## Tags System

PRDs and technical documents use tags to link related content:
- `#task:T1.1` - References a specific task
- `#milestone:M1` - Associates with a milestone
- `#feature:authentication` - Tags a feature area
- `#priority:critical` - Indicates priority level
- `#dependency:T2.3` - Shows task dependencies

When creating tasks from PRDs, extract these tags to populate task fields.

## Task JSON Format

Tasks are stored in `/docs/roadmap/tasks.json` as a dictionary where task IDs are keys. Each task must follow this exact format:

```json
{
  "TASK_ID": {
    "id": "TASK_ID",
    "title": "Brief task title",
    "status": "todo|in_progress|done|blocked",
    "priority": "low|medium|high|critical",
    "project": "appflowy-studios",
    "description": "Detailed description of the task",
    "milestone": "M1|M2|M3|M4",
    "created": "ISO 8601 timestamp",
    "updated": "ISO 8601 timestamp",
    "details": "Extended details about implementation",
    "links": [
      {
        "name": "PRD",
        "url": "../specifications/prd.md"
      },
      {
        "name": "Technical PRD",
        "url": "../specifications/technical-prd-milestone-1.md"
      }
    ],
    "subtasks": ["SUBTASK_ID1", "SUBTASK_ID2"]
  }
}
```

## Field Definitions

- **id**: Unique identifier (e.g., "T1.1", "T2.3")
- **title**: Short, actionable task title
- **status**: Current state
  - `todo`: Not started
  - `in_progress`: Currently being worked on
  - `done`: Completed
  - `blocked`: Cannot proceed
- **priority**: 
  - `critical`: Must Have - blocking other work
  - `high`: Must Have - required for milestone
  - `medium`: Should Have - important but not blocking
  - `low`: Nice to Have - can be deferred
- **project**: Always "appflowy-studios"
- **description**: One-line summary of what needs to be done
- **milestone**: M1, M2, M3, or M4 (or empty for unassigned)
- **details**: Extended information about how to implement
- **links**: Array of related documents
- **subtasks**: Array of child task IDs (optional)

## Adding New Tasks

When adding a new task:

1. Use the next sequential ID in the format `T<milestone>.<number>`
2. Set status to "todo" 
3. Include relevant PRD/technical spec links
4. Add subtask IDs if the task should be broken down further
5. Use ISO 8601 format for timestamps: `datetime.now().isoformat()`

## Example Task

```json
{
  "T1.1": {
    "id": "T1.1",
    "title": "Set up GCP project",
    "status": "todo",
    "priority": "high",
    "project": "appflowy-studios",
    "description": "Set up GCP project and billing alerts",
    "milestone": "M1",
    "created": "2024-01-15T10:30:00",
    "updated": "2024-01-15T10:30:00",
    "details": "Create a new project named appflowy-studios-prod, link billing account, create budget, enable necessary APIs",
    "links": [
      {
        "name": "PRD",
        "url": "../specifications/prd.md"
      },
      {
        "name": "Technical PRD",
        "url": "../specifications/technical-prd-milestone-1.md"
      }
    ],
    "subtasks": []
  }
}
```

## Creating Tasks from PRDs

When processing a PRD with tags:

1. Extract all `#task:` tags to create task entries
2. Use `#milestone:` tags to set the milestone field
3. Map `#priority:` tags to priority levels (critical/high/medium/low)
4. Create links back to the PRD section containing the task
5. Use `#dependency:` tags to populate subtasks or note dependencies in details

## Roadmap Generation

When asked to create a roadmap:

1. Group tasks by milestone
2. Order by priority within each milestone
3. Show dependencies between tasks
4. Include links to source PRDs and technical specs
5. Format as markdown with clear sections per milestone

## Important Notes

- Always maintain the dictionary structure with task IDs as keys
- Never use array format - the roadmap tool expects a dictionary
- Include links to relevant documentation for context
- Use subtasks array to reference child task IDs, not inline task objects
- Details field should contain implementation notes not in the main description
- Extract and preserve tags from PRDs when creating tasks
- Cross-reference tasks using the tag system