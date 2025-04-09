#!/bin/bash
echo "Stopping any running Node.js app..."

# Stop the app (if running)
pkill node || true