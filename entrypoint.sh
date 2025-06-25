#!/bin/sh
set -e

APP_DIR="/app"
EXECUTABLE_PATH="${APP_DIR}/bricksync"
DEFAULT_CONFIG_SOURCE="/app/bricksync.conf.txt" # Original default config from Dockerfile
EFFECTIVE_CONFIG_PATH="${APP_DIR}/bricksync.conf"
USER_CONFIG_MOUNT_DIR="/mnt/config" # User mounts their bricksync.conf here
USER_CONFIG_FILE_PATH="${USER_CONFIG_MOUNT_DIR}/bricksync.conf"

# Function to update config
update_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    local is_numeric_or_bool="$4" # true if value should not be quoted, false or empty otherwise

    echo "DEBUG: update_config: Received key='${key}', value='${value}', config_file='${config_file}', is_numeric_or_bool='${is_numeric_or_bool}'"

    # Escape forward slashes for sed, and also & and \ just in case
    local escaped_value=$(echo "$value" | sed 's/[&\\/]/\\\\&/g')
    echo "DEBUG: update_config: Escaped value='${escaped_value}'"

    local sed_cmd_part1="s|^${key} =.*|${key} = ${escaped_value}|"
    local sed_cmd_full=""

    # Check if the key exists
    if grep -q "^${key} =.*" "${config_file}"; then
        echo "DEBUG: update_config: Key '${key}' found in '${config_file}'. Preparing to update."
        if [ "$is_numeric_or_bool" = "true" ]; then
            sed_cmd_full="sed -i \"s|^${key} =.*|${key} = ${escaped_value}|\" \"${config_file}\""
        else
            sed_cmd_full="sed -i \"s|^${key} =.*|${key} = ${escaped_value}|\" \"${config_file}\""
        fi
        echo "DEBUG: update_config: Executing: ${sed_cmd_full}"
        eval "${sed_cmd_full}" # Using eval to execute the constructed command string
        echo "DEBUG: update_config: sed update for key '${key}' completed."
    else
        echo "DEBUG: update_config: Key '${key}' not found in '${config_file}'. Preparing to append."
        local append_line="${key} = ${escaped_value}"
        echo "DEBUG: update_config: Appending: \"${append_line}\" to \"${config_file}\""
        echo "${append_line}" >> "${config_file}"
        echo "DEBUG: update_config: Append for key '${key}' completed."
    fi
}

# 1. Check if bricksync executable exists and is executable
echo "INFO: Checking for bricksync executable at ${EXECUTABLE_PATH}..."
if [ ! -x "${EXECUTABLE_PATH}" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERROR: ${EXECUTABLE_PATH} not found or not executable."
    echo "Please ensure the Docker image was built correctly."
    echo "Listing ${APP_DIR} directory:"
    ls -la "${APP_DIR}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
fi
echo "INFO: Found ${EXECUTABLE_PATH}, permissions:"
ls -l "${EXECUTABLE_PATH}"

# 2. Manage bricksync.conf
echo "INFO: Managing ${EFFECTIVE_CONFIG_PATH}..."
if [ -f "${USER_CONFIG_FILE_PATH}" ]; then
    echo "INFO: User-provided config found at ${USER_CONFIG_FILE_PATH}. Copying to ${EFFECTIVE_CONFIG_PATH}."
    cp "${USER_CONFIG_FILE_PATH}" "${EFFECTIVE_CONFIG_PATH}"
elif [ -f "${DEFAULT_CONFIG_SOURCE}" ]; then
    echo "INFO: No user-provided config found. Using default config from image: ${DEFAULT_CONFIG_SOURCE}."
    cp "${DEFAULT_CONFIG_SOURCE}" "${EFFECTIVE_CONFIG_PATH}"
else
    echo "INFO: No user-provided config and no default config source (${DEFAULT_CONFIG_SOURCE}) found."
    echo "INFO: Creating a default ${EFFECTIVE_CONFIG_PATH}."
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
    echo "INFO: Default ${EFFECTIVE_CONFIG_PATH} created."
fi

if [ ! -f "${EFFECTIVE_CONFIG_PATH}" ]; then
    echo "CRITICAL ERROR: ${EFFECTIVE_CONFIG_PATH} could not be created."
    exit 1
fi
echo "INFO: ${EFFECTIVE_CONFIG_PATH} is ready for updates."

# 3. Update settings from environment variables
echo "INFO: Applying environment variable configurations..."

# General
if [ -n "$BRICKSYNC_AUTOCHECK" ]; then update_config "autocheck" "$BRICKSYNC_AUTOCHECK" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

# BrickLink
if [ -n "$BRICKSYNC_BRICKLINK_CONSUMERKEY" ]; then update_config "bricklink.consumerkey" "$BRICKSYNC_BRICKLINK_CONSUMERKEY" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_CONSUMERSECRET" ]; then update_config "bricklink.consumersecret" "$BRICKSYNC_BRICKLINK_CONSUMERSECRET" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_TOKEN" ]; then update_config "bricklink.token" "$BRICKSYNC_BRICKLINK_TOKEN" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_TOKENSECRET" ]; then update_config "bricklink.tokensecret" "$BRICKSYNC_BRICKLINK_TOKENSECRET" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKLINK_FAILINTERVAL" ]; then update_config "bricklink.failinterval" "$BRICKSYNC_BRICKLINK_FAILINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKLINK_POLLINTERVAL" ]; then update_config "bricklink.pollinterval" "$BRICKSYNC_BRICKLINK_POLLINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

