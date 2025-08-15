#!/bin/bash
set -e

# Script to validate a single registry for equilibrium
# Usage: ./.github/scripts/validate-registry.sh <registry-url> <file-suffix> [temp-dir]
# Example: ./.github/scripts/validate-registry.sh gcr.io/datadoghq/apm-inject inject

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <registry-url> <file-suffix> [temp-dir]"
    echo "Example: $0 gcr.io/datadoghq/apm-inject inject"
    exit 1
fi

REGISTRY="$1"
FILE_SUFFIX="$2"
REGISTRY_NAME=$(basename "$REGISTRY")

# Use provided temp directory or create one
if [ $# -eq 3 ]; then
    TEMP_DIR="$3"
else
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
fi

echo "🔍 Validating $REGISTRY..."

# Generate expected, actual, and analysis files in temp directory
bundle exec ./equilibrium expected "$REGISTRY" --format json > "$TEMP_DIR/expected-$FILE_SUFFIX.json"
bundle exec ./equilibrium actual "$REGISTRY" --format json > "$TEMP_DIR/actual-$FILE_SUFFIX.json"

# Test catalog roundtrip conversion: expected -> catalog -> uncatalog
bundle exec ./equilibrium catalog < "$TEMP_DIR/expected-$FILE_SUFFIX.json" > "$TEMP_DIR/catalog-$FILE_SUFFIX.json"
bundle exec ./equilibrium uncatalog "$TEMP_DIR/catalog-$FILE_SUFFIX.json" > "$TEMP_DIR/uncatalog-$FILE_SUFFIX.json"

bundle exec ./equilibrium analyze --expected "$TEMP_DIR/expected-$FILE_SUFFIX.json" --actual "$TEMP_DIR/actual-$FILE_SUFFIX.json" --format json > "$TEMP_DIR/analysis-$FILE_SUFFIX.json"

# Verify roundtrip conversion
echo "🔄 Verifying catalog roundtrip conversion..."
if diff -q "$TEMP_DIR/expected-$FILE_SUFFIX.json" "$TEMP_DIR/uncatalog-$FILE_SUFFIX.json" >/dev/null; then
    echo "✅ Catalog roundtrip conversion successful"
else
    echo "❌ Catalog roundtrip conversion failed - files differ"
    echo "Expected vs Uncatalog diff:"
    diff "$TEMP_DIR/expected-$FILE_SUFFIX.json" "$TEMP_DIR/uncatalog-$FILE_SUFFIX.json" || true
    exit 1
fi

# Display results
echo "📊 Analysis Results for $REGISTRY_NAME:"
jq '.' < "$TEMP_DIR/analysis-$FILE_SUFFIX.json"

echo "📋 Catalog Format:"
jq '.' < "$TEMP_DIR/catalog-$FILE_SUFFIX.json"

# Check if registry is in equilibrium
status=$(jq -r '.status' < "$TEMP_DIR/analysis-$FILE_SUFFIX.json")
if [ "$status" != "perfect" ]; then
    echo "❌ Registry $REGISTRY_NAME is NOT in equilibrium (status: $status)"
    echo "📋 Remediation plan:"
    jq -r '.remediation_plan[].command' < "$TEMP_DIR/analysis-$FILE_SUFFIX.json"
    exit 1
else
    echo "✅ Registry $REGISTRY_NAME is in perfect equilibrium!"
fi