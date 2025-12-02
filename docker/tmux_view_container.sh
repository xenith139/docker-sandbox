#!/bin/bash
# View container tmux session
# Usage: ./tmux_view_container.sh <identifier>
# Example: ./tmux_view_container.sh 01

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if identifier provided
if [ -z "$1" ]; then
    echo "Error: Container identifier required"
    echo ""
    echo "Usage: ./tmux_view_container.sh <identifier>"
    echo ""
    echo "Examples:"
    echo "  ./tmux_view_container.sh 01   -> View tron-docker-01 tmux session"
    echo "  ./tmux_view_container.sh dev  -> View tron-docker-dev tmux session"
    echo ""
    exit 1
fi

IDENTIFIER="$1"
pidfile="$SCRIPT_DIR/container_session_${IDENTIFIER}_PID"

# Check if the PID file exists
if [ ! -f "$pidfile" ]; then
    echo "Error: $pidfile file not found!"
    echo "Please run ./tmux_run_container.sh $IDENTIFIER first to start a container session."
    exit 1
fi

# Read the session ID from the PID file
sessionId=$(cat "$pidfile")

echo "Attaching to tmux session: $sessionId"

# Check if the session exists
if ! tmux has-session -t "$sessionId" 2>/dev/null; then
    echo "Error: Session '$sessionId' not found!"
    echo "The session may have been terminated."
    exit 1
fi

# Attach to the tmux session
tmux attach-session -t "$sessionId"
