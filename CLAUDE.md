# Equilibrium

A Docker image tag validation tool that ensures equilibrium between computed and actual mutable tags.

## Overview

When container images are published with semantic versioning (e.g., `1.2.3`), registries often create corresponding mutable tags like `latest`, `1`, `1.2`, etc. This tool validates that these mutable tags correctly point to their expected semantic versions by:

1. **Fetching actual mutable tags** from the container registry
2. **Computing expected mutable tags** from semantic versions
3. **Validating equilibrium** between actual vs expected mappings

## Quick Start

```bash
# Setup
bundle install
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Set registry to validate
REGISTRY="gcr.io/datadoghq/apm-inject"

# Run validation
./src/main.sh $REGISTRY

# View results
bundle exec rspec spec/
```

## Architecture

### Components

- **`src/main.sh`** - Main orchestration script
- **`src/import-semantic-tags.sh`** - Fetches semantic version tags from registry
- **`src/import-mutable-tags.sh`** - Fetches mutable tags from registry
- **`src/compute.rb`** - Computes expected mutable tag mappings
- **`spec/equilibrium_spec.rb`** - Validates equilibrium between actual vs computed

### Data Flow

```
Registry Tags → Semantic Filter → Compute Mutable → Compare
                     ↓              ↓            ↓
              semantic_versions → expected_mutable → Equilibrium
                     ↓                              ↗ Validation
              Direct Mutable Fetch → actual_mutable
```

### Output Structure

```
fixtures/
└── {registry_name}/
    ├── semantic_versions.json      # Semantic versions from registry
    ├── actual_mutable_tags.json    # Actual mutable tags from registry
    └── expected_mutable_tags.json  # Expected mutable tag mappings
```

## Usage

### Basic Workflow

```bash
# Set registry to validate
REGISTRY="gcr.io/datadoghq/apm-inject"

# Validate the registry
./src/main.sh $REGISTRY

# Run tests for all fixtures
bundle exec rspec spec/

# Check specific registry results
ls fixtures/gcr_io_datadoghq_apm_inject/
```

### Individual Commands

```bash
# Set registry to work with
REGISTRY="gcr.io/datadoghq/apm-inject"

# Fetch semantic tags and compute mappings
./src/import-semantic-tags.sh $REGISTRY

# Fetch actual mutable tags
./src/import-mutable-tags.sh $REGISTRY

# Compute mappings from existing semantic data
ruby src/compute.rb fixtures/gcr_io_datadoghq_apm_inject/semantic_versions.json
```

## Development

### Prerequisites

- **Ruby** with Bundler
- **gcloud CLI** with registry access permissions
- **jq** for JSON processing
- **shellcheck** (optional, for linting)

### Setup

```bash
# Install dependencies
bundle install

# Configure gcloud
gcloud auth login

# Set registry for testing
REGISTRY="gcr.io/datadoghq/apm-inject"

# Verify access
gcloud container images list-tags $REGISTRY --limit=1
```

### Testing

**Important**: Data must be fetched and ready before running tests. Generate fixtures first using `./src/main.sh` with your target registry.

```bash
# Set registry for testing
REGISTRY="gcr.io/datadoghq/apm-inject"

# Generate test data first
./src/main.sh $REGISTRY

# Run all tests
bundle exec rspec

# Test specific registry (after generating fixtures)
bundle exec rspec --example "gcr.io/datadoghq/apm-inject"
```

### Code Quality

```bash
# Ruby linting
bundle exec standardrb
bundle exec standardrb --fix

# Shell script linting
shellcheck src/*.sh
```

## Examples

### Supported Registries

This tool works with Google Container Registry (GCR) and Artifact Registry:

```bash
./src/main.sh "gcr.io/datadoghq/apm-inject"
./src/main.sh "gcr.io/datadoghq/dd-lib-ruby-init"
...

```

### Expected Mutable Tag Logic

For semantic versions like `0.42.1`, `0.42.0`, `0.41.5`, the tool computes:

- **`latest`** → highest overall version (`0.42.1`)
- **`0`** → highest version for major `0` (`0.42.1`)
- **`0.42`** → highest patch for `0.42.x` (`0.42.1`)
- **`0.41`** → highest patch for `0.41.x` (`0.41.5`)

## Registry Requirements

- **Authentication**: Must have `gcloud` configured with proper credentials
- **Permissions**: Requires IAM permissions to read container images
- **Supported**: Google Container Registry (GCR) and Artifact Registry only

## File Organization

- **Source code** is tracked in git
- **Generated fixtures** are `.gitignore`d (registry-specific data)
- **Registry names** are sanitized (special chars → underscores)