# BrickOwl
if [ -n "$BRICKSYNC_BRICKOWL_KEY" ]; then update_config "brickowl.key" "$BRICKSYNC_BRICKOWL_KEY" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_BRICKOWL_FAILINTERVAL" ]; then update_config "brickowl.failinterval" "$BRICKSYNC_BRICKOWL_FAILINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_POLLINTERVAL" ]; then update_config "brickowl.pollinterval" "$BRICKSYNC_BRICKOWL_POLLINTERVAL" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

# Price Guide
if [ -n "$BRICKSYNC_PRICEGUIDE_CACHEPATH" ]; then
    update_config "priceguide.cachepath" "$BRICKSYNC_PRICEGUIDE_CACHEPATH" "${EFFECTIVE_CONFIG_PATH}"
    echo "INFO: Ensuring price guide cache path directory exists for user-defined path: $BRICKSYNC_PRICEGUIDE_CACHEPATH"
    mkdir -p "$(dirname "$BRICKSYNC_PRICEGUIDE_CACHEPATH")"
    echo "INFO: Directory check/creation for $BRICKSYNC_PRICEGUIDE_CACHEPATH completed."
else
    DEFAULT_PG_CACHE_PATH=$(grep '^priceguide.cachepath' "${EFFECTIVE_CONFIG_PATH}" | cut -d '=' -f2 | xargs)
    if [ -n "${DEFAULT_PG_CACHE_PATH}" ]; then
        echo "INFO: Ensuring default price guide cache path directory exists: ${DEFAULT_PG_CACHE_PATH}"
        mkdir -p "$(dirname "${DEFAULT_PG_CACHE_PATH}")"
        echo "INFO: Directory check/creation for ${DEFAULT_PG_CACHE_PATH} completed."
    else
        echo "WARN: No priceguide.cachepath defined in config or via BRICKSYNC_PRICEGUIDE_CACHEPATH."
    fi
fi
if [ -n "$BRICKSYNC_PRICEGUIDE_CACHEFORMAT" ]; then update_config "priceguide.cacheformat" "$BRICKSYNC_PRICEGUIDE_CACHEFORMAT" "${EFFECTIVE_CONFIG_PATH}"; fi
if [ -n "$BRICKSYNC_PRICEGUIDE_CACHETIME" ]; then update_config "priceguide.cachetime" "$BRICKSYNC_PRICEGUIDE_CACHETIME" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

# Advanced
if [ -n "$BRICKSYNC_RETAINEMPTYLOTS" ]; then update_config "retainemptylots" "$BRICKSYNC_RETAINEMPTYLOTS" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_REUSEEMPTY" ]; then update_config "brickowl.reuseempty" "$BRICKSYNC_BRICKOWL_REUSEEMPTY" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_CHECKMESSAGE" ]; then update_config "checkmessage" "$BRICKSYNC_CHECKMESSAGE" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKLINK_PIPELINEQUEUE" ]; then update_config "bricklink.pipelinequeue" "$BRICKSYNC_BRICKLINK_PIPELINEQUEUE" "${EFFECTIVE_CONFIG_PATH}" "true"; fi
if [ -n "$BRICKSYNC_BRICKOWL_PIPELINEQUEUE" ]; then update_config "brickowl.pipelinequeue" "$BRICKSYNC_BRICKOWL_PIPELINEQUEUE" "${EFFECTIVE_CONFIG_PATH}" "true"; fi

echo "INFO: All environment variable processing complete."
echo "--- Final effective bricksync.conf (${EFFECTIVE_CONFIG_PATH}) ---"
cat "${EFFECTIVE_CONFIG_PATH}"
echo "---------------------------------------------------------"

# 4. Execute bricksync
echo "INFO: Starting bricksync application with arguments: $@"
exec "${EXECUTABLE_PATH}" "$@"
