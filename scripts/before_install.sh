#!/bin/bash
echo "Running before_install.sh..."

# Ensure the ubuntu user has ownership of the entire app directory
sudo chown -R ubuntu:ubuntu /home/ubuntu/myapp

# Now safely remove previous deployment if needed
rm -rf /home/ubuntu/myapp/nodejsapp/node_modules
rm -f /home/ubuntu/myapp/nodejsapp/package-lock.json

echo "before_install.sh completed"