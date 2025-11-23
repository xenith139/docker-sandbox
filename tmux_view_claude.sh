#!/bin/bash

# Check if the PID file exists
if [ ! -f claude_session_PID ]; then
    echo "Error: claude_session_PID file not found!"
    echo "Please run tmux_run_claude.sh first to start a Claude session."
    exit 1
fi

# Read the session ID from the PID file
sessionId=$(cat claude_session_PID)

echo "Attaching to tmux session: $sessionId"

# Check if the session exists
if ! tmux has-session -t "$sessionId" 2>/dev/null; then
    echo "Error: Session '$sessionId' not found!"
    echo "The session may have been terminated."
    exit 1
fi

# Attach to the tmux session
tmux attach-session -t "$sessionId"
