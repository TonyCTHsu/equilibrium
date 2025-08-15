# frozen_string_literal: true

module Equilibrium
  module Schemas
    # JSON Schema for analyzer output format
    # Used by `equilibrium analyze --format=json` command
    #
    # Example output (perfect equilibrium):
    # {
    #   "repository_url": "gcr.io/datadoghq/apm-inject",
    #   "repository_name": "apm-inject",
    #   "expected_count": 28,
    #   "actual_count": 28,
    #   "missing_tags": {},
    #   "unexpected_tags": {},
    #   "mismatched_tags": {},
    #   "status": "perfect",
    #   "remediation_plan": []
    # }
    #
    # Example output (requires remediation):
    # {
    #   "repository_url": "gcr.io/datadoghq/example",
    #   "repository_name": "example",
    #   "expected_count": 3,
    #   "actual_count": 2,
    #   "missing_tags": {
    #     "latest": "sha256:abc123ef456789..."
    #   },
    #   "unexpected_tags": {
    #     "dev": "sha256:xyz789ab123456..."
    #   },
    #   "mismatched_tags": {
    #     "0.1": {
    #       "expected": "sha256:def456ab789123...",
    #       "actual": "sha256:old123ef456789..."
    #     }
    #   },
    #   "status": "missing_tags",
    #   "remediation_plan": [
    #     {
    #       "action": "create_tag",
    #       "tag": "latest",
    #       "digest": "sha256:abc123ef456789...",
    #       "command": "gcloud container images add-tag gcr.io/datadoghq/example@sha256:abc123... gcr.io/datadoghq/example:latest"
    #     }
    #   ]
    # }
    ANALYZER_OUTPUT = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "title" => "Equilibrium Analyzer Output Schema",
      "description" => "Schema for output from 'equilibrium analyze --format=json' command",
      "type" => "object",
      "required" => [
        "repository_url",
        "repository_name", "expected_count", "actual_count", "missing_tags", "unexpected_tags", "mismatched_tags", "status", "remediation_plan"
      ],
      "properties" => {
        "repository_url" => {"type" => "string"},
        "repository_name" => {"type" => "string"},
        "expected_count" => {"type" => "integer", "minimum" => 0},
        "actual_count" => {"type" => "integer", "minimum" => 0},
        "status" => {"enum" => ["perfect", "missing_tags", "mismatched", "extra_tags"]},
        "missing_tags" => {
          "type" => "object",
          "patternProperties" => {
            ".*" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"}
          }
        },
        "unexpected_tags" => {
          "type" => "object",
          "patternProperties" => {
            ".*" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"}
          }
        },
        "mismatched_tags" => {
          "type" => "object",
          "patternProperties" => {
            ".*" => {
              "type" => "object",
              "required" => ["expected", "actual"],
              "properties" => {
                "expected" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"},
                "actual" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"}
              }
            }
          }
        },
        "remediation_plan" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "required" => ["action", "tag"],
            "properties" => {
              "action" => {"enum" => ["create_tag", "update_tag", "remove_tag"]},
              "tag" => {"type" => "string"},
              "digest" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"},
              "old_digest" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"},
              "new_digest" => {"type" => "string", "pattern" => "^sha256:[a-f0-9]{64}$"},
              "command" => {"type" => "string"}
            }
          }
        }
      }
    }.freeze
  end
end
