#!/bin/bash
echo "Starting the Node.js app..."

cd /home/ubuntu/myapp/nodejsapp

# Kill existing Node.js processes if any
pkill node || true

# Start the app in the background
nohup node app.js > /home/ubuntu/app.log 2>&1 &