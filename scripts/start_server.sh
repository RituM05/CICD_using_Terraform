#!/bin/bash
echo "Starting server..."
cd /home/ubuntu/myapp/nodejsapp

# Ensure node_modules is present
npm install

# Start the app in background
nohup npm start > app.log 2>&1 &