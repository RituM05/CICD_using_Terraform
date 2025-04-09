#!/bin/bash
echo "Running ValidateService Script"

# Wait to allow app startup
sleep 10

# Try curl
curl -f http://localhost:8080
if [ $? -ne 0 ]; then
  echo "App failed health check"
  exit 1
fi

echo "App passed health check"