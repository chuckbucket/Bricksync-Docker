#!/bin/sh
set -e

# VNC Server Configuration
VNC_DISPLAY="${VNC_DISPLAY:-:1}"
VNC_DISPLAY_NUM=$(echo "${VNC_DISPLAY}" | cut -d':' -f2)
VNC_GEOMETRY="${VNC_GEOMETRY:-1280x1024}" # Default screen resolution
VNC_DEPTH="${VNC_DEPTH:-24}" # Default color depth
VNC_PASSWORD="${VNC_PASSWORD}" # Mandatory: user must set this environment variable

# User under which VNC and Xfce will run (must match supervisord.conf and user created in Dockerfile)
# This script is run by supervisor as 'appuser', so USER and HOME should be correctly set by supervisor.
# If not, uncomment and set:
# APP_USER="appuser"
# CURRENT_USER_HOME="/home/${APP_USER}" # Renamed from HOME to avoid conflict if supervisor sets HOME

# If supervisor doesn't set HOME reliably for the script's environment itself,
# but sets it for the command's environment, we might need to derive it or pass APP_USER.
# For now, assume HOME is correctly set by supervisor's environment directive for the program.
if [ -z "${HOME}" ]; then
  echo "ERROR: HOME environment variable is not set. Cannot determine user's home directory."
  exit 1
fi

XSTARTUP_PATH="${HOME}/.vnc/xstartup"

# Check if VNC_PASSWORD is set
if [ -z "${VNC_PASSWORD}" ]; then
  echo "ERROR: VNC_PASSWORD environment variable is not set."
  echo "Please set it to secure your VNC server."
  exit 1
fi

# Create .vnc directory if it doesn't exist
mkdir -p "${HOME}/.vnc"

# Create VNC password file
echo "${VNC_PASSWORD}" | vncpasswd -f > "${HOME}/.vnc/passwd"
chmod 600 "${HOME}/.vnc/passwd"

# Ensure xstartup script exists and is executable (will be created in another step)
if [ ! -f "${XSTARTUP_PATH}" ]; then
    echo "ERROR: ${XSTARTUP_PATH} not found. Please ensure it's created and populated."
    # Create a minimal one if it's missing, just to allow VNC server to start for debugging
    # but the real one should launch Xfce and the terminal.
    echo "#!/bin/sh" > "${XSTARTUP_PATH}"
    echo "unset SESSION_MANAGER" >> "${XSTARTUP_PATH}"
    echo "unset DBUS_SESSION_BUS_ADDRESS" >> "${XSTARTUP_PATH}"
    echo "echo 'Minimal xstartup: Xfce not configured to start via this minimal xstartup!'" >> "${XSTARTUP_PATH}"
    echo "xsetroot -solid grey" >> "${XSTARTUP_PATH}"
    echo "xterm &" >> "${XSTARTUP_PATH}" # Fallback to xterm if xfce4-terminal not found or xfce not started
    chmod +x "${XSTARTUP_PATH}"
    echo "WARNING: Created a minimal fallback ${XSTARTUP_PATH}. You need to create the proper one."
elif [ ! -x "${XSTARTUP_PATH}" ]; then
    echo "WARNING: ${XSTARTUP_PATH} is not executable. Setting it now."
    chmod +x "${XSTARTUP_PATH}"
fi

# Clean up any old VNC server locks or sockets for this display
# Xtigervnc usually handles this, but good practice for robustness
VNCLOCK="/tmp/.X${VNC_DISPLAY_NUM}-lock"
X11SOCK="/tmp/.X11-unix/X${VNC_DISPLAY_NUM}"
rm -f "${VNCLOCK}" "${X11SOCK}"

echo "Starting Xtigervnc on display ${VNC_DISPLAY} with geometry ${VNC_GEOMETRY}..."
# Run Xtigervnc in the foreground for supervisor
# -localhost no: Allow connections from non-localhost (needed for websockify from same container, and direct VNC)
# -SecurityTypes VncAuth: Use standard VNC password authentication
# -PasswordFile: Points to the VNC password file
# -fg: Run in foreground
# -desktop: Name for the VNC desktop (optional)
# The xstartup script at $HOME/.vnc/xstartup will be executed to start the desktop environment
exec /usr/bin/Xtigervnc "${VNC_DISPLAY}" \
  -geometry "${VNC_GEOMETRY}" \
  -depth "${VNC_DEPTH}" \
  -localhost no \
  -SecurityTypes VncAuth \
  -PasswordFile "${HOME}/.vnc/passwd" \
  -fg \
  -desktop "BrickSyncDesktop" \
  -xstartup "${XSTARTUP_PATH}" \
  -Log "*:stderr:100" # Log verbosely to stderr for supervisor to capture. Changed from -verbose.
