#!/bin/bash
set -e

APP_DIR="/app"
DATA_DIR="${APP_DIR}/data"
DEFAULT_CONFIG_SOURCE="${APP_DIR}/bricksync.conf.txt"
EFFECTIVE_CONFIG_PATH="${DATA_DIR}/bricksync.conf.txt"
USER_CONFIG_MOUNT_DIR="/mnt/config"
USER_CONFIG_FILE_PATH="${USER_CONFIG_MOUNT_DIR}/bricksync.conf"

echo "----- Starting Entrypoint -----"
echo "INFO: Preparing BrickSync config..."

# Obfuscates secrets from logs
safe_echo() {
    local key="$1"
    if [[ "$key" == *"key"* || "$key" == *"secret"* || "$key" == *"token"* ]]; then
        echo "INFO: Updating config: ${key} = ********"
    else
        echo "INFO: Updating config: ${key} = $2"
    fi
}

update_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    local is_numeric_or_bool="$4"

    local trimmed_value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    safe_echo "$key" "$trimmed_value"
    local escaped_value=$(echo "$trimmed_value" | sed 's/[&\\/]/\\\\&/g')

    if grep -q "^${key}[[:space:]]*=.*" "$config_file"; then
        if [ "$is_numeric_or_bool" = "true" ]; then
            sed -i "s|^${key}[[:space:]]*=.*|${key} = ${escaped_value};|" "$config_file"
        else
            sed -i "s|^${key}[[:space:]]*=.*|${key} = \"${escaped_value}\";|" "$config_file"
        fi
    else
        if [ "$is_numeric_or_bool" = "true" ]; then
            echo "${key} = ${escaped_value};" >> "$config_file"
        else
            echo "${key} = \"${escaped_value}\";" >> "$config_file"
        fi
    fi
}

mkdir -p "$DATA_DIR"
# Ownership should be correct from Dockerfile, sudo not needed here
chown -R dockeruser:dockeruser "$DATA_DIR" 2>/dev/null || echo "WARN: Could not ensure ownership of $DATA_DIR (expected dockeruser)"

if [ -f "$USER_CONFIG_FILE_PATH" ]; then
    echo "INFO: Found user config, copying..."
    cp "$USER_CONFIG_FILE_PATH" "$EFFECTIVE_CONFIG_PATH"
elif [ -f "$DEFAULT_CONFIG_SOURCE" ]; then
    echo "INFO: Using default config from image."
    cp "$DEFAULT_CONFIG_SOURCE" "$EFFECTIVE_CONFIG_PATH"
else
    echo "INFO: Creating minimal default config."
    cat <<EOF > "$EFFECTIVE_CONFIG_PATH"
// General configuration
autocheck = 1;

// BrickLink configuration
bricklink.consumerkey = "";
bricklink.consumersecret = "";
bricklink.token = "";
bricklink.tokensecret = "";
bricklink.failinterval = 300;
bricklink.pollinterval = 600;

// BrickOwl configuration
brickowl.key = "";
brickowl.failinterval = 300;
brickowl.pollinterval = 600;

// Price Guide configuration
priceguide.cachepath = "data/pgcache/priceguide.db";
priceguide.cacheformat = "BrickStock";
priceguide.cachetime = 5;

// Advanced configuration
retainemptylots = 0;
brickowl.reuseempty = 0;
checkmessage = 1;
bricklink.pipelinequeue = 8;
brickowl.pipelinequeue = 8;
EOF
fi

# Ownership should be correct as dockeruser creates/copies the file into its own directory
chown dockeruser:dockeruser "$EFFECTIVE_CONFIG_PATH" 2>/dev/null || echo "WARN: Could not ensure ownership of $EFFECTIVE_CONFIG_PATH (expected dockeruser)"

