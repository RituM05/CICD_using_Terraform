#!/bin/bash
echo "Running InstallDependencies Script"

# Update packages
sudo apt-get update -y
sudo apt-get install -y nodejs npm

# Fix permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/myapp

# Navigate and install
cd /home/ubuntu/myapp
npm install