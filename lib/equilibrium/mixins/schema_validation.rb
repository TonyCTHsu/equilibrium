# frozen_string_literal: true

require "json"
require_relative "../schema_validator"
require_relative "../schemas/expected_actual"
require_relative "../schemas/catalog"
require_relative "../schemas/analyzer_output"

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

      # Load and validate JSON file against expected/actual schema
      # @param file_path [String] Path to JSON file
      # @return [Hash] Validated JSON data
      def load_and_validate_json_file(file_path)
        unless File.exist?(file_path)
          raise "File not found: #{file_path}"
        end

        data = JSON.parse(File.read(file_path))
        validate_expected_actual_schema(data)
        data
      rescue JSON::ParserError => e
        raise "Invalid JSON in #{file_path}: #{e.message}"
      end

      # Schema validation methods
      def validate_expected_actual_schema(data)
        SchemaValidator.validate!(data, Equilibrium::Schemas::EXPECTED_ACTUAL, error_prefix: "Schema validation failed")
      rescue SchemaValidator::ValidationError => e
        error_and_exit(e.message)
      end

      def validate_catalog_schema(data)
        SchemaValidator.validate!(data, Equilibrium::Schemas::CATALOG, error_prefix: "Catalog schema validation failed")
      rescue SchemaValidator::ValidationError => e
        error_and_exit(e.message)
      end

      def validate_analyzer_output_schema(data)
        SchemaValidator.validate!(data, Equilibrium::Schemas::ANALYZER_OUTPUT, error_prefix: "Analyzer output schema validation failed")
      rescue SchemaValidator::ValidationError => e
        error_and_exit(e.message)
      end

      # Note: error_and_exit method is provided by ErrorHandling module
    end
  end
end