# Apply environment configs
echo "INFO: Applying environment overrides..."
[ -n "$BRICKSYNC_AUTOCHECK" ] && update_config "autocheck" "$BRICKSYNC_AUTOCHECK" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKLINK_CONSUMERKEY" ] && update_config "bricklink.consumerkey" "$BRICKSYNC_BRICKLINK_CONSUMERKEY" "$EFFECTIVE_CONFIG_PATH"
[ -n "$BRICKSYNC_BRICKLINK_CONSUMERSECRET" ] && update_config "bricklink.consumersecret" "$BRICKSYNC_BRICKLINK_CONSUMERSECRET" "$EFFECTIVE_CONFIG_PATH"
[ -n "$BRICKSYNC_BRICKLINK_TOKEN" ] && update_config "bricklink.token" "$BRICKSYNC_BRICKLINK_TOKEN" "$EFFECTIVE_CONFIG_PATH"
[ -n "$BRICKSYNC_BRICKLINK_TOKENSECRET" ] && update_config "bricklink.tokensecret" "$BRICKSYNC_BRICKLINK_TOKENSECRET" "$EFFECTIVE_CONFIG_PATH"
[ -n "$BRICKSYNC_BRICKLINK_FAILINTERVAL" ] && update_config "bricklink.failinterval" "$BRICKSYNC_BRICKLINK_FAILINTERVAL" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKLINK_POLLINTERVAL" ] && update_config "bricklink.pollinterval" "$BRICKSYNC_BRICKLINK_POLLINTERVAL" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKOWL_KEY" ] && update_config "brickowl.key" "$BRICKSYNC_BRICKOWL_KEY" "$EFFECTIVE_CONFIG_PATH"
[ -n "$BRICKSYNC_BRICKOWL_FAILINTERVAL" ] && update_config "brickowl.failinterval" "$BRICKSYNC_BRICKOWL_FAILINTERVAL" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKOWL_POLLINTERVAL" ] && update_config "brickowl.pollinterval" "$BRICKSYNC_BRICKOWL_POLLINTERVAL" "$EFFECTIVE_CONFIG_PATH" "true"

if [ -n "$BRICKSYNC_PRICEGUIDE_CACHEPATH" ]; then
    update_config "priceguide.cachepath" "$BRICKSYNC_PRICEGUIDE_CACHEPATH" "$EFFECTIVE_CONFIG_PATH"
    mkdir -p "$(dirname "$BRICKSYNC_PRICEGUIDE_CACHEPATH")"
else
    DEFAULT_PG_PATH=$(grep '^priceguide.cachepath[[:space:]]*=' "$EFFECTIVE_CONFIG_PATH" \
        | sed -E 's/.*=\s*"?([^";]+)"?.*/\1/' \
        | sed "s|^\.*/*data|${APP_DIR}/data|")
    [ -n "$DEFAULT_PG_PATH" ] && mkdir -p "$(dirname "$DEFAULT_PG_PATH")"
fi

[ -n "$BRICKSYNC_PRICEGUIDE_CACHEFORMAT" ] && update_config "priceguide.cacheformat" "$BRICKSYNC_PRICEGUIDE_CACHEFORMAT" "$EFFECTIVE_CONFIG_PATH"
[ -n "$BRICKSYNC_PRICEGUIDE_CACHETIME" ] && update_config "priceguide.cachetime" "$BRICKSYNC_PRICEGUIDE_CACHETIME" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_RETAINEMPTYLOTS" ] && update_config "retainemptylots" "$BRICKSYNC_RETAINEMPTYLOTS" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKOWL_REUSEEMPTY" ] && update_config "brickowl.reuseempty" "$BRICKSYNC_BRICKOWL_REUSEEMPTY" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_CHECKMESSAGE" ] && update_config "checkmessage" "$BRICKSYNC_CHECKMESSAGE" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKLINK_PIPELINEQUEUE" ] && update_config "bricklink.pipelinequeue" "$BRICKSYNC_BRICKLINK_PIPELINEQUEUE" "$EFFECTIVE_CONFIG_PATH" "true"
[ -n "$BRICKSYNC_BRICKOWL_PIPELINEQUEUE" ] && update_config "brickowl.pipelinequeue" "$BRICKSYNC_BRICKOWL_PIPELINEQUEUE" "$EFFECTIVE_CONFIG_PATH" "true"

echo "INFO: BrickSync config setup complete."

