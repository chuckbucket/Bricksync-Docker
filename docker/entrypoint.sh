#!/bin/bash
# set -e: exit asap if a command exits with a non-zero status
set -e

# --- Start of Bricksync Configuration Logic ---
APP_DIR="/app"
DATA_DIR="${APP_DIR}/data"
# EXECUTABLE_PATH="${APP_DIR}/bricksync" # Path to the main application executable
DEFAULT_CONFIG_SOURCE="/app/bricksync.conf.txt" # Original default config from Dockerfile (template)
EFFECTIVE_CONFIG_PATH="${DATA_DIR}/bricksync.conf.txt" # Effective config path
USER_CONFIG_MOUNT_DIR="/mnt/config" # User mounts their bricksync.conf here
USER_CONFIG_FILE_PATH="${USER_CONFIG_MOUNT_DIR}/bricksync.conf" # Path for user-mounted custom config

# Function to update config
update_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    local is_numeric_or_bool="$4" # true if value should not be quoted, false or empty otherwise

    local trimmed_value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "INFO: Updating config: ${key} = ${trimmed_value}"
    local escaped_value=$(echo "$trimmed_value" | sed 's/[&\\/]/\\\\&/g') # Escape for sed

    # Check if the key exists and update it
    if grep -q "^${key}[[:space:]]*=.*" "${config_file}"; then
        if [ "$is_numeric_or_bool" = "true" ]; then
            sed -i "s|^${key}[[:space:]]*=.*|${key} = ${escaped_value};|" "${config_file}"
        else
            sed -i "s|^${key}[[:space:]]*=.*|${key} = \"${escaped_value}\";|" "${config_file}"
        fi
    # If key doesn't exist, append it
    else
        if [ "$is_numeric_or_bool" = "true" ]; then
            echo "${key} = ${escaped_value};" >> "${config_file}"
        else
            echo "${key} = \"${escaped_value}\";" >> "${config_file}"
        fi
    fi
}

echo "INFO: Ensuring Bricksync data directory exists and is writable: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
# Dockerfile should grant dockeruser sudo NOPASSWD.
# This chown is to ensure dockeruser can write to the data dir, e.g. for bricksync.conf.txt
if sudo chown -R dockeruser:dockeruser "${DATA_DIR}"; then
    echo "INFO: Ownership of ${DATA_DIR} set to dockeruser."
    ls -ld "${DATA_DIR}"
else
    echo "WARNING: Failed to change ownership of ${DATA_DIR}. Config file operations might fail."
fi

# Manage bricksync.conf.txt
echo "INFO: Managing ${EFFECTIVE_CONFIG_PATH}..."
if [ -f "${USER_CONFIG_FILE_PATH}" ]; then
    echo "INFO: User-provided config found at ${USER_CONFIG_FILE_PATH}. Copying to ${EFFECTIVE_CONFIG_PATH}."
    cp "${USER_CONFIG_FILE_PATH}" "${EFFECTIVE_CONFIG_PATH}"

elif [ -f "${DEFAULT_CONFIG_SOURCE}" ]; then
    echo "INFO: No user-provided config. Using default config from image: ${DEFAULT_CONFIG_SOURCE}."

    cp "${DEFAULT_CONFIG_SOURCE}" "${EFFECTIVE_CONFIG_PATH}"
else
    echo "INFO: No user-provided config and no default image config. Creating minimal ${EFFECTIVE_CONFIG_PATH}."
    cat <<EOF > "${EFFECTIVE_CONFIG_PATH}"
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
    echo "INFO: Minimal default ${EFFECTIVE_CONFIG_PATH} created."
fi

# Ensure the config file is writable by dockeruser if it was copied from root-owned source
sudo chown dockeruser:dockeruser "${EFFECTIVE_CONFIG_PATH}" || echo "WARN: Could not chown ${EFFECTIVE_CONFIG_PATH}"

# Apply environment variable configurations
echo "INFO: Applying Bricksync environment variable configurations..."
if [ -n "$BRICKSYNC_AUTOCHECK" ]; then update_config "autocheck" "$BRICKSYNC_AUTOCHECK" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKLINK_CONSUMERKEY" ]; then update_config "bricklink.consumerkey" "$BRICKSYNC_BRICKLINK_CONSUMERKEY" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_CONSUMERSECRET" ]; then update_config "bricklink.consumersecret" "$BRICKSYNC_BRICKLINK_CONSUMERSECRET" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_TOKEN" ]; then update_config "bricklink.token" "$BRICKSYNC_BRICKLINK_TOKEN" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_TOKENSECRET" ]; then update_config "bricklink.tokensecret" "$BRICKSYNC_BRICKLINK_TOKENSECRET" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_FAILINTERVAL" ]; then update_config "bricklink.failinterval" "$BRICKSYNC_BRICKLINK_FAILINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKLINK_POLLINTERVAL" ]; then update_config "bricklink.pollinterval" "$BRICKSYNC_BRICKLINK_POLLINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_KEY" ]; then update_config "brickowl.key" "$BRICKSYNC_BRICKOWL_KEY" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKOWL_FAILINTERVAL" ]; then update_config "brickowl.failinterval" "$BRICKSYNC_BRICKOWL_FAILINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_POLLINTERVAL" ]; then update_config "brickowl.pollinterval" "$BRICKSYNC_BRICKOWL_POLLINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

if [ -n "$BRICKSYNC_PRICEGUIDE_CACHEPATH" ]; then
    update_config "priceguide.cachepath" "$BRICKSYNC_PRICEGUIDE_CACHEPATH" "${EFFECTIVE_CONFIG_PATH}"
    echo "INFO: Ensuring price guide cache path directory exists for: $BRICKSYNC_PRICEGUIDE_CACHEPATH"
    mkdir -p "$(dirname "$BRICKSYNC_PRICEGUIDE_CACHEPATH")"
