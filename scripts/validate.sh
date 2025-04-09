#!/bin/bash
echo "Running ValidateService Script..."

MAX_RETRIES=10
SLEEP_SECONDS=3

for (( i=1; i<=MAX_RETRIES; i++ ))
do
  echo "Health check attempt $i..."
  curl -f http://localhost:8080 && break
  echo "App not up yet. Retrying in $SLEEP_SECONDS seconds..."
  sleep $SLEEP_SECONDS
done

if [ $i -eq $MAX_RETRIES ]; then
  echo "App failed health check after $MAX_RETRIES attempts."
  exit 1
fi

echo "App passed health check."