#!/bin/bash
# Stop container tmux session
# Usage: ./tmux_stop_container.sh <identifier>
# Example: ./tmux_stop_container.sh 01

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if identifier provided
if [ -z "$1" ]; then
    echo "Error: Container identifier required"
    echo ""
    echo "Usage: ./tmux_stop_container.sh <identifier>"
    echo ""
    echo "Examples:"
    echo "  ./tmux_stop_container.sh 01   -> Stop tron-docker-01 tmux session"
    echo "  ./tmux_stop_container.sh dev  -> Stop tron-docker-dev tmux session"
    echo ""
    exit 1
fi

IDENTIFIER="$1"
pidfile="$SCRIPT_DIR/container_session_${IDENTIFIER}_PID"

# Check if the PID file exists
if [ ! -f "$pidfile" ]; then
    echo "Error: $pidfile file not found!"
    echo "No container session for identifier '$IDENTIFIER' appears to be running."
    exit 1
fi

# Read the session ID from the PID file
sessionId=$(cat "$pidfile")

echo "Stopping tmux session: $sessionId"

# Check if the session exists
if ! tmux has-session -t "$sessionId" 2>/dev/null; then
    echo "Warning: Session '$sessionId' not found!"
    echo "The session may have already been terminated."
    echo "Cleaning up PID file..."
    rm -f "$pidfile"
    exit 0
fi

# Kill the tmux session
tmux kill-session -t "$sessionId"

if [ $? -eq 0 ]; then
    echo "Session '$sessionId' stopped successfully!"
    echo "Cleaning up PID file..."
    rm -f "$pidfile"
    echo "Done!"
else
    echo "Error: Failed to stop session '$sessionId'"
    exit 1
fi
