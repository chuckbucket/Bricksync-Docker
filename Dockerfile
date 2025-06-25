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

# Use a smaller base image for the final image
FROM debian:bullseye-slim

# Install runtime dependencies (OpenSSL)
RUN apt-get update && apt-get install -y libssl1.1 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled application and the default config from the builder stage
COPY --from=builder /app/bricksync /app/bricksync
COPY --from=builder /app/bricksync.conf.txt /app/bricksync.conf

# Create the data directory mentioned in bricksync.conf.txt for priceguide.cachepath
RUN mkdir -p data/pgcache

# Expose any ports if necessary (bricksync seems to be a CLI tool, so likely none needed for direct connections)

# Set the entrypoint
ENTRYPOINT ["/app/bricksync"]

# Users can mount their own bricksync.conf to /app/bricksync.conf
# CMD can be used to pass arguments to bricksync if needed, e.g. CMD ["--help"]
