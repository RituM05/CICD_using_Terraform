#!/bin/bash

# Navigate to app directory
cd /home/ec2-user/myapp/nodejsapp

# Kill any process running on port 8080
PORT=8080
PID=$(lsof -t -i:$PORT)
if [ ! -z "$PID" ]; then
  kill -9 $PID
fi

# Start app in background
nohup node app.js > app.log 2>&1 &