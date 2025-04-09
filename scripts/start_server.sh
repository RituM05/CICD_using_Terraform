#!/bin/bash
echo "Starting Node.js server..."
cd /home/ubuntu/myapp/nodejsapp
nohup node app.js > app.log 2>&1 &