#!/bin/bash
set -e

if [ $# -eq 0 ]; then
  echo "Usage: $0 <registry/image>"
  echo "Example: $0 gcr.io/datadoghq/apm-inject"
  exit 1
fi

REGISTRY="$1"
GCLOUD_CMD=${GCLOUD_CMD:-gcloud}

# Create a safe directory name from registry path
SAFE_NAME=${REGISTRY//[^a-zA-Z0-9]/_}
OUTPUT_DIR="fixtures/$SAFE_NAME"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Store original registry name for test filtering
echo "$REGISTRY" > "$OUTPUT_DIR/registry.txt"

# Keep only the semantic version complete tags
$GCLOUD_CMD container images list-tags "$REGISTRY" \
  --filter="tags:*" \
  --flatten="tags" \
  --format=json | \
  jq 'map({(.tags): .digest}) | add' | \
  jq 'with_entries(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))) |
      to_entries |
      sort_by(.key) |
      reverse |
      from_entries' > "$OUTPUT_DIR/canonical_tags.json"

# Compute the mutable tags from canonical tags
bundle exec ruby src/compute_virtual_tags.rb "$OUTPUT_DIR/canonical_tags.json" "$OUTPUT_DIR/virtual_tags.json"

# Convert to schema format
bundle exec ruby src/build_catalog.rb "$OUTPUT_DIR/virtual_tags.json" "$OUTPUT_DIR/catalog.json" "$REGISTRY"
