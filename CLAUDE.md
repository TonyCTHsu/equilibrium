# Equilibrium

A container image tool that validates equilibrium between mutable tags and semantic version tags.

## Overview

When container images are published with semantic versioning tags (e.g., `1.2.3`), registries often create corresponding mutable tags like `latest`, `1`, `1.2`, etc. This tool validates these mutable tags correctly point to their expected semantic versions by:

1. **Fetching actual tags** from the container registry
2. **Computing expected mutable tags** from semantic versions
3. **Validating equilibrium** between actual vs expected

> [!NOTE]
> Currently, only supporting Google Container Registry (GCR) and Artifact Registry.

## Quick Start

```bash
# Install dependencies
bundle install

# Configure gcloud
gcloud auth login

# Fetch and validate
./src/main.sh
```

## Architecture

### Components

- **`src/*`** - functional scripts ands
  - **`src/main.sh`** - Main orchestration script
  - **`src/schema.json`** - JSON schema for validating tag resolver data structure
- **`spec/*`** - RSpec test suite

### Data Flow

```
Registry → Semantic Filter → compute.rb → convert_to_schema.rb
   ↓            ↓               ↓             ↓
All Tags → semantic_versions → expected_mutable → expected_mutable_schema
   ↓                                              ↓
Mutable Fetch → actual_mutable → RSpec Tests → Equilibrium Validation
```

**Pipeline Steps:**
1. **Fetch all tags** from registry via `gcloud container images list-tags`
2. **Filter semantic versions** (MAJOR.MINOR.PATCH format) → `semantic_versions.json`
3. **Compute expected mappings** via `compute.rb` → `expected_mutable_tags.json`
4. **Convert to schema format** via `convert_to_schema.rb` → `expected_mutable_tags_schema.json`
5. **Fetch actual mutable tags** from registry → `actual_mutable_tags.json`
6. **Validate equilibrium** via RSpec test suite comparing expected vs actual

### Tag conversion logic

Semantic version tag contains MAJOR.MINOR.PATCH format (excluding preleases and other prefixes or suffixes ), withle each component is numeric.

The mutable tags should be computed and generated as described:

For semantic versions like `0.42.1`, `0.42.0`, `0.41.5`,

- **`latest`** → highest overall version (`0.42.1`)
- **`0`** → highest version for major `0` (`0.42.1`)
- **`0.42`** → highest patch for `0.42.x` (`0.42.1`)
- **`0.41`** → highest patch for `0.41.x` (`0.41.5`)

This conversion MUST be idempotent.

## Catalog and Schema Validation

After the expected mutable tags are computed and generated, it would be output to a catalog defined by a JSON schema(`src/schema.json`).

### Output Structure

The data are output to `fixtures` and will later be vailated by the test suite. Under `fixtures`, further namespace by registry while the directory names are sanitized (special chars → underscores).

```
fixtures/
└── {registry_name}/
    ├── semantic_versions.json           # Semantic versions from registry
    ├── actual_mutable_tags.json         # Actual mutable tags from registry
    ├── expected_mutable_tags.json       # Expected mutable tag mappings
    ├── expected_mutable_tags_schema.json # Schema-validated expected tags
    └── registry.txt                     # Original registry name (for reference)
```

## Usage

### Basic Workflow

```bash
# All registries
./src/main.sh

# Run the entire test suite with all fixtures
bundle exec rspec
```

For a specific registry

```bash
# Set registry to work with
REGISTRY="gcr.io/datadoghq/apm-inject"

# Fetch and validate
./src/main.sh $REGISTRY

# Test specific registry (after generating fixtures)
bundle exec rspec --example $REGISTRY
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
- **jq** for JSON processing (required)
- **shellcheck** (optional, for linting)

### Testing

**Important**: Data must be fetched and ready before running tests. Generate fixtures first using `./src/main.sh` with your target registry.

### Code Quality

```bash
# Ruby linting
bundle exec standardrb
bundle exec standardrb --fix

# Shell script linting
shellcheck src/*.sh
```
