#!/bin/bash
set -e

# Script to validate a single registry for equilibrium
# Usage: ./.github/scripts/validate-registry.sh <registry-url> <file-suffix>
# Example: ./.github/scripts/validate-registry.sh gcr.io/datadoghq/apm-inject inject

if [ $# -ne 2 ]; then
    echo "Usage: $0 <registry-url> <file-suffix>"
    echo "Example: $0 gcr.io/datadoghq/apm-inject inject"
    exit 1
fi

REGISTRY="$1"
FILE_SUFFIX="$2"
REGISTRY_NAME=$(basename "$REGISTRY")

echo "🔍 Validating $REGISTRY..."

# Generate expected, actual, and analysis files
bundle exec ./equilibrium expected "$REGISTRY" --format json > "expected-$FILE_SUFFIX.json"
bundle exec ./equilibrium actual "$REGISTRY" --format json > "actual-$FILE_SUFFIX.json"
bundle exec ./equilibrium analyze --expected "expected-$FILE_SUFFIX.json" --actual "actual-$FILE_SUFFIX.json" --format json > "analysis-$FILE_SUFFIX.json"

# Display results
echo "📊 Analysis Results for $REGISTRY_NAME:"
cat "analysis-$FILE_SUFFIX.json" | jq '.'

# Check if registry is in equilibrium
status=$(cat "analysis-$FILE_SUFFIX.json" | jq -r '.status')
if [ "$status" != "perfect" ]; then
    echo "❌ Registry $REGISTRY_NAME is NOT in equilibrium (status: $status)"
    echo "📋 Remediation plan:"
    cat "analysis-$FILE_SUFFIX.json" | jq -r '.remediation_plan[].command'
    exit 1
else
    echo "✅ Registry $REGISTRY_NAME is in perfect equilibrium!"
fi