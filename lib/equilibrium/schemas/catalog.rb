# frozen_string_literal: true

module Equilibrium
  module Schemas
    # JSON Schema for catalog output format
    # Used by `catalog` command
    #
    # Example output:
    # {
    #   "repository_url": "gcr.io/datadoghq/apm-inject",
    #   "repository_name": "apm-inject",
    #   "images": [
    #     {
    #       "tag": "latest",
    #       "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #       "canonical_version": "0.43.2"
    #     },
    #     {
    #       "tag": "0",
    #       "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #       "canonical_version": "0.43.2"
    #     },
    #     {
    #       "tag": "0.43",
    #       "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #       "canonical_version": "0.43.1"
    #     }
    #   ]
    # }
    CATALOG = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "title" => "Tag Resolver Schema",
      "description" => "Schema for Resolve tag",
      "type" => "object",
      "required" => ["repository_url", "repository_name", "images"],
      "properties" => {
        "repository_url" => {
          "type" => "string",
          "description" => "Full repository URL (e.g., 'gcr.io/project-id/image-name')",
          "minLength" => 1,
          "pattern" => "^[a-zA-Z0-9.-]+(/[a-zA-Z0-9._-]+)*$"
        },
        "repository_name" => {
          "type" => "string",
          "description" => "Repository name extracted from URL (e.g., 'apm-inject')",
          "minLength" => 1,
          "pattern" => "^[a-zA-Z0-9._-]+$"
        },
        "images" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "required" => [
              "tag",
              "digest",
              "canonical_version"
            ],
            "properties" => {
              "tag" => {
                "type" => "string",
                "description" => "The mutable tag of the image"
              },
              "digest" => {
                "type" => "string",
                "description" => "The full digest of the image",
                "pattern" => "^sha256:[a-f0-9]{64}$"
              },
              "canonical_version" => {
                "type" => "string",
                "description" => "The canonical semantic version for this mutable tag",
                "pattern" => "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$"
              }
            },
            "additionalProperties" => false
          }
        }
      },
      "additionalProperties" => false
    }.freeze
  end
end
