#!/bin/bash
echo "Running BeforeInstall..."

# Ensure ownership and clean any existing deployment folder
sudo rm -rf /home/ubuntu/myapp
mkdir -p /home/ubuntu/myapp