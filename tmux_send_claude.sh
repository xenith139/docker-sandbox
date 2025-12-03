#!/bin/bash
# Send keys to Claude tmux session
# Usage: ./tmux_send_claude.sh <keys>
# Example: ./tmux_send_claude.sh "ls -la"
# Example: ./tmux_send_claude.sh "hello" --no-enter
# Example: ./tmux_send_claude.sh Enter

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if keys provided
if [ -z "$1" ]; then
    echo "Error: Keys/command to send required"
    echo ""
    echo "Usage: ./tmux_send_claude.sh <keys> [--no-enter]"
    echo ""
    echo "Examples:"
    echo "  ./tmux_send_claude.sh \"ls -la\"           -> Send command and press Enter"
    echo "  ./tmux_send_claude.sh \"hello\" --no-enter -> Send text without Enter"
    echo "  ./tmux_send_claude.sh Enter               -> Just press Enter"
    echo "  ./tmux_send_claude.sh Down                -> Press Down arrow"
    echo ""
    exit 1
fi

KEYS="$1"
NO_ENTER=false

# Check for --no-enter flag
if [ "$2" == "--no-enter" ]; then
    NO_ENTER=true
fi

pidfile="$SCRIPT_DIR/claude_session_PID"

# Check if the PID file exists
if [ ! -f "$pidfile" ]; then
    echo "Error: claude_session_PID file not found!"
    echo "No Claude session appears to be running."
    echo "Start one with: ./tmux_run_claude.sh"
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
    # These are literal tmux key names, not regular text
    case "$KEYS" in
        Enter|Down|Up|Left|Right|Tab|Escape|Space|BSpace|Home|End|PageUp|PageDown)
            tmux send-keys -t "$sessionId" "$KEYS"
            echo "Sent special key to session '$sessionId': $KEYS"
            ;;
        *)
            # All regular text (including "." or other short messages) gets Enter appended
            # Use -l flag to send text literally, then send Enter as separate key
            tmux send-keys -t "$sessionId" -l "$KEYS"
            tmux send-keys -t "$sessionId" Enter
            echo "Sent command to session '$sessionId': $KEYS"
            ;;
    esac
fi