# VNC Setup
trap ctrl_c INT TERM
ctrl_c() {
    echo "INFO: Trap caught SIGINT or SIGTERM. Shutting down..."
    # Attempt to dump logs before exiting
    echo "INFO: [TRAP] Final contents of $NOVNC_LOG:"
    cat "$NOVNC_LOG" || echo "INFO: [TRAP] Could not cat $NOVNC_LOG"
    echo "INFO: [TRAP] Final contents of $VNCSERVER_LOG:"
    cat "$VNCSERVER_LOG" || echo "INFO: [TRAP] Could not cat $VNCSERVER_LOG"
    # Also try to dump xstartup.log if we create it later
    if [ -f "$XSTARTUP_LOG" ]; then
        echo "INFO: [TRAP] Final contents of $XSTARTUP_LOG:"
        cat "$XSTARTUP_LOG" || echo "INFO: [TRAP] Could not cat $XSTARTUP_LOG"
    fi

    # Terminate script's own process group (includes background jobs if any were started by this shell directly without setsid)
    # However, vncserver and novnc are complex; they might daemonize or manage their own process groups.
    # A simple kill -TERM -$$ might not be enough to gracefully stop them if they are truly detached.
    # For now, focus on getting logs.
    
    # Try to kill the specific PIDs if they are still running
    if [ -n "$NOVNC_PID" ] && ps -p $NOVNC_PID > /dev/null; then
        echo "INFO: [TRAP] Sending SIGTERM to noVNC PID $NOVNC_PID"
        kill -TERM $NOVNC_PID
    fi
    if [ -n "$VNCSERVER_PID" ] && ps -p $VNCSERVER_PID > /dev/null; then
        echo "INFO: [TRAP] Sending SIGTERM to VNC Server PID $VNCSERVER_PID"
        kill -TERM $VNCSERVER_PID
    fi
    
    # Give them a moment to die
    sleep 0.5
    
    echo "INFO: [TRAP] VNC server and noVNC shut down initiated."
    exit 0 # Exit from trap
}

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

VNC_PORT="${VNC_PORT:-5901}"
NO_VNC_PORT="${NO_VNC_PORT:-6901}"
DISPLAY="${DISPLAY:-:1}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-32}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1600x900}"

echo "INFO: VNC and noVNC Startup Sequence"
echo "INFO: Current user: $(id)"
echo "INFO: PATH: $PATH"
WHICH_VNCSERVER=$(which vncserver)
echo "INFO: which vncserver: $WHICH_VNCSERVER"
if [ -n "$WHICH_VNCSERVER" ]; then
    echo "INFO: ls -l \$(which vncserver):"
    ls -l "$WHICH_VNCSERVER"
else
    echo "ERROR: vncserver not found in PATH."
fi
echo "INFO: VNC_PORT=${VNC_PORT}, NO_VNC_PORT=${NO_VNC_PORT}, DISPLAY=${DISPLAY}"
echo "INFO: VNC_COL_DEPTH=${VNC_COL_DEPTH}, VNC_RESOLUTION=${VNC_RESOLUTION}"

# Ensure log files can be written by dockeruser
# These files are expected to be in /var/log, which might not be writable by default by dockeruser.
# Consider creating /var/log/bricksync/ owned by dockeruser and logging there,
# or ensure /var/log is writable or these specific files are pre-created with correct permissions.
# For now, we'll attempt to use /var/log and let it fail if permissions are wrong,
# as changing Dockerfile for /var/log ownership is a separate step.
LOG_DIR="/tmp/bricksync_logs"
mkdir -p "$LOG_DIR"
chown dockeruser:dockeruser "$LOG_DIR"
NOVNC_LOG="${LOG_DIR}/novnc.log"
VNCSERVER_LOG="${LOG_DIR}/vncserver.log"
XSTARTUP_LOG="${LOG_DIR}/xstartup.log" # Define XSTARTUP_LOG for entrypoint
touch "$NOVNC_LOG" "$VNCSERVER_LOG" "$XSTARTUP_LOG" || echo "WARN: Could not touch log files in $LOG_DIR"
chown dockeruser:dockeruser "$NOVNC_LOG" "$VNCSERVER_LOG" "$XSTARTUP_LOG" 2>/dev/null || echo "WARN: Could not chown log files in $LOG_DIR"

echo "INFO: Logging noVNC to $NOVNC_LOG"
echo "INFO: Logging VNC Server to $VNCSERVER_LOG"

set -x # Enable command tracing for VNC/noVNC launch

echo "INFO: Starting noVNC server..."
/opt/noVNC/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT --desktop BrickSync >> "$NOVNC_LOG" 2>&1 &
NOVNC_PID=$!
echo "INFO: noVNC PID: $NOVNC_PID"

echo "INFO: Starting VNC server..."
# Re-adding security options as the initial 'usage' error is resolved.
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION \
  -SecurityTypes None -localhost=0 >> "$VNCSERVER_LOG" 2>&1 &
VNCSERVER_PID=$!
echo "INFO: VNC Server PID: $VNCSERVER_PID"