else # Ensure default cache path from config exists
    DEFAULT_PG_CACHE_PATH_FROM_CONF=$(grep '^priceguide.cachepath[[:space:]]*=' "${EFFECTIVE_CONFIG_PATH}" | sed 's/.*=[[:space:]]*"\(.*\)"\s*;.*/\1/' | sed "s|^\.\./data|${APP_DIR}/data|g" | sed "s|^\./data|${APP_DIR}/data|g" | sed "s|^data|${APP_DIR}/data|g")
    if [ -z "$DEFAULT_PG_CACHE_PATH_FROM_CONF" ]; then # try without quotes
        DEFAULT_PG_CACHE_PATH_FROM_CONF=$(grep '^priceguide.cachepath[[:space:]]*=' "${EFFECTIVE_CONFIG_PATH}" | sed 's/.*=[[:space:]]*\(.*\)\s*;.*/\1/' | sed "s|^\.\./data|${APP_DIR}/data|g" | sed "s|^\./data|${APP_DIR}/data|g" | sed "s|^data|${APP_DIR}/data|g")
    fi
    if [ -n "$DEFAULT_PG_CACHE_PATH_FROM_CONF" ]; then
        echo "INFO: Ensuring default price guide cache path directory exists from config: ${DEFAULT_PG_CACHE_PATH_FROM_CONF}"
        mkdir -p "$(dirname "${DEFAULT_PG_CACHE_PATH_FROM_CONF}")"
    else
        echo "WARN: Could not determine default priceguide.cachepath from config to ensure directory exists."
    fi
fi
if [ -n "$BRICKSYNC_PRICEGUIDE_CACHEFORMAT" ]; then update_config "priceguide.cacheformat" "$BRICKSYNC_PRICEGUIDE_CACHEFORMAT" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_PRICEGUIDE_CACHETIME" ]; then update_config "priceguide.cachetime" "$BRICKSYNC_PRICEGUIDE_CACHETIME" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_RETAINEMPTYLOTS" ]; then update_config "retainemptylots" "$BRICKSYNC_RETAINEMPTYLOTS" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_REUSEEMPTY" ]; then update_config "brickowl.reuseempty" "$BRICKSYNC_BRICKOWL_REUSEEMPTY" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_CHECKMESSAGE" ]; then update_config "checkmessage" "$BRICKSYNC_CHECKMESSAGE" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKLINK_PIPELINEQUEUE" ]; then update_config "bricklink.pipelinequeue" "$BRICKSYNC_BRICKLINK_PIPELINEQUEUE" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_PIPELINEQUEUE" ]; then update_config "brickowl.pipelinequeue" "$BRICKSYNC_BRICKOWL_PIPELINEQUEUE" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

echo "INFO: Bricksync environment variable processing complete."
echo "--- Final effective ${EFFECTIVE_CONFIG_PATH} ---"
cat "${EFFECTIVE_CONFIG_PATH}"
echo "---------------------------------------------------------"
# --- End of Bricksync Configuration Logic ---


# VNC and noVNC services startup (from user's example)
trap ctrl_c INT TERM # Use TERM for more graceful shutdown if possible
function ctrl_c() {
  # Kill all background processes (children of this script)
  # The '-' before PID means kill the process group.
  kill -TERM -$$
  wait # Wait for them to terminate
  echo "INFO: VNC server and noVNC shut down."
  exit 0
}

# Clean up VNC lock files if they exist from a previous unclean shutdown
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Default VNC environment variables if not set (already set in Dockerfile but good for standalone script execution)
VNC_PORT="${VNC_PORT:-5901}"
NO_VNC_PORT="${NO_VNC_PORT:-6901}"
DISPLAY="${DISPLAY:-:1}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-32}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1600x900}"

echo "INFO: Launching noVNC server..."
/opt/noVNC/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT &
NOVNC_PID=$!
echo "INFO: noVNC server started with PID $NOVNC_PID on port $NO_VNC_PORT."

echo "INFO: Launching VNC server (vncserver wrapper for Xtigervnc)..."
# The vncserver script typically creates ~/.vnc/xstartup if it doesn't exist,
# or uses a system default. It also manages finding a free display number if :1 is taken,
# though here we are explicitly setting it.
# Using --I-KNOW-THIS-IS-INSECURE for -SecurityTypes None
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION \
  -SecurityTypes None -localhost no --I-KNOW-THIS-IS-INSECURE &
VNCSERVER_PID=$! # vncserver script often daemonizes; PID might be of the script, not Xtigervnc directly.
echo "INFO: VNC server process started with PID $VNCSERVER_PID on display $DISPLAY."
# Xtigervnc PID might be different if vncserver forks. For trap, killing the vncserver script PID should be enough.

echo "INFO: VNC setup complete. Waiting for processes to exit..."
# Wait for the primary VNC server process.
# If vncserver daemonizes properly, this wait might exit if VNCSERVER_PID is the initial script.
# A more robust wait would be on Xtigervnc if its PID could be reliably obtained.
# However, for the trap, killing the process group of the entrypoint script (kill -TERM -$$) is more effective.
wait $NOVNC_PID $VNCSERVER_PID
# If VNCSERVER_PID is just the script that forks, it might exit quickly.
# The trap with 'kill -TERM -$$' is the main mechanism for stopping everything.
# A final 'wait' without PIDs will wait for all children if the specific PIDs already exited.
wait
