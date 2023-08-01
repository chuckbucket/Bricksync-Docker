# Use the Alpine Linux base image
FROM alpine:latest

# Set the working directory
WORKDIR /app

# Install required dependencies
RUN apk add --no-cache libssl1.1

# Copy the configuration template and entrypoint script to the container
COPY DockerFiles/ ./
COPY Entrypoint.sh ./

# Set environment variables for Bricklink and BrickOwl credentials
ENV BRICKLINK_CONSUMER_KEY "blank"
ENV BRICKLINK_CONSUMER_SECRET "blank"
ENV BRICKLINK_TOKEN "blank"
ENV BRICKLINK_TOKEN_SECRET "blank"
ENV BRICKOWL_KEY "blank"

# Print some debugging information
RUN echo "Getting Ready to replace keys:"

# Set the entrypoint script
CMD ["/app/Entrypoint.sh"]
