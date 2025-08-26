#!/bin/bash
# Open tools for AppFlowy Studio project specifically

# Set the project directory
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="appflowy-studios"

# Set environment to use this project as the workspace root
export WORKSPACE_ROOT="$PROJECT_DIR"

# Get the tools directory (parent directory)
TOOLS_DIR="$(dirname "$PROJECT_DIR")"

# Check which command to run
if [ $# -eq 0 ]; then
    # Default to roadmap TUI if no arguments
    echo "🚀 Opening AppFlowy Studio Tools..."
    python3 "$TOOLS_DIR/roadmaptool/roadmap-tui.py"
else
    # Pass through to the appropriate tool
    case "$1" in
        roadmap|r)
            shift
            python3 "$TOOLS_DIR/roadmaptool/roadmap.py" "$@"
            ;;
        tui|roadmap-tui|rt)
            shift
            python3 "$TOOLS_DIR/roadmaptool/roadmap-tui.py" "$@"
            ;;
        status|s)
            shift
            python3 "$TOOLS_DIR/project-status/project-status.py" "$PROJECT_NAME" "$@"
            ;;
        docs|d)
            shift
            python3 "$TOOLS_DIR/doc-viewer/view-docs.py" "$PROJECT_NAME" "$@"
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

The tools will work with the AppFlowy Studio project directory:
$PROJECT_DIR

EOF
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use './open-tools.sh help' for usage information"
            exit 1
            ;;
    esac
fi