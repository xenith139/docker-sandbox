#!/bin/bash
# Timer script to periodically send messages to container tmux session
# Usage: ./tmux_timer_container.sh <identifier> [minutes] [--message "text"]
#        ./tmux_timer_container.sh <identifier> --stop
#        ./tmux_timer_container.sh <identifier> --view

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_INTERVAL_MINUTES=2
DEFAULT_MESSAGE="."
COUNTDOWN_INTERVAL=30  # Print countdown every 30 seconds

show_usage() {
    echo "Usage: ./tmux_timer_container.sh <identifier> [minutes] [--message \"text\"]"
    echo "       ./tmux_timer_container.sh <identifier> --stop"
    echo "       ./tmux_timer_container.sh <identifier> --view"
    echo ""
    echo "Options:"
    echo "  <identifier>     Container identifier (required, e.g., 1, dev)"
    echo "  [minutes]        Interval in minutes (default: $DEFAULT_INTERVAL_MINUTES)"
    echo "  --message, -m    Message to send (default: \"$DEFAULT_MESSAGE\")"
    echo "  --stop           Stop the timer for this container"
    echo "  --view           View the timer session"
    echo ""
    echo "Examples:"
    echo "  ./tmux_timer_container.sh 1                    -> Send '.' every 2 minutes"
    echo "  ./tmux_timer_container.sh 1 5                  -> Send '.' every 5 minutes"
    echo "  ./tmux_timer_container.sh 1 3 -m \"continue\"   -> Send 'continue' every 3 minutes"
    echo "  ./tmux_timer_container.sh 1 --stop             -> Stop the timer"
    echo ""
}

# Check if identifier provided
if [ -z "$1" ]; then
    echo "Error: Container identifier required"
    echo ""
    show_usage
    exit 1
fi

# Handle --help flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

IDENTIFIER="$1"
shift

TMUX_SESSION="timer-container-$IDENTIFIER"

# Parse arguments
INTERVAL_MINUTES=$DEFAULT_INTERVAL_MINUTES
MESSAGE="$DEFAULT_MESSAGE"
INSIDE_TMUX=false

# Handle --stop flag
if [[ "$1" == "--stop" ]]; then
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "Stopping timer for container $IDENTIFIER..."
        tmux kill-session -t "$TMUX_SESSION"
        echo "Timer stopped"
    else
        echo "No timer running for container $IDENTIFIER"
    fi
    exit 0
fi

# Handle --view flag
if [[ "$1" == "--view" ]]; then
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "No timer running for container $IDENTIFIER"
        echo "Start it with: ./tmux_timer_container.sh $IDENTIFIER [minutes]"
        exit 1
    fi
    echo "Attaching to timer session for container $IDENTIFIER..."
    echo "To detach: Ctrl+B then D"
    exec tmux attach-session -t "$TMUX_SESSION"
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
    # Check if container session is running
    pidfile="$SCRIPT_DIR/container_session_${IDENTIFIER}_PID"
    if [ ! -f "$pidfile" ]; then
        echo "Error: No container session running for identifier '$IDENTIFIER'"
        echo "Start one with: ./tmux_run_container.sh $IDENTIFIER"
        exit 1
    fi

    # Kill existing timer session if it exists
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "Stopping previous timer for container $IDENTIFIER..."
        tmux kill-session -t "$TMUX_SESSION"
        sleep 1
    fi

    echo "Starting timer for container $IDENTIFIER in background..."
    echo "Interval: $INTERVAL_MINUTES minute(s)"
    echo "Message: \"$MESSAGE\""
    echo "To view: ./tmux_timer_container.sh $IDENTIFIER --view"
    echo "To stop: ./tmux_timer_container.sh $IDENTIFIER --stop"

    # Start new tmux session in detached mode
    tmux new-session -d -s "$TMUX_SESSION" "bash '$0' $IDENTIFIER --inside-tmux $INTERVAL_MINUTES --message '$MESSAGE'"

    echo "Timer started successfully"
    exit 0
fi

# From here on, we're inside the tmux session
echo "Container $IDENTIFIER Keep-Alive Timer Started"
echo "========================================"
echo "This script will send '$MESSAGE' to container $IDENTIFIER every $INTERVAL_MINUTES minute(s)"
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

    # Send message via tmux_send_container.sh
    echo "Sending '$MESSAGE' to container $IDENTIFIER..."
    if bash "$SCRIPT_DIR/tmux_send_container.sh" "$IDENTIFIER" "$MESSAGE"; then
        echo "Message sent successfully"
    else
        echo "Failed to send message (container session may not exist)"
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
