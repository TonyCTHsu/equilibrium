#!/bin/bash
set -e

if [ $# -eq 0 ]; then
  echo "Usage: $0 <registry/image>"
  echo "Example: $0 gcr.io/datadoghq/apm-inject"
  exit 1
fi

REGISTRY="$1"
SAFE_NAME=${REGISTRY//[^a-zA-Z0-9]/_}

echo "Starting Docker image tag validation workflow for $REGISTRY..."
echo "Output directory: fixtures/${SAFE_NAME}/"

# Step 1: Import semantic versioned tags from registry
echo "Step 1: Importing semantic versioned tags..."
./src/import-semantic-tags.sh "$REGISTRY"

# Step 2: Import mutable tags from registry
echo "Step 2: Importing mutable tags..."
./src/import-mutable-tags.sh "$REGISTRY"

# Step 3: Run validation tests
echo "Step 3: Running validation tests..."
bundle exec rspec --example "$REGISTRY"

echo "Workflow completed successfully!"