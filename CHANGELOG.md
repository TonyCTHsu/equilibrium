# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-08-06

### Added
- GitHub Packages publishing support in release workflow
- Draft mode for GitHub releases requiring manual review
- Enhanced release automation with artifact attachment

### Fixed
- Preserve descending tag order in summary format output
- Consistent descending ordering for expected and actual outputs

### Changed
- Reorganized spec files to mirror lib directory structure
- Extracted TagSorter utility with comprehensive unit tests
- Enhanced RegistryClient with pagination analysis capabilities

## [0.1.0] - 2025-08-05

### Added
- Initial release of Equilibrium container image validation tool
- Core CLI with Unix-style command interface (`expected`, `actual`, `analyze`, `catalog`)
- Support for Google Container Registry (GCR) public repositories
- Semantic version tag processing and mutable tag computation
- JSON schema validation for all command outputs
- Comprehensive analysis and remediation planning functionality
- Ruby gem packaging with executable installation
- Thor-based command-line interface with table formatting
- Dual format output support (summary and JSON) for analysis
- Catalog generation with canonical version mapping
- Comprehensive test suite with RSpec
- CI/CD pipeline with GitHub Actions
- Trusted publishing support for RubyGems
- Standard rake task integration

### Features
- **Tag Validation**: Validates equilibrium between mutable tags and semantic version tags
- **Registry Client**: Pure Ruby HTTP client for container registry API access
- **Tag Processing**: Computes expected mutable tags from semantic versions (latest, major, minor)
- **Analysis Engine**: Compares expected vs actual tags with detailed remediation planning
- **Schema Validation**: Embedded JSON schemas for all data formats
- **Unix Philosophy**: Composable commands that work well in pipelines
- **Output Formats**: Multiple output formats including JSON, summary tables, and catalog

### Documentation
- Comprehensive README with usage examples and API documentation
- Detailed architecture overview and data flow diagrams
- Complete command reference and examples

[0.1.1]: https://github.com/DataDog/equilibrium/releases/tag/v0.1.1
[0.1.0]: https://github.com/DataDog/equilibrium/releases/tag/v0.1.0