#!/bin/bash
echo "Running InstallDependencies Script"

# Give ownership to ubuntu user
sudo chown -R ubuntu:ubuntu /home/ubuntu/myapp

# Optional: cleanup (ensure permission first)
rm -rf /home/ubuntu/myapp/nodejsapp/node_modules

# Install dependencies
cd /home/ubuntu/myapp/nodejsapp
npm install