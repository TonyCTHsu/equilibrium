# frozen_string_literal: true

module Equilibrium
  module Schemas
    # JSON Schema for catalog output format
    # Used by `equilibrium catalog` command
    #
    # Example output:
    # {
    #   "images": [
    #     {
    #       "name": "apm-inject",
    #       "tag": "latest",
    #       "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #       "canonical_version": "0.43.2"
    #     },
    #     {
    #       "name": "apm-inject",
    #       "tag": "0",
    #       "digest": "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
    #       "canonical_version": "0.43.2"
    #     },
    #     {
    #       "name": "apm-inject",
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
      "properties" => {
        "images" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "required" => [
              "name",
              "tag",
              "digest",
              "canonical_version"
            ],
            "properties" => {
              "name" => {
                "type" => "string",
                "description" => "The name of the image"
              },
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
