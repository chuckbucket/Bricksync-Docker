# Stage 1: Builder for bricksync (modified to use Debian Bullseye)
FROM buildpack-deps:bullseye-scm AS builder

# Install build dependencies for bricksync on Bullseye
# gcc, make etc. are included in buildpack-deps
# libssl-dev is removed as we will build OpenSSL from source
RUN apt-get update && apt-get install -y wget make gcc perl

WORKDIR /app

# Download and compile OpenSSL
RUN wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz && \
    tar -xf openssl-1.1.1w.tar.gz && \
    cd openssl-1.1.1w && \
    ./config no-shared no-threads --prefix=/usr/local --openssldir=/usr/local && \
    make -j$(nproc) && \
    make install_sw && \
    cd .. && \
    rm -rf openssl-1.1.1w openssl-1.1.1w.tar.gz

COPY . /app

# Compile bricksync application
# Statically link OpenSSL by pointing to the custom compiled libraries
# and adding -ldl for dlopen used by OpenSSL
RUN gcc -std=gnu99 -m64 cpuconf.c cpuinfo.c -O2 -s -o cpuconf && \
    ./cpuconf -h && \
    gcc -std=gnu99 -m64 bricksync.c bricksyncconf.c bricksyncnet.c bricksyncinit.c bricksyncinput.c bsantidebug.c bsmessage.c bsmathpuzzle.c bsorder.c bsregister.c bsapihistory.c bstranslation.c bsevalgrade.c bsoutputxml.c bsorderdir.c bspriceguide.c bsmastermode.c bscheck.c bssync.c bsapplydiff.c bsfetchorderinv.c bsresolve.c bscatedit.c bsfetchinv.c bsfetchorderlist.c bsfetchset.c bscheckreg.c bsfetchpriceguide.c tcp.c vtlex.c cpuinfo.c antidebug.c mm.c mmhash.c mmbitmap.c cc.c ccstr.c debugtrack.c tcphttp.c oauth.c bricklink.c brickowl.c brickowlinv.c colortable.c json.c bsx.c bsxpg.c journal.c exclperm.c iolog.c crypthash.c cryptsha1.c rand.c bn512.c bn1024.c rsabn.c -O2 -s -fvisibility=hidden -I/usr/local/include -o bricksync -lm -lpthread /usr/local/lib/libssl.a /usr/local/lib/libcrypto.a -ldl

# Stage 2: Main application image (reverted to Debian 11 Bullseye)
FROM debian:11.1-slim

ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901 \
    VNC_COL_DEPTH=32 \
    VNC_RESOLUTION=1920x1080

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    xvfb xauth dbus-x11 xfce4 xfce4-terminal \
    wget sudo curl gpg git bzip2 vim procps python x11-xserver-utils \
    nano \
    libnss3 libnspr4 libasound2 libgbm1 ca-certificates fonts-liberation xdg-utils \
    tigervnc-standalone-server tigervnc-common firefox-esr; \
    curl http://ftp.us.debian.org/debian/pool/main/liba/libappindicator/libappindicator3-1_0.4.92-7_amd64.deb --output /opt/libappindicator3-1_0.4.92-7_amd64.deb && \
    curl http://ftp.us.debian.org/debian/pool/main/libi/libindicator/libindicator3-7_0.5.0-4_amd64.deb --output /opt/libindicator3-7_0.5.0-4_amd64.deb && \
    apt-get install -y /opt/libappindicator3-1_0.4.92-7_amd64.deb /opt/libindicator3-7_0.5.0-4_amd64.deb && \
    \
    echo "Installing noVNC and websockify..." && \
    git clone --branch v1.2.0 --single-branch https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --branch v0.9.0 --single-branch https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    \
    rm -vf /opt/lib*.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ENV TERM=xterm
# The noVNC installation commands have been moved into the main RUN block that installs packages.

# disable shared memory X11 affecting Chromium
ENV QT_X11_NO_MITSHM=1 \
    _X11_NO_MITSHM=1 \
    _MITSHM=0

RUN mkdir /src # Create /src directory

# Copy entrypoint script and make it executable (as root)
COPY docker/entrypoint.sh /src/entrypoint.sh
RUN chmod +x /src/entrypoint.sh

# give every user read write access to the "/root" folder where the binary is cached (from user example)
RUN ls -la /root
RUN chmod 777 /root

RUN groupadd -g 61000 dockeruser; \
    useradd -g 61000 -l -m -s /bin/bash -u 61000 dockeruser

# Switch to root to create system-level directories and set up autostart
USER root

# Create /app directory for bricksync and related files
# This needs to be done as root if it's directly under /
RUN mkdir -p /app

# Create autostart directory for dockeruser and set its ownership immediately
RUN mkdir -p /home/dockeruser/.config/autostart/ && \
    chown dockeruser:dockeruser /home/dockeruser/.config/autostart/

# Copy the .desktop file for bricksync in terminal
# Ensure 'bricksync-terminal.desktop' exists in your Docker build context (same dir as Dockerfile)
COPY docker/bricksync-terminal.desktop /home/dockeruser/.config/autostart/bricksync-terminal.desktop
RUN chown dockeruser:dockeruser /home/dockeruser/.config/autostart/bricksync-terminal.desktop && \
    chmod 644 /home/dockeruser/.config/autostart/bricksync-terminal.desktop

# Copy compiled application and default config from builder stage
COPY --from=builder /app/bricksync /app/bricksync
COPY --from=builder /app/bricksync.conf.txt /app/bricksync.conf.txt

# Set ownership for /app and /home/dockeruser, and sudo permissions
# Note: /home/dockeruser is already created by useradd -m, 
# chown here ensures all contents including .config/autostart are correct if not already.
RUN chown -R dockeruser:dockeruser /home/dockeruser && \
    chown -R dockeruser:dockeruser /app && \
    chmod -R 777 /home/dockeruser && \
    adduser dockeruser sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to dockeruser for subsequent commands and runtime
USER dockeruser

USER root
RUN mkdir -p /home/dockeruser/Desktop && \
    chown dockeruser:dockeruser /home/dockeruser/Desktop && \
    chmod 755 /home/dockeruser/Desktop

# Copy the GitHub link .desktop file to the user's Desktop
# Make sure 'BricksyncGitHub.desktop' is in your build context (same dir as Dockerfile)
COPY docker/BricksyncGitHub.desktop /home/dockeruser/Desktop/BricksyncGitHub.desktop
RUN chown dockeruser:dockeruser /home/dockeruser/Desktop/BricksyncGitHub.desktop && \
    chmod 644 /home/dockeruser/Desktop/BricksyncGitHub.desktop

# Switch back to dockeruser if not already the active user for subsequent RUN commands or final USER
USER dockeruser


# COPY assets/config/ /home/dockeruser/.config # User-provided assets folder, comment out as it's not in the repo

# versions of local tools
RUN echo  "debian version:  $(cat /etc/debian_version) \n" \
          "user:            $(whoami) \n"

WORKDIR /app

#Expose port 5901 to view display using VNC Viewer
EXPOSE 5901 6901
ENTRYPOINT ["/src/entrypoint.sh"]
