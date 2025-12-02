#!/bin/bash
# Send keys to container tmux session
# Usage: ./tmux_send_container.sh <identifier> <keys>
# Example: ./tmux_send_container.sh 1 "ls -la"
# Example: ./tmux_send_container.sh 1 "cd /workspace" --enter

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if identifier provided
if [ -z "$1" ]; then
    echo "Error: Container identifier required"
    echo ""
    echo "Usage: ./tmux_send_container.sh <identifier> <keys> [--no-enter]"
    echo ""
    echo "Examples:"
    echo "  ./tmux_send_container.sh 1 \"ls -la\"           -> Send command and press Enter"
    echo "  ./tmux_send_container.sh 1 \"hello\" --no-enter -> Send text without Enter"
    echo "  ./tmux_send_container.sh 1 Enter               -> Just press Enter"
    echo "  ./tmux_send_container.sh 1 Down                -> Press Down arrow"
    echo ""
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: Keys/command to send required"
    echo ""
    echo "Usage: ./tmux_send_container.sh <identifier> <keys> [--no-enter]"
    exit 1
fi

IDENTIFIER="$1"
KEYS="$2"
NO_ENTER=false

# Check for --no-enter flag
if [ "$3" == "--no-enter" ]; then
    NO_ENTER=true
fi

pidfile="$SCRIPT_DIR/container_session_${IDENTIFIER}_PID"

# Check if the PID file exists
if [ ! -f "$pidfile" ]; then
    echo "Error: $pidfile file not found!"
    echo "No container session for identifier '$IDENTIFIER' appears to be running."
    echo "Start one with: ./tmux_run_container.sh $IDENTIFIER"
    exit 1
fi

# Read the session ID from the PID file
sessionId=$(cat "$pidfile")

# Check if the session exists
if ! tmux has-session -t "$sessionId" 2>/dev/null; then
    echo "Error: Session '$sessionId' not found!"
    echo "The session may have been terminated."
    exit 1
fi

# Send the keys
if [ "$NO_ENTER" = true ]; then
    tmux send-keys -t "$sessionId" "$KEYS"
    echo "Sent keys to session '$sessionId': $KEYS"
else
    # Check if KEYS is a special key like Enter, Down, Up, etc.
    case "$KEYS" in
        Enter|Down|Up|Left|Right|Tab|Escape|Space)
            tmux send-keys -t "$sessionId" "$KEYS"
            echo "Sent special key to session '$sessionId': $KEYS"
            ;;
        *)
            tmux send-keys -t "$sessionId" "$KEYS" Enter
            echo "Sent command to session '$sessionId': $KEYS"
            ;;
    esac
fi
