#!/bin/bash
echo "Running InstallDependencies Script"

# Update packages
sudo apt-get update -y

# Example dependencies for Node.js app
sudo apt-get install -y nodejs npm

# Navigate to app directory and install dependencies
cd /home/ubuntu/myapp
npm install