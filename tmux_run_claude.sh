#!/bin/bash

# Generate a unique session ID
sessionId="claude-$(date +%s)"

# Use a single log file (will be overwritten each time)
logfile="claude_session.log"

# Save the session ID to a PID file
echo "$sessionId" > claude_session_PID

# Clear the log file for new session
> "$logfile"

echo "Launching Claude in tmux session: $sessionId"
echo "Log file: $logfile"

# Get current user and directory
current_user=$(whoami)
current_dir=$(pwd)

# Write startup information to log file
{
  echo "=========================================="
  echo "Claude Session Started"
  echo "=========================================="
  echo "Session ID: $sessionId"
  echo "Timestamp: $(date)"
  echo "User: $current_user"
  echo "Directory: $current_dir"
  echo "=========================================="
} >> "$logfile"

# Launch tmux session with Claude
tmux new-session -d -s "$sessionId" -x 120 -y 40 \
  "bash -lc 'cd $current_dir; \
  export TERM=screen-256color; \
  export COLUMNS=120; \
  export LINES=40; \
  if command -v claude &> /dev/null; then \
    echo \"Claude command found - launching...\" >> $current_dir/$logfile; \
    claude --dangerously-skip-permissions; \
    exit_code=\$?; \
    echo \"\" >> $current_dir/$logfile; \
    echo \"========================================\" >> $current_dir/$logfile; \
    echo \"Claude Session Ended\" >> $current_dir/$logfile; \
    echo \"========================================\" >> $current_dir/$logfile; \
    echo \"Timestamp: \$(date)\" >> $current_dir/$logfile; \
    echo \"Exit Code: \$exit_code\" >> $current_dir/$logfile; \
    if [ \$exit_code -eq 0 ]; then \
      echo \"Status: SUCCESS\" >> $current_dir/$logfile; \
    else \
      echo \"Status: ERROR\" >> $current_dir/$logfile; \
    fi; \
    echo \"========================================\" >> $current_dir/$logfile; \
  else \
    echo \"ERROR: Claude not found in PATH\" >> $current_dir/$logfile; \
  fi; \
  exec bash'"

echo "Claude session started successfully!"
echo "Session ID: $sessionId"
echo "Session ID saved to: claude_session_PID"
echo "Log file: $logfile (minimal logging - startup/shutdown only)"
echo ""
echo "To view the session, run: ./tmux_view_claude.sh"
echo "To stop the session, run: ./tmux_stop_claude.sh"
