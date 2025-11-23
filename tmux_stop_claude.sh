#!/bin/bash

# Check if the PID file exists
if [ ! -f claude_session_PID ]; then
    echo "Error: claude_session_PID file not found!"
    echo "No Claude session appears to be running."
    exit 1
fi

# Read the session ID from the PID file
sessionId=$(cat claude_session_PID)

echo "Stopping tmux session: $sessionId"

# Check if the session exists
if ! tmux has-session -t "$sessionId" 2>/dev/null; then
    echo "Warning: Session '$sessionId' not found!"
    echo "The session may have already been terminated."
    echo "Cleaning up PID file..."
    rm -f claude_session_PID
    exit 0
fi

# Kill the tmux session
tmux kill-session -t "$sessionId"

if [ $? -eq 0 ]; then
    echo "Session '$sessionId' stopped successfully!"
    echo "Cleaning up PID file..."
    rm -f claude_session_PID
    echo "Done!"
else
    echo "Error: Failed to stop session '$sessionId'"
    exit 1
fi
