#!/bin/bash
# Run container in tmux session
# Usage: ./tmux_run_container.sh <identifier> [--description "text"]
# Example: ./tmux_run_container.sh 01
# Example: ./tmux_run_container.sh 01 --description "My container"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse arguments
IDENTIFIER=""
DESCRIPTION=""

i=1
for arg in "$@"; do
    if [[ "$arg" == "--description" ]] || [[ "$arg" == "-d" ]]; then
        i=$((i + 1))
        eval "DESCRIPTION=\${$i}"
    elif [[ "$arg" == --description=* ]]; then
        DESCRIPTION="${arg#--description=}"
    elif [[ "$arg" != "$DESCRIPTION" ]]; then
        if [ -z "$IDENTIFIER" ]; then
            IDENTIFIER="$arg"
        fi
    fi
    i=$((i + 1))
done

# Check if identifier provided
if [ -z "$IDENTIFIER" ]; then
    echo "Error: Container identifier required"
    echo ""
    echo "Usage: ./tmux_run_container.sh <identifier> [--description \"text\"]"
    echo ""
    echo "Examples:"
    echo "  ./tmux_run_container.sh 1              -> Run tron-docker-1 in tmux"
    echo "  ./tmux_run_container.sh dev            -> Run tron-docker-dev in tmux"
    echo "  ./tmux_run_container.sh 2 -d \"Test\"    -> Run with description (for new containers)"
    echo ""
    exit 1
fi

CONTAINER_NAME="tron-docker-$IDENTIFIER"

# Generate a unique session ID
sessionId="container-${IDENTIFIER}-$(date +%s)"

# Use identifier-specific log file and PID file in docker folder
logfile="$SCRIPT_DIR/container_session_${IDENTIFIER}.log"
pidfile="$SCRIPT_DIR/container_session_${IDENTIFIER}_PID"

# Save the session ID to a PID file
echo "$sessionId" > "$pidfile"

# Clear the log file for new session
> "$logfile"

echo "Launching container '$CONTAINER_NAME' in tmux session: $sessionId"
echo "Log file: $logfile"

# Get current user and directory
current_user=$(whoami)

# Write startup information to log file
{
  echo "=========================================="
  echo "Container Session Started"
  echo "=========================================="
  echo "Session ID: $sessionId"
  echo "Container: $CONTAINER_NAME"
  echo "Identifier: $IDENTIFIER"
  echo "Timestamp: $(date)"
  echo "User: $current_user"
  echo "Script Directory: $SCRIPT_DIR"
  echo "=========================================="
} >> "$logfile"

# Build the run-container command with optional description
RUN_CMD="$SCRIPT_DIR/run-container.sh $IDENTIFIER"
if [ -n "$DESCRIPTION" ]; then
    RUN_CMD="$SCRIPT_DIR/run-container.sh $IDENTIFIER --description \"$DESCRIPTION\""
fi

# Launch tmux session with run-container.sh
tmux new-session -d -s "$sessionId" -x 120 -y 40 \
  "bash -lc 'cd $SCRIPT_DIR; \
  export TERM=screen-256color; \
  export COLUMNS=120; \
  export LINES=40; \
  echo \"Launching run-container.sh $IDENTIFIER...\" >> $logfile; \
  $RUN_CMD; \
  exit_code=\$?; \
  echo \"\" >> $logfile; \
  echo \"========================================\" >> $logfile; \
  echo \"Container Session Ended\" >> $logfile; \
  echo \"========================================\" >> $logfile; \
  echo \"Timestamp: \$(date)\" >> $logfile; \
  echo \"Exit Code: \$exit_code\" >> $logfile; \
  if [ \$exit_code -eq 0 ]; then \
    echo \"Status: SUCCESS\" >> $logfile; \
  else \
    echo \"Status: ERROR\" >> $logfile; \
  fi; \
  echo \"========================================\" >> $logfile; \
  exec bash'"

echo "Container session started successfully!"
echo "Session ID: $sessionId"
echo "Session ID saved to: $pidfile"
echo "Log file: $logfile"
echo ""
echo "To view the session, run: ./tmux_view_container.sh $IDENTIFIER"
echo "To stop the session, run: ./tmux_stop_container.sh $IDENTIFIER"
