#!/bin/sh

echo "ls of root"
ls /

echo "ls of app"
ls -R /app

echo "Hello"
time=$(date)

# Perform the necessary configuration using sed
#sed -e "s|{BRICKLINK_CONSUMER_KEY}|$BRICKLINK_CONSUMER_KEY|" \
#    -e "s|{BRICKLINK_CONSUMER_SECRET}|$BRICKLINK_CONSUMER_SECRET|" \
#    -e "s|{BRICKLINK_TOKEN}|$BRICKLINK_TOKEN|" \
#    -e "s|{BRICKLINK_TOKEN_SECRET}|$BRICKLINK_TOKEN_SECRET|" \
#    -e "s|{BRICKOWL_KEY}|$BRICKOWL_KEY|" \
#    /app/data/bricksync.conf.template > /app/data/bricksync.conf.txt

