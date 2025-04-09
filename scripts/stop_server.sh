#!/bin/bash
echo "Running StopServer Script"

# Stop the app
pkill -f myapp || true