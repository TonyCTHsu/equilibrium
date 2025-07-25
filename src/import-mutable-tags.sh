#!/bin/bash
set -e

if [ $# -eq 0 ]; then
  echo "Usage: $0 <registry/image>"
  echo "Example: $0 gcr.io/datadoghq/apm-inject"
  exit 1
fi

REGISTRY="$1"

# Create a safe directory name from registry path
SAFE_NAME=${REGISTRY//[^a-zA-Z0-9]/_}
OUTPUT_DIR="fixtures/$SAFE_NAME"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Store original registry name for test filtering
echo "$REGISTRY" > "$OUTPUT_DIR/registry.txt"

# Remove canonical tags and v-prefixed tags
gcloud container images list-tags "$REGISTRY" \
  --filter="tags:*" \
  --flatten="tags" \
  --format=json | \
  jq 'map({(.tags): .digest}) | add' | \
  jq 'with_entries(select(.key | (test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$") | not) and (test("^v") | not))) |
      to_entries |
      sort_by(.key) |
      reverse |
      from_entries' > "$OUTPUT_DIR/actual_mutable_tags.json"
