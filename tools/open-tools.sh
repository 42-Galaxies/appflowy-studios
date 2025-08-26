#!/bin/bash
# Open tools for AppFlowy Studio project specifically

# Set the project directory (parent of tools folder)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="appflowy-studios"

# Get the main tools directory (two levels up)
TOOLS_DIR="$(cd "$PROJECT_DIR/.." && pwd)"

# Get the actual workspace root (for tools that need it)
ACTUAL_WORKSPACE_ROOT="/home/jb/workspace"

# Ensure roadmap directory exists in docs folder
mkdir -p "$PROJECT_DIR/docs/roadmap"

# Check if tasks file exists and show info
if [ ! -f "$PROJECT_DIR/docs/roadmap/tasks.json" ]; then
    echo "📝 Note: No tasks found. Tasks will be stored in: $PROJECT_DIR/docs/roadmap/tasks.json"
    echo ""
fi

# Check which command to run
if [ $# -eq 0 ]; then
    # Default to modern roadmap viewer if no arguments
    # Use the modern roadmap tool
    WORKSPACE_ROOT="$PROJECT_DIR/docs" python3 "$PROJECT_DIR/tools/roadmap-modern.py"
else
    # Pass through to the appropriate tool
    case "$1" in
        roadmap|r)
            shift
            # Set workspace root to docs folder for roadmap tool
            WORKSPACE_ROOT="$PROJECT_DIR/docs" python3 "$TOOLS_DIR/roadmaptool/roadmap.py" "$@"
            ;;
        tui|roadmap-tui|rt)
            shift
            # Use the modern roadmap tool
            WORKSPACE_ROOT="$PROJECT_DIR/docs" python3 "$PROJECT_DIR/tools/roadmap-modern.py" "$@"
            ;;
        status|s)
            shift
            # Use actual workspace root for project-status tool
            WORKSPACE_ROOT="$ACTUAL_WORKSPACE_ROOT" python3 "$TOOLS_DIR/project-status/project-status.py" "$PROJECT_NAME" "$@"
            ;;
        docs|d)
            shift
            # Use actual workspace root for doc-viewer tool
            WORKSPACE_ROOT="$ACTUAL_WORKSPACE_ROOT" python3 "$TOOLS_DIR/doc-viewer/view-docs.py" "$PROJECT_NAME" "$@"
            ;;
        markdown|m)
            shift
            # Default to project docs if no path specified
            if [ $# -eq 0 ]; then
                python3 "$TOOLS_DIR/markdown-viewer/markdown-viewer.py" "$PROJECT_DIR/docs"
            else
                python3 "$TOOLS_DIR/markdown-viewer/markdown-viewer.py" "$@"
            fi
            ;;
        help|--help|-h)
            cat << EOF
AppFlowy Studio Tools

Usage: ./open-tools.sh [command] [arguments]

Commands:
    roadmap, r       - Manage project roadmap and tasks
    tui, rt          - Interactive roadmap management (TUI) [default]
    status, s        - Show project status
    docs, d          - View project documentation
    markdown, m      - Browse markdown files
    help             - Show this help message

Without arguments, opens the roadmap TUI for AppFlowy Studio project.

Project directory: $PROJECT_DIR
Tasks stored in: $PROJECT_DIR/docs/roadmap/

EOF
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use './open-tools.sh help' for usage information"
            exit 1
            ;;
    esac
fi