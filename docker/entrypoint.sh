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
sudo chown -R dockeruser:dockeruser "$DATA_DIR" || echo "WARN: Could not change ownership of $DATA_DIR"

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

sudo chown dockeruser:dockeruser "$EFFECTIVE_CONFIG_PATH" || echo "WARN: Could not chown $EFFECTIVE_CONFIG_PATH"

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
    kill -TERM -$$
    wait
    echo "INFO: VNC server and noVNC shut down."
    exit 0
}

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

VNC_PORT="${VNC_PORT:-5901}"
NO_VNC_PORT="${NO_VNC_PORT:-6901}"
DISPLAY="${DISPLAY:-:1}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-32}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1600x900}"

echo "INFO: Starting noVNC server..."
/opt/noVNC/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT > /dev/null &
NOVNC_PID=$!

echo "INFO: Starting VNC server..."
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION \
  -SecurityTypes None -localhost no --I-KNOW-THIS-IS-INSECURE &
VNCSERVER_PID=$!

echo "-----------------------------"
echo "INFO: noVNC available at: http://localhost:${NO_VNC_PORT}/vnc.html (replace 'localhost' with your Docker host IP if accessing remotely)"

echo "-----------------------------"

echo "INFO: VNC services started. Awaiting termination..."
wait $NOVNC_PID $VNCSERVER_PID
wait
