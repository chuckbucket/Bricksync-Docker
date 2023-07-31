# Use the Alpine Linux base image
FROM alpine:latest

# Set the working directory
WORKDIR /data

# Install required dependencies
RUN apk add --no-cache git

# Clone Bricksync from GitHub
RUN git clone https://github.com/chuckbucket/Bricksync-Docker .

# Copy the configuration template to the container
COPY /data/bricksync.conf.template /data/bricksync.conf.template
COPY bricksync /bricksync

# Set environment variables for Bricklink and BrickOwl credentials
ENV BRICKLINK_CONSUMER_KEY ""
ENV BRICKLINK_CONSUMER_SECRET ""
ENV BRICKLINK_TOKEN ""
ENV BRICKLINK_TOKEN_SECRET ""
ENV BRICKOWL_KEY ""

# Create the final bricksync.conf.txt file by replacing placeholders with environment variables
CMD sed -e "s|{BRICKLINK_CONSUMER_KEY}|$BRICKLINK_CONSUMER_KEY|" \
        -e "s|{BRICKLINK_CONSUMER_SECRET}|$BRICKLINK_CONSUMER_SECRET|" \
        -e "s|{BRICKLINK_TOKEN}|$BRICKLINK_TOKEN|" \
        -e "s|{BRICKLINK_TOKEN_SECRET}|$BRICKLINK_TOKEN_SECRET|" \
        -e "s|{BRICKOWL_KEY}|$BRICKOWL_KEY|" \
        /data/bricksync.conf.template > /data/bricksync.conf.txt && ./bricksync --config bricksync.conf.txt

RUN bricksync