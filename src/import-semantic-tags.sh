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

# Keep only the semantic version complete tags
gcloud container images list-tags "$REGISTRY" \
  --filter="tags:*" \
  --flatten="tags" \
  --format=json | \
  jq 'map({(.tags): .digest}) | add' | \
  jq 'with_entries(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))' > "$OUTPUT_DIR/tag_digest_mapping.json" 

ruby src/compute.rb "$OUTPUT_DIR/tag_digest_mapping.json" "$OUTPUT_DIR/computed_mutable_tags.json" 
