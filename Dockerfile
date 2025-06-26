# Stage 1: Builder for bricksync
FROM gcc:latest AS builder

# Install build dependencies for bricksync
RUN apt-get update && apt-get install -y libssl-dev

WORKDIR /app
COPY . /app

# Compile bricksync application
RUN gcc -std=gnu99 -m64 cpuconf.c cpuinfo.c -O2 -s -o cpuconf && \
    ./cpuconf -h && \
    gcc -std=gnu99 -m64 bricksync.c bricksyncconf.c bricksyncnet.c bricksyncinit.c bricksyncinput.c bsantidebug.c bsmessage.c bsmathpuzzle.c bsorder.c bsregister.c bsapihistory.c bstranslation.c bsevalgrade.c bsoutputxml.c bsorderdir.c bspriceguide.c bsmastermode.c bscheck.c bssync.c bsapplydiff.c bsfetchorderinv.c bsresolve.c bscatedit.c bsfetchinv.c bsfetchorderlist.c bsfetchset.c bscheckreg.c bsfetchpriceguide.c tcp.c vtlex.c cpuinfo.c antidebug.c mm.c mmhash.c mmbitmap.c cc.c ccstr.c debugtrack.c tcphttp.c oauth.c bricklink.c brickowl.c brickowlinv.c colortable.c json.c bsx.c bsxpg.c journal.c exclperm.c iolog.c crypthash.c cryptsha1.c rand.c bn512.c bn1024.c rsabn.c -O2 -s -fvisibility=hidden -o bricksync -lm -lpthread -lssl -lcrypto

# Stage 2: Main application image based on user's specification
FROM debian:11.1-slim

ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901 \
    VNC_COL_DEPTH=32 \
    VNC_RESOLUTION=1920x1080

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive

# Set terminal type
ENV TERM=xterm

# disable shared memory X11 affecting Chromium
ENV QT_X11_NO_MITSHM=1 \
    _X11_NO_MITSHM=1 \
    _MITSHM=0

# User-specified package installation
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    xvfb xauth dbus-x11 xfce4 xfce4-terminal \
    wget sudo curl gpg git bzip2 vim procps python x11-xserver-utils \
    libnss3 libnspr4 libasound2 libgbm1 ca-certificates fonts-liberation xdg-utils \
    tigervnc-standalone-server tigervnc-common firefox-esr; \
    curl http://ftp.us.debian.org/debian/pool/main/liba/libappindicator/libappindicator3-1_0.4.92-7_amd64.deb --output /opt/libappindicator3-1_0.4.92-7_amd64.deb && \
    curl http://ftp.us.debian.org/debian/pool/main/libi/libindicator/libindicator3-7_0.5.0-4_amd64.deb --output /opt/libindicator3-7_0.5.0-4_amd64.deb && \
    apt-get install -y /opt/libappindicator3-1_0.4.92-7_amd64.deb /opt/libindicator3-7_0.5.0-4_amd64.deb; \
    rm -vf /opt/lib*.deb; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# User-specified noVNC installation
RUN     git clone --branch v1.2.0 --single-branch https://github.com/novnc/noVNC.git /opt/noVNC; \
        git clone --branch v0.9.0 --single-branch https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify; \
        ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# Create /app directory for bricksync and related files
RUN mkdir -p /app

# Copy compiled application and default config from builder stage
COPY --from=builder /app/bricksync /app/bricksync
COPY --from=builder /app/bricksync.conf.txt /app/bricksync.conf.txt

# Create directories for scripts, user home, VNC, data, and supervisor logs
RUN mkdir -p /src \
             /home/dockeruser/.vnc \
             /app/data/pgcache \
             /var/log/supervisor \
             /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# Copy helper scripts
COPY entrypoint.sh /src/entrypoint.sh
COPY xstartup /home/dockeruser/.vnc/xstartup # For VNC session startup
# vncserver_start.sh removed, logic merged into entrypoint.sh
# COPY supervisord.conf /etc/supervisor/supervisord.conf # Remains removed

# User setup (User Specified)
RUN ls -la /root
RUN chmod 777 /root # Note: Broad permissions

RUN groupadd -g 61000 dockeruser; \
    useradd -g 61000 -l -m -s /bin/bash -u 61000 dockeruser

# Post user-creation ownership and permissions
RUN chown -R dockeruser:dockeruser /home/dockeruser && \
    chown dockeruser:dockeruser /app && \
    chown -R dockeruser:dockeruser /app/data && \
    chmod -R u+rwx /app/data && \
    chmod +x /src/entrypoint.sh \
             /home/dockeruser/.vnc/xstartup

RUN chown -R dockeruser:dockeruser /home/dockeruser;\
    chmod -R 777 /home/dockeruser ;\
    # Sudo permissions for dockeruser
    adduser dockeruser sudo;\
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER dockeruser

# versions of local tools (as per user's Dockerfile)
RUN echo  "debian version:  $(cat /etc/debian_version) \n" \
          "user:            $(whoami) \n"

WORKDIR /app

EXPOSE 5901 6901
ENTRYPOINT ["/src/entrypoint.sh"]
CMD []
