# Use the Alpine Linux base image
FROM alpine:latest

# Set the working directory
WORKDIR /app

# Install required dependencies
#RUN apk add --no-cache git

# Copy the configuration template and entrypoint script to the container
COPY DockerFiles/ ./
COPY entrypoint.sh ./

# Set environment variables for Bricklink and BrickOwl credentials
ENV BRICKLINK_CONSUMER_KEY ""
ENV BRICKLINK_CONSUMER_SECRET ""
ENV BRICKLINK_TOKEN ""
ENV BRICKLINK_TOKEN_SECRET ""
ENV BRICKOWL_KEY ""

# Print some debugging information
RUN echo "Getting Ready to replace keys:"
RUN ls -R .
RUN cat data/bricksync.conf.txt.template

# Set the entrypoint script
CMD ["./entrypoint.sh"]
