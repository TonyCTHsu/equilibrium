# frozen_string_literal: true

require "json_schemer"

module Equilibrium
  # Reusable schema validation utility
  # Centralizes JSON Schema validation logic across the application
  class SchemaValidator
    class ValidationError < StandardError; end

    # Validates data against a JSON Schema
    # @param data [Hash] The data to validate
    # @param schema [Hash] The JSON Schema to validate against
    # @param error_prefix [String] Prefix for error messages (optional)
    # @raise [ValidationError] If validation fails
    def self.validate!(data, schema, error_prefix: "Schema validation failed")
      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(data).to_a

      return if errors.empty?

      error_messages = errors.map do |error|
        "#{error["data_pointer"]}: #{error["details"] || error["error"]}"
      end

      raise ValidationError, "#{error_prefix}:\n#{error_messages.join("\n")}"
    end
  end
end