set +x # Disable command tracing

echo "-----------------------------"
echo "INFO: noVNC available at: http://localhost:${NO_VNC_PORT}/vnc.html (replace 'localhost' with your Docker host IP if accessing remotely)"
echo "INFO: Check $NOVNC_LOG and $VNCSERVER_LOG for startup messages."
echo "-----------------------------"

# Check if processes are running
if [ -n "$NOVNC_PID" ] && ps -p $NOVNC_PID > /dev/null; then
    echo "INFO: noVNC process $NOVNC_PID is running."
else
    echo "ERROR: noVNC process $NOVNC_PID not found or failed to start. Check $NOVNC_LOG."
    echo "INFO: Contents of $NOVNC_LOG:"
    cat "$NOVNC_LOG" || echo "INFO: Could not cat $NOVNC_LOG"
fi

if [ -n "$VNCSERVER_PID" ] && ps -p $VNCSERVER_PID > /dev/null; then
    echo "INFO: VNC server process $VNCSERVER_PID is running."
else
    echo "ERROR: VNC server process $VNCSERVER_PID not found or failed to start. Check $VNCSERVER_LOG."
    echo "INFO: Contents of $VNCSERVER_LOG:"
    cat "$VNCSERVER_LOG" || echo "INFO: Could not cat $VNCSERVER_LOG"
fi

echo "INFO: Awaiting termination of PIDs: NOVNC_PID=$NOVNC_PID, VNCSERVER_PID=$VNCSERVER_PID ..."
# Wait for both processes. If one fails to start, its PID might be empty or invalid.
# `wait` can handle multiple PIDs. It will return when all specified PIDs have exited.
# If a PID is invalid or already exited, wait might behave differently based on shell.
# We rely on the PIDs being valid if the commands launched successfully.

# Store PIDs that we expect to be valid
PIDS_TO_WAIT=""
[ -n "$NOVNC_PID" ] && PIDS_TO_WAIT="$PIDS_TO_WAIT $NOVNC_PID"
[ -n "$VNCSERVER_PID" ] && PIDS_TO_WAIT="$PIDS_TO_WAIT $VNCSERVER_PID"

if [ -n "$PIDS_TO_WAIT" ]; then
    wait $PIDS_TO_WAIT
    EC=$?
    echo "INFO: Primary wait command for ($PIDS_TO_WAIT) finished with exit code: $EC."
else
    echo "INFO: No valid PIDs to wait for. Both processes may have failed to start."
fi

# Adding a small sleep to allow any final logs to flush.
sleep 1

# Disable exit on error for the log dumping and copying, to ensure we try everything
set +e

LOG_COPY_DIR="/output_logs_internal_dont_touch"
echo "INFO: Preparing to copy logs to $LOG_COPY_DIR for retrieval via volume mount."
mkdir -p "$LOG_COPY_DIR"
chown dockeruser:dockeruser "$LOG_COPY_DIR" 2>/dev/null || echo "WARN: Could not chown $LOG_COPY_DIR"

echo "INFO: Final contents of $NOVNC_LOG:"
cat "$NOVNC_LOG" || echo "INFO: Could not cat $NOVNC_LOG (normal if noVNC had no output or errors)."
if [ -f "$NOVNC_LOG" ]; then cp "$NOVNC_LOG" "$LOG_COPY_DIR/"; fi

echo "INFO: Final contents of $VNCSERVER_LOG:"
cat "$VNCSERVER_LOG" || echo "INFO: Could not cat $VNCSERVER_LOG (CRITICAL if VNC server was expected to run)."
if [ -f "$VNCSERVER_LOG" ]; then cp "$VNCSERVER_LOG" "$LOG_COPY_DIR/"; fi

echo "INFO: Final contents of $XSTARTUP_LOG:"
cat "$XSTARTUP_LOG" || echo "INFO: Could not cat $XSTARTUP_LOG (CRITICAL if VNC server started but xstartup failed)."
if [ -f "$XSTARTUP_LOG" ]; then cp "$XSTARTUP_LOG" "$LOG_COPY_DIR/"; fi

echo "INFO: Logs copied to $LOG_COPY_DIR within the container. Map this directory as a volume to access logs on the host."

echo "INFO: Script pausing for 300 seconds..."
sleep 300 # Keep container alive for manual inspection or if logs weren't mapped
echo "INFO: Pause finished. Script finished. Container will now exit."
