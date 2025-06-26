#!/bin/sh
set -e
/usr/bin/echo "vncserver_start.sh: Script started" >&2
/usr/bin/echo "vncserver_start.sh: USER is $(/usr/bin/id -u -n)" >&2
/usr/bin/echo "vncserver_start.sh: UID is $(/usr/bin/id -u)" >&2
/usr/bin/echo "vncserver_start.sh: GID is $(/usr/bin/id -g)" >&2
/usr/bin/echo "vncserver_start.sh: HOME is ${HOME}" >&2
/usr/bin/echo "vncserver_start.sh: PATH is ${PATH}" >&2
/usr/bin/echo "vncserver_start.sh: PWD is $(/bin/pwd)" >&2

/usr/bin/echo "vncserver_start.sh: Listing /app..." >&2
/bin/ls -la /app >&2

/usr/bin/echo "vncserver_start.sh: Listing /usr/bin/Xtigervnc..." >&2
if [ -f /usr/bin/Xtigervnc ]; then
  /bin/ls -la /usr/bin/Xtigervnc >&2
else
  /usr/bin/echo "vncserver_start.sh: /usr/bin/Xtigervnc NOT FOUND" >&2
fi

/usr/bin/echo "vncserver_start.sh: Listing /usr/bin/vncpasswd..." >&2
if [ -f /usr/bin/vncpasswd ]; then
  /bin/ls -la /usr/bin/vncpasswd >&2
else
  /usr/bin/echo "vncserver_start.sh: /usr/bin/vncpasswd NOT FOUND" >&2
fi

/usr/bin/echo "vncserver_start.sh: Attempting to execute Xtigervnc --help" >&2
if /usr/bin/Xtigervnc --help > /dev/null 2>&1; then
  /usr/bin/echo "vncserver_start.sh: Xtigervnc --help executed successfully" >&2
else
  ret_code=$?
  /usr/bin/echo "vncserver_start.sh: Xtigervnc --help FAILED with status ${ret_code}" >&2
fi

# Also test vncpasswd
/usr/bin/echo "vncserver_start.sh: Attempting to execute vncpasswd --help" >&2
if /usr/bin/vncpasswd --help > /dev/null 2>&1; then
    /usr/bin/echo "vncserver_start.sh: vncpasswd --help executed successfully" >&2
else
    ret_code_pw=$?
    /usr/bin/echo "vncserver_start.sh: vncpasswd --help FAILED with status ${ret_code_pw}" >&2
fi


/usr/bin/echo "vncserver_start.sh: Exiting with 0 for debug to prevent supervisor restart loop" >&2
exit 0 # Intentionally exit cleanly for supervisor
