#!/bin/sh
set -e

# VNC Server Configuration
VNC_DISPLAY="${VNC_DISPLAY:-:1}"
VNC_DISPLAY_NUM=$(/usr/bin/echo "${VNC_DISPLAY}" | /usr/bin/cut -d':' -f2)
VNC_GEOMETRY="${VNC_GEOMETRY:-1280x1024}" # Default screen resolution
VNC_DEPTH="${VNC_DEPTH:-24}" # Default color depth
VNC_PASSWORD="${VNC_PASSWORD}" # Mandatory: user must set this environment variable

if [ -z "${HOME}" ]; then
  /usr/bin/echo "ERROR: HOME environment variable is not set. Cannot determine user's home directory." >&2
  exit 1
fi

XSTARTUP_PATH="${HOME}/.vnc/xstartup"

if [ -z "${VNC_PASSWORD}" ]; then
  /usr/bin/echo "ERROR: VNC_PASSWORD environment variable is not set." >&2
  /usr/bin/echo "Please set it to secure your VNC server." >&2
  exit 1
fi

/usr/bin/mkdir -p "${HOME}/.vnc"

# Create VNC password file using tigervncpasswd
/usr/bin/echo "Creating VNC password file..." >&2
/usr/bin/echo "${VNC_PASSWORD}" | /usr/bin/tigervncpasswd -f > "${HOME}/.vnc/passwd"
/usr/bin/chmod 600 "${HOME}/.vnc/passwd"
/usr/bin/echo "VNC password file created." >&2

# Ensure xstartup script exists and is executable
if [ ! -f "${XSTARTUP_PATH}" ]; then
    /usr/bin/echo "ERROR: ${XSTARTUP_PATH} not found. This script should have been copied by the Dockerfile." >&2
    # Create a minimal one just in case, though this indicates a build problem
    /usr/bin/echo "#!/bin/sh" > "${XSTARTUP_PATH}"
    /usr/bin/echo "unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS; xsetroot -solid grey; xterm &" >> "${XSTARTUP_PATH}"
    /usr/bin/chmod +x "${XSTARTUP_PATH}"
    /usr/bin/echo "WARNING: Created a minimal fallback ${XSTARTUP_PATH} because the proper one was missing." >&2
elif [ ! -x "${XSTARTUP_PATH}" ]; then
    /usr/bin/echo "WARNING: ${XSTARTUP_PATH} is not executable. Setting it now." >&2
    /usr/bin/chmod +x "${XSTARTUP_PATH}"
fi

# Clean up any old VNC server locks or sockets for this display
VNCLOCK="/tmp/.X${VNC_DISPLAY_NUM}-lock"
X11SOCK="/tmp/.X11-unix/X${VNC_DISPLAY_NUM}"
/usr/bin/echo "Cleaning up old VNC locks and sockets if any..." >&2
/usr/bin/rm -f "${VNCLOCK}" "${X11SOCK}"

/usr/bin/echo "Starting Xtigervnc on display ${VNC_DISPLAY} with geometry ${VNC_GEOMETRY}..." >&2
# Run Xtigervnc in the foreground for supervisor
exec /usr/bin/Xtigervnc "${VNC_DISPLAY}" \
  -geometry "${VNC_GEOMETRY}" \
  -depth "${VNC_DEPTH}" \
  -localhost no \
  -SecurityTypes VncAuth \
  -PasswordFile "${HOME}/.vnc/passwd" \
  -fg \
  -desktop "BrickSyncDesktop" \
  -xstartup "${XSTARTUP_PATH}" \
  -Log "*:stderr:100"
