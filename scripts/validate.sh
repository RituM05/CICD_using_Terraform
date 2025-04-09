#!/bin/bash
echo "Running ValidateService Script"

# Health check
curl -f http://localhost:8080 || exit 1
