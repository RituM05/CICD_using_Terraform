#!/bin/bash

# Exit on error
set -e

# Update & install dependencies
sudo apt-get update -y
sudo apt-get install -y ruby wget

# Go to home directory
cd /home/ubuntu

# Download and install CodeDeploy agent
wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

# Enable and start the CodeDeploy agent
sudo systemctl enable codedeploy-agent
sudo systemctl start codedeploy-agent