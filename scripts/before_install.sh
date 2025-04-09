#!/bin/bash
echo "Running BeforeInstall Script"

# Optional: Stop the app if it's already running
pkill -f myapp || true

# Clean old app directory
rm -rf /home/ubuntu/myapp