# Equilibrium

[![Gem Version](https://badge.fury.io/rb/equilibrium.svg)](https://badge.fury.io/rb/equilibrium)
[![GitHub Actions](https://github.com/TonyCTHsu/equilibrium/workflows/CI/badge.svg)](https://github.com/TonyCTHsu/equilibrium/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A container image tool that validates equilibrium between mutable tags and semantic version tags.

## Table of Contents

- [The Problem](#the-problem)
- [How Equilibrium Solves It](#how-equilibrium-solves-it)
- [Tag Conversion Logic](#tag-conversion-logic)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Output Formats & Schemas](#output-formats--schemas)
- [Constraints](#constraints)
- [Examples](#examples)
- [License](#license)

## The Problem

Container registries create a web of mutable tags that should point to specific semantic versions, but these relationships can break over time:

**The Challenge:**
- When you publish `myapp:1.2.3`, registries should automatically create `myapp:latest`, `myapp:1`, `myapp:1.2`
- But what happens when you later publish `myapp:1.2.4` or `myapp:1.3.0`?
- Do all the mutable tags get updated correctly?
- How do you verify the entire tag ecosystem is in equilibrium?

**Real-World Impact:**
- `latest` might point to an outdated version
- Major version tags like `1` might miss recent patches
- Minor version tags like `1.2` might not reflect the latest patch
- Users pulling `myapp:1` expect the latest `1.x.x`, but get an old version

## How Equilibrium Solves It

Equilibrium validates your container registry's tag ecosystem through a clear data flow:

```mermaid
flowchart LR
    A[Registry Query] --> B[All Tags<br/>1.0.0<br/>1.1.0<br/>latest<br/>1<br/>1.1<br/>dev]

    B --> C[Filter<br/>Semantic<br/>Versions]
    B --> D[Filter<br/>Mutable<br/>Tags]

    C --> E[Semantic Versions<br/>1.0.0<br/>1.1.0]
    D --> F[Actual Mutable<br/>latest→1.0<br/>1→1.0.0<br/>1.1→1.1.0]

    E --> G[Compute<br/>Expected<br/>Mutable Tags]
    G --> H[Expected Mutable<br/>latest→1.1<br/>1→1.1.0<br/>1.1→1.1.0]

    H --> I[Compare<br/>Expected vs<br/>Actual]
    F --> I

    I --> J[Analysis &<br/>Remediation<br/>Update: latest]

    classDef source fill:#e1d5e7
    classDef process fill:#fff2cc
    classDef expected fill:#d5e8d4
    classDef actual fill:#f8cecc
    classDef result fill:#ffcccc

    class A source
    class C,D,G,I process
    class E,H expected
    class F actual
    class J result
```

**Process Steps:**
1. **Fetch All Tags**: Query registry for complete tag list
2. **Filter Semantic**: Extract only valid semantic version tags (MAJOR.MINOR.PATCH)
3. **Compute Expected**: Generate mutable tags based on semantic versions
4. **Fetch Actual**: Query registry for current mutable tag state
5. **Compare & Analyze**: Identify mismatches and generate remediation plan

## Installation

```bash
gem install equilibrium
```

*For other installation methods, see `equilibrium help`*

## Quick Start

```bash
REPO="gcr.io/datadoghq/apm-inject"
# 1. Check what mutable tags should exist
equilibrium expected "$REPO"

# 2. Check what mutable tags actually exist
equilibrium actual "$REPO"

# 3. Compare and get remediation plan
equilibrium expected "$REPO" --format json > expected.json
equilibrium actual "$REPO" --format json > actual.json
equilibrium analyze --expected expected.json --actual actual.json
```

*For detailed command options, run `equilibrium help [command]`*

## Tag Conversion Logic

Equilibrium transforms semantic version tags into their expected mutable tag ecosystem:

### Core Principle
For any semantic version `MAJOR.MINOR.PATCH`, create mutable tags for each component level, pointing to the **highest available version** at that level.

### Detailed Examples

**Scenario 1: Single Version**
```
Semantic versions: ["1.0.0"]

Expected mutable tags:
├── latest → 1.0.0    (highest overall)
├── 1      → 1.0.0    (highest major 1)
└── 1.0    → 1.0.0    (highest minor 1.0)
```

**Scenario 2: Multiple Patch Versions**
```
Semantic versions: ["1.0.0", "1.0.1", "1.0.2"]

Expected mutable tags:
├── latest → 1.0.2    (highest overall)
├── 1      → 1.0.2    (highest major 1)
└── 1.0    → 1.0.2    (highest minor 1.0)
```

**Scenario 3: Multiple Minor Versions**
```
Semantic versions: ["1.0.0", "1.0.1", "1.1.0", "1.1.3"]

Expected mutable tags:
├── latest → 1.1.3    (highest overall)
├── 1      → 1.1.3    (highest major 1)
├── 1.0    → 1.0.1    (highest minor 1.0)
└── 1.1    → 1.1.3    (highest minor 1.1)
```

**Scenario 4: Multiple Major Versions**
```
Semantic versions: ["0.9.0", "1.0.0", "1.2.3", "2.0.0", "2.1.0"]

Expected mutable tags:
├── latest → 2.1.0    (highest overall)
├── 0      → 0.9.0    (highest major 0)
├── 0.9    → 0.9.0    (highest minor 0.9)
├── 1      → 1.2.3    (highest major 1)
├── 1.0    → 1.0.0    (highest minor 1.0)
├── 1.2    → 1.2.3    (highest minor 1.2)
├── 2      → 2.1.0    (highest major 2)
├── 2.0    → 2.0.0    (highest minor 2.0)
└── 2.1    → 2.1.0    (highest minor 2.1)
```

**Scenario 5: Pre-release and Non-semantic Tags (Filtered Out)**
```
All tags: ["1.0.0", "1.1.0-beta", "1.1.0-rc1", "1.1.0", "latest", "dev"]
Semantic versions: ["1.0.0", "1.1.0"]  # Pre-releases and existing mutable tags filtered

Expected mutable tags:
├── latest → 1.1.0    (highest overall)
├── 1      → 1.1.0    (highest major 1)
├── 1.0    → 1.0.0    (highest minor 1.0)
└── 1.1    → 1.1.0    (highest minor 1.1)
```

## Output Formats & Schemas

### JSON Format
All commands output structured JSON following validated schemas (see [schemas](lib/equilibrium/schemas/)):

**Expected/Actual Commands** ([schema](lib/equilibrium/schemas/expected_actual.rb)):
```json
{
  "repository_url": "gcr.io/project/image",
  "repository_name": "image",
  "digests": {
    "latest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    "1": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    "1.2": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c"
  },
  "canonical_versions": {
    "latest": "1.2.3",
    "1": "1.2.3",
    "1.2": "1.2.3"
  }
}
```

**Analyze Command** ([schema](lib/equilibrium/schemas/analyzer_output.rb)):
```json
{
  "repository_url": "gcr.io/project/image",
  "expected_count": 3,
  "actual_count": 2,
  "missing_tags": {
    "1.2": "sha256:abc123ef456789012345678901234567890123456789012345678901234567890"
  },
  "unexpected_tags": {},
  "mismatched_tags": {
    "latest": {
      "expected": "sha256:def456ab789123456789012345678901234567890123456789012345678901",
      "actual": "sha256:old123ef456789012345678901234567890123456789012345678901234567890"
    }
  },
  "status": "missing_tags",
  "remediation_plan": [
    {
      "action": "create_tag",
      "tag": "1.2",
      "digest": "sha256:abc123ef456789012345678901234567890123456789012345678901234567890",
      "command": "gcloud container images add-tag gcr.io/project/image@sha256:abc123... gcr.io/project/image:1.2"
    },
    {
      "action": "update_tag",
      "tag": "latest",
      "old_digest": "sha256:old123ef456789012345678901234567890123456789012345678901234567890",
      "new_digest": "sha256:def456ab789123456789012345678901234567890123456789012345678901",
      "command": "gcloud container images add-tag gcr.io/project/image@sha256:def456... gcr.io/project/image:latest"
    }
  ]
}
```

**Catalog Command** ([schema](lib/equilibrium/schemas/catalog.rb)):
```json
{
  "images": [
    {
      "name": "image",
      "tag": "latest",
      "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
      "canonical_version": "1.2.3"
    },
    {
      "name": "image",
      "tag": "1",
      "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
      "canonical_version": "1.2.3"
    },
    {
      "name": "image",
      "tag": "1.2",
      "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
      "canonical_version": "1.2.3"
    }
  ]
}
```

### Summary Format
Human-readable table format for quick visual inspection.

## Constraints

- **Registry Support**: Public Google Container Registry (GCR) only
- **Tag Format**: Only processes semantic version tags (MAJOR.MINOR.PATCH)
- **URL Format**: Requires full repository URLs: `[REGISTRY_HOST]/[NAMESPACE]/[REPOSITORY]`

## Examples

### Example 1: Perfect Equilibrium
```bash
$ equilibrium expected gcr.io/google-containers/pause
# Shows: latest→3.9, 3→3.9, 3.9→3.9

$ equilibrium actual gcr.io/google-containers/pause
# Shows: latest→3.9, 3→3.9, 3.9→3.9

$ equilibrium analyze --expected expected.json --actual actual.json
# Status: ✅ in_equilibrium
```

### Example 2: Out of Equilibrium
```bash
$ equilibrium expected gcr.io/project/myapp
# Expected: latest→2.1.0, 1→1.5.3, 2→2.1.0, 2.1→2.1.0

$ equilibrium actual gcr.io/project/myapp
# Actual: latest→1.5.3, 1→1.5.3 (missing: 2, 2.1)

$ equilibrium analyze --expected expected.json --actual actual.json
# Status: ❌ out_of_equilibrium
# Remediation: Create tags: 2→2.1.0, 2.1→2.1.0; Update: latest→2.1.0
```

### Example 3: Automation Pipeline
```bash
#!/bin/bash
REPO="gcr.io/project/image"

# Daily equilibrium check
equilibrium expected "$REPO" > expected.json
equilibrium actual "$REPO" > actual.json
equilibrium analyze --expected expected.json --actual actual.json --format json > report.json

# Alert if out of equilibrium
if grep -q '"status": "out_of_equilibrium"' report.json; then
  echo "⚠️  Repository $REPO is out of equilibrium!"
  equilibrium analyze --expected expected.json --actual actual.json
fi
```

## Development

### Prerequisites

- **Ruby** (>= 3.0.0) with Bundler
- **No authentication required** for public Google Container Registry (GCR) access
- **Pure Ruby implementation** - uses only Ruby standard library (Net::HTTP) for HTTP requests

### Code Quality

```bash
# Ruby linting
bundle exec standardrb
bundle exec standardrb --fix

# Run tests
bundle exec rspec
```

### Release Process

To create a new release:

```bash
# Update version in lib/equilibrium/version.rb, then:
./bin/release
```

The script automatically:
1. Reads the version from `equilibrium.gemspec`
2. Creates a git tag with `v` prefix (e.g., `v0.1.1`)
3. Pushes the tag to trigger the automated release workflow

The GitHub Actions workflow validates that the tag version matches the gemspec version before publishing to RubyGems and GitHub Packages.

## License

MIT License - see [LICENSE](LICENSE) file for details.
