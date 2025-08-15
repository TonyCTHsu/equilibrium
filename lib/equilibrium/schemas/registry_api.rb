# frozen_string_literal: true

module Equilibrium
  module Schemas
    # JSON Schema for Docker Registry v2 API tags/list endpoint response
    # Used by RegistryClient to validate API responses
    # Endpoint: https://docs.docker.com/registry/spec/api/#listing-image-tags
    #
    # Example response:
    # {
    #   "name": "datadoghq/apm-inject",
    #   "tags": ["0.42.0", "0.42.1", "0.43.0", "latest"],
    #   "manifest": {
    #     "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c": {
    #       "tag": ["latest", "0.43.0", "0"]
    #     },
    #     "sha256:c7a822d271eb72e6c3bee2aaf579c8a3732eda9710d27effdca6beb3f5f63b0e": {
    #       "tag": ["0.42.1", "0.42"]
    #     }
    #   }
    # }
    REGISTRY_API_RESPONSE = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "title" => "Docker Registry v2 Tags List Response Schema",
      "description" => "Schema for response from Docker Registry v2 API /v2/{name}/tags/list endpoint",
      "type" => "object",
      "required" => ["name", "tags", "manifest"],
      "properties" => {
        "name" => {
          "type" => "string",
          "description" => "Repository name"
        },
        "tags" => {
          "type" => "array",
          "description" => "List of tag names",
          "items" => {
            "type" => "string"
          }
        },
        "manifest" => {
          "type" => "object",
          "description" => "Manifest data mapping digests to tag metadata",
          "patternProperties" => {
            "^sha256:[a-f0-9]{64}$" => {
              "type" => "object",
              "properties" => {
                "tag" => {
                  "type" => "array",
                  "items" => {
                    "type" => "string"
                  }
                }
              },
              "additionalProperties" => true
            }
          },
          "additionalProperties" => false
        }
      },
      "additionalProperties" => true
    }.freeze
  end
end
