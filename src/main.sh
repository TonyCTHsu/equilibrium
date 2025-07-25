#!/bin/bash
set -e

# Default registries to process
DEFAULT_REGISTRIES=(
  "gcr.io/datadoghq/apm-inject"
  "gcr.io/datadoghq/dd-lib-java-init"
  "gcr.io/datadoghq/dd-lib-js-init"
  "gcr.io/datadoghq/dd-lib-python-init"
  "gcr.io/datadoghq/dd-lib-dotnet-init"
  "gcr.io/datadoghq/dd-lib-ruby-init"
  "gcr.io/datadoghq/dd-lib-php-init"
)

process_registry() {
  local REGISTRY="$1"
  local SAFE_NAME=${REGISTRY//[^a-zA-Z0-9]/_}

  echo "Starting Docker image tag validation workflow for $REGISTRY..."
  echo "Output directory: fixtures/${SAFE_NAME}/"

  # Step 1: Import semantic versioned tags from registry
  echo "Step 1: Importing semantic versioned tags..."
  ./src/import-semantic-tags.sh "$REGISTRY"

  # Step 2: Import mutable tags from registry
  echo "Step 2: Importing mutable tags..."
  ./src/import-mutable-tags.sh "$REGISTRY"

  echo "Workflow completed for $REGISTRY!"
  echo "---"
}

if [ $# -eq 0 ]; then
  echo "Processing all default registries..."
  for registry in "${DEFAULT_REGISTRIES[@]}"; do
    process_registry "$registry"
  done

  # Run all tests at the end
  echo "Running validation tests for all registries..."
  bundle exec rspec
else
  # Process single registry
  REGISTRY="$1"
  process_registry "$REGISTRY"

  # Run tests for specific registry
  echo "Running validation tests for $REGISTRY..."
  bundle exec rspec --example "$REGISTRY"
fi

echo "All workflows completed successfully!"