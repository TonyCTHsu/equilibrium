# frozen_string_literal: true

require "json"
require_relative "../schema_validator"

module Equilibrium
  module Mixins
    # Module for all schema validation operations
    module SchemaValidation
      # Validate repository URL format
      # @param repository_url [String] Repository URL to validate
      # @return [String] Validated repository URL
      def validate_repository_url(repository_url)
        unless repository_url.include?("/")
          raise Thor::Error, "Repository URL must be full format (e.g., 'gcr.io/project-id/image-name'), not '#{repository_url}'"
        end
        repository_url
      end

      # Load and validate JSON file against provided schema
      # @param file_path [String] Path to JSON file
      # @param schema [Hash] JSON schema to validate against
      # @param error_prefix [String] Prefix for validation error messages
      # @return [Hash] Validated JSON data
      def load_and_validate_json_file(file_path, schema, error_prefix: "Schema validation failed")
        unless File.exist?(file_path)
          raise "File not found: #{file_path}"
        end

        data = JSON.parse(File.read(file_path))
        SchemaValidator.validate!(data, schema, error_prefix: error_prefix)
        data
      end
    end
  end
end
