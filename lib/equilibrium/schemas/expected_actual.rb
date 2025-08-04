# frozen_string_literal: true

module Equilibrium
  module Schemas
    # JSON Schema for expected/actual command output format
    # Used by `equilibrium expected` and `equilibrium actual` commands
    #
    # Example output:
    # {
    #   "repository_url": "gcr.io/datadoghq/apm-inject",
    #   "repository_name": "apm-inject",
    #   "tags": {
    #     "latest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #     "0": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #     "0.43": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #     "0.42": "sha256:c7a822d271eb72e6c3bee2aaf579c8a3732eda9710d27effdca6beb3f5f63b0e"
    #   }
    # }
    EXPECTED_ACTUAL = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "title" => "Equilibrium Expected/Actual Output Schema",
      "description" => "Schema for output from 'equilibrium expected' and 'equilibrium actual' commands",
      "type" => "object",
      "required" => ["repository_url", "repository_name", "tags"],
      "properties" => {
        "repository_url" => {
          "type" => "string",
          "description" => "Full repository URL (e.g., 'gcr.io/project-id/image-name', 'registry.example.com/namespace/repository')",
          "minLength" => 1,
          "pattern" => "^[a-zA-Z0-9.-]+(/[a-zA-Z0-9._-]+)*$"
        },
        "repository_name" => {
          "type" => "string",
          "description" => "Repository name extracted from URL (e.g., 'apm-inject')",
          "minLength" => 1,
          "pattern" => "^[a-zA-Z0-9._-]+$"
        },
        "tags" => {
          "type" => "object",
          "description" => "Mapping of mutable tags to their SHA256 digests",
          "minProperties" => 1,
          "patternProperties" => {
            "^(latest|[0-9]+(\\.[0-9]+)*)$" => {
              "type" => "string",
              "description" => "SHA256 digest for the tag",
              "pattern" => "^sha256:[a-f0-9]{64}$"
            }
          },
          "additionalProperties" => false
        }
      },
      "additionalProperties" => false
    }.freeze
  end
end
