# Use an official GCC image as a build environment
FROM gcc:latest AS builder

# Install dependencies
RUN apt-get update && apt-get install -y libssl-dev

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Compile the application
# Adapted from the 'compile' script
RUN gcc -std=gnu99 -m64 cpuconf.c cpuinfo.c -O2 -s -o cpuconf && \
    ./cpuconf -h && \
    gcc -std=gnu99 -m64 bricksync.c bricksyncconf.c bricksyncnet.c bricksyncinit.c bricksyncinput.c bsantidebug.c bsmessage.c bsmathpuzzle.c bsorder.c bsregister.c bsapihistory.c bstranslation.c bsevalgrade.c bsoutputxml.c bsorderdir.c bspriceguide.c bsmastermode.c bscheck.c bssync.c bsapplydiff.c bsfetchorderinv.c bsresolve.c bscatedit.c bsfetchinv.c bsfetchorderlist.c bsfetchset.c bscheckreg.c bsfetchpriceguide.c tcp.c vtlex.c cpuinfo.c antidebug.c mm.c mmhash.c mmbitmap.c cc.c ccstr.c debugtrack.c tcphttp.c oauth.c bricklink.c brickowl.c brickowlinv.c colortable.c json.c bsx.c bsxpg.c journal.c exclperm.c iolog.c crypthash.c cryptsha1.c rand.c bn512.c bn1024.c rsabn.c -O2 -s -fvisibility=hidden -o bricksync -lm -lpthread -lssl -lcrypto

# Use a smaller base image for the final image - changed to bookworm for OpenSSL 3.x
FROM debian:bookworm-slim

# Install runtime dependencies (OpenSSL 3, bash, supervisor)
# curl and ca-certificates are kept for now as Xfce/VNC might need to download things or for general utility.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    libssl3 \    curl \    ca-certificates \    supervisor \    # Xfce and terminal components
    xfce4-session \
    xfce4-panel \
    xfwm4 \
    xfce4-settings \
    xfce4-terminal \
    dbus-x11 \    # Fonts
    xfonts-base \
    xfonts-utils \
    fonts-dejavu-core \    # Other useful X11 utils, might be needed by Xfce or VNC indirectly
    xauth \
    xkb-data \    # TigerVNC server components
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \ # This was the line we fixed
    novnc \
    websockify \    && rm -rf /var/lib/apt/lists/*

# apt-file and its cache are not needed in the final image, so the diagnostic step is removed.
# If further diagnostics are needed, it can be temporarily re-added.

# Create directory for supervisor's log files
RUN mkdir -p /var/log/supervisor

# Create appuser and its home directory
ENV APP_USER_NAME=appuser
ENV APP_USER_HOME=/home/${APP_USER_NAME}
RUN groupadd --gid 1000 ${APP_USER_NAME} || true && \
    useradd --uid 1000 --gid 1000 --shell /bin/bash --create-home ${APP_USER_NAME} && \
    mkdir -p ${APP_USER_HOME}/.vnc && \
    chown -R ${APP_USER_NAME}:${APP_USER_NAME} ${APP_USER_HOME}

# Set user environment variables that might be inherited by VNC session
ENV HOME=${APP_USER_HOME}
ENV USER=${APP_USER_NAME}
ENV LANG=en_US.UTF-8

WORKDIR /app

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Copy VNC startup scripts
COPY vncserver_start.sh /app/vncserver_start.sh
COPY xstartup ${APP_USER_HOME}/.vnc/xstartup
RUN chmod +x /app/vncserver_start.sh && \
    chmod +x ${APP_USER_HOME}/.vnc/xstartup && \
    chown ${APP_USER_NAME}:${APP_USER_NAME} ${APP_USER_HOME}/.vnc/xstartup

# Expose VNC and noVNC default ports
# VNC default for display :1
EXPOSE 5901/tcp
# noVNC default for display :1
EXPOSE 6901/tcp

# Copy the compiled application from the builder stage
COPY --from=builder /app/bricksync /app/bricksync
# Copy the original default config file, the entrypoint script will decide to use it or a user-mounted one
COPY --from=builder /app/bricksync.conf.txt /app/bricksync.conf.txt

# Copy and set up the entrypoint script (this will run before supervisord)
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create and set permissions for the data directory
RUN mkdir -p /app/data/pgcache && \
    chown -R ${APP_USER_NAME}:${APP_USER_NAME} /app/data

# Entrypoint script handles config and then execs supervisord
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command (not strictly necessary as entrypoint execs)
CMD []
