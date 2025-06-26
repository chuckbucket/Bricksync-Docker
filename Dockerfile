# Stage 1: Builder for bricksync (modified to use Debian Bullseye)
FROM buildpack-deps:bullseye-scm AS builder

# Install build dependencies for bricksync on Bullseye
# gcc, make etc. are included in buildpack-deps
RUN apt-get update && apt-get install -y libssl-dev

WORKDIR /app
COPY . /app

# Compile bricksync application
RUN gcc -std=gnu99 -m64 cpuconf.c cpuinfo.c -O2 -s -o cpuconf && \
    ./cpuconf -h && \
    gcc -std=gnu99 -m64 bricksync.c bricksyncconf.c bricksyncnet.c bricksyncinit.c bricksyncinput.c bsantidebug.c bsmessage.c bsmathpuzzle.c bsorder.c bsregister.c bsapihistory.c bstranslation.c bsevalgrade.c bsoutputxml.c bsorderdir.c bspriceguide.c bsmastermode.c bscheck.c bssync.c bsapplydiff.c bsfetchorderinv.c bsresolve.c bscatedit.c bsfetchinv.c bsfetchorderlist.c bsfetchset.c bscheckreg.c bsfetchpriceguide.c tcp.c vtlex.c cpuinfo.c antidebug.c mm.c mmhash.c mmbitmap.c cc.c ccstr.c debugtrack.c tcphttp.c oauth.c bricklink.c brickowl.c brickowlinv.c colortable.c json.c bsx.c bsxpg.c journal.c exclperm.c iolog.c crypthash.c cryptsha1.c rand.c bn512.c bn1024.c rsabn.c -O2 -s -fvisibility=hidden -o bricksync -lm -lpthread -lssl -lcrypto

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
    libssl1.1 \
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
COPY entrypoint.sh /src/entrypoint.sh
RUN chmod +x /src/entrypoint.sh

# give every user read write access to the "/root" folder where the binary is cached (from user example)
RUN ls -la /root
RUN chmod 777 /root

RUN groupadd -g 61000 dockeruser; \
    useradd -g 61000 -l -m -s /bin/bash -u 61000 dockeruser

# COPY assets/config/ /home/dockeruser/.config # User-provided assets folder, comment out as it's not in the repo

# Create /app directory for bricksync and related files
RUN mkdir -p /app

# Copy compiled application and default config from builder stage
COPY --from=builder /app/bricksync /app/bricksync
# Default/template config for bricksync
COPY --from=builder /app/bricksync.conf.txt /app/bricksync.conf.txt

RUN chown -R dockeruser:dockeruser /home/dockeruser /app && \
    chmod -R 777 /home/dockeruser && \
    # chmod u+rwx /app && # Not strictly needed as dockeruser owns /app now
    adduser dockeruser sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER dockeruser
# versions of local tools
RUN echo  "debian version:  $(cat /etc/debian_version) \n" \
          "user:            $(whoami) \n"

WORKDIR /app # Set WORKDIR to /app, which is owned by dockeruser

#Expose port 5901 to view display using VNC Viewer
EXPOSE 5901 6901
ENTRYPOINT ["/src/entrypoint.sh"]
