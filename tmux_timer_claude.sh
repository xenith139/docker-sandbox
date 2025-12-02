#!/bin/bash
# Timer script to periodically send messages to Claude tmux session
# Usage: ./tmux_timer_claude.sh [minutes] [--message "text"]
#        ./tmux_timer_claude.sh --stop
#        ./tmux_timer_claude.sh --view

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMUX_SESSION="claude-timer"
DEFAULT_INTERVAL_MINUTES=2
DEFAULT_MESSAGE="."
COUNTDOWN_INTERVAL=30  # Print countdown every 30 seconds

# Parse arguments
INTERVAL_MINUTES=$DEFAULT_INTERVAL_MINUTES
MESSAGE="$DEFAULT_MESSAGE"
INSIDE_TMUX=false

show_usage() {
    echo "Usage: ./tmux_timer_claude.sh [minutes] [--message \"text\"]"
    echo "       ./tmux_timer_claude.sh --stop"
    echo "       ./tmux_timer_claude.sh --view"
    echo ""
    echo "Options:"
    echo "  [minutes]        Interval in minutes (default: $DEFAULT_INTERVAL_MINUTES)"
    echo "  --message, -m    Message to send (default: \"$DEFAULT_MESSAGE\")"
    echo "  --stop           Stop the timer"
    echo "  --view           View the timer session"
    echo ""
    echo "Examples:"
    echo "  ./tmux_timer_claude.sh                    -> Send '.' every 2 minutes"
    echo "  ./tmux_timer_claude.sh 5                  -> Send '.' every 5 minutes"
    echo "  ./tmux_timer_claude.sh 3 -m \"continue\"   -> Send 'continue' every 3 minutes"
    echo ""
}

# Handle --stop flag
if [[ "$1" == "--stop" ]]; then
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "Stopping claude-timer..."
        tmux kill-session -t "$TMUX_SESSION"
        echo "Timer stopped"
    else
        echo "No claude-timer session running"
    fi
    exit 0
fi

# Handle --view flag
if [[ "$1" == "--view" ]]; then
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "No claude-timer session running"
        echo "Start it with: ./tmux_timer_claude.sh [minutes]"
        exit 1
    fi
    echo "Attaching to claude-timer session..."
    echo "To detach: Ctrl+B then D"
    exec tmux attach-session -t "$TMUX_SESSION"
fi

# Handle --help flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Handle --inside-tmux flag (internal use)
if [[ "$1" == "--inside-tmux" ]]; then
    INSIDE_TMUX=true
    shift
fi

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --message|-m)
            MESSAGE="$2"
            shift 2
            ;;
        --message=*)
            MESSAGE="${1#--message=}"
            shift
            ;;
        -m=*)
            MESSAGE="${1#-m=}"
            shift
            ;;
        [0-9]*)
            INTERVAL_MINUTES="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

INTERVAL_SECONDS=$((INTERVAL_MINUTES * 60))

# If not inside tmux, start/restart the tmux session
if [ "$INSIDE_TMUX" = false ]; then
    # Check if Claude session is running
    if [ ! -f "$SCRIPT_DIR/claude_session_PID" ]; then
        echo "Error: No Claude session running"
        echo "Start one with: ./tmux_run_claude.sh"
        exit 1
    fi

    # Kill existing timer session if it exists
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "Stopping previous claude-timer session..."
        tmux kill-session -t "$TMUX_SESSION"
        sleep 1
    fi

    echo "Starting claude-timer in background tmux session..."
    echo "Interval: $INTERVAL_MINUTES minute(s)"
    echo "Message: \"$MESSAGE\""
    echo "To view: ./tmux_timer_claude.sh --view"
    echo "To stop: ./tmux_timer_claude.sh --stop"

    # Start new tmux session in detached mode
    tmux new-session -d -s "$TMUX_SESSION" "bash '$0' --inside-tmux $INTERVAL_MINUTES --message '$MESSAGE'"

    echo "Timer started successfully"
    exit 0
fi

# From here on, we're inside the tmux session
echo "Claude Keep-Alive Timer Started"
echo "========================================"
echo "This script will send '$MESSAGE' to Claude every $INTERVAL_MINUTES minute(s)"
echo "Press Ctrl+C to stop (or use --stop flag)"
echo "========================================"
echo ""

# Function to format seconds into MM:SS
format_time() {
    local seconds=$1
    printf "%02d:%02d" $((seconds / 60)) $((seconds % 60))
}

# Trap Ctrl+C for clean exit
trap 'echo ""; echo "Timer stopped"; exit 0' INT

ITERATION=1

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iteration #$ITERATION"

    # Send message via tmux_send_claude.sh
    echo "Sending '$MESSAGE'..."
    if bash "$SCRIPT_DIR/tmux_send_claude.sh" "$MESSAGE"; then
        echo "Message sent successfully"
    else
        echo "Failed to send message (Claude session may not exist)"
    fi

    echo ""
    echo "Next message in $(format_time $INTERVAL_SECONDS)..."
    echo ""

    # Countdown with intervals
    for ((remaining=INTERVAL_SECONDS; remaining>0; remaining-=COUNTDOWN_INTERVAL)); do
        if [ $remaining -le $COUNTDOWN_INTERVAL ]; then
            # For the last interval, count down second by second
            for ((sec=remaining; sec>0; sec--)); do
                echo -ne "\rSending in $(format_time $sec)...   "
                sleep 1
            done
        else
            echo "$(format_time $remaining) remaining..."
            sleep $COUNTDOWN_INTERVAL
        fi
    done

    echo -ne "\r"
    echo ""
    echo "----------------------------------------"
    echo ""

    ((ITERATION++))
done
