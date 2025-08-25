# frozen_string_literal: true

require "json"

require_relative "../mixins/error_handling"
require_relative "../mixins/input_output"
require_relative "../schema_validator"
require_relative "../schemas/expected_actual"
require_relative "../schemas/analyzer_output"
require_relative "../analyzer"

module Equilibrium
  module Commands
    # Command for analyzing expected vs actual tags with unified structure
    class AnalyzeCommand
      include Mixins::ErrorHandling
      include Mixins::InputOutput

      # Execute the analyze command
      # @param options [Hash] Command options (expected, actual, format, etc.)
      def execute(options = {})
        with_error_handling do
          # Load and validate data files
          expected_data = load_and_validate_json_file(options[:expected], error_prefix: "Expected data schema validation failed")
          actual_data = load_and_validate_json_file(options[:actual], error_prefix: "Actual data schema validation failed")

          # Perform analysis
          analysis = Analyzer.analyze(expected_data, actual_data)

          # Validate output schema
          SchemaValidator.validate!(analysis, Equilibrium::Schemas::ANALYZER_OUTPUT, error_prefix: "Analyzer output schema validation failed")

          # Format and display output
          format_output(analysis, options[:format] || "summary", "analysis")
        end
      end

      private

      def load_and_validate_json_file(file_path, error_prefix:)
        raise "File not found: #{file_path}" unless File.exist?(file_path)

        JSON.parse(File.read(file_path)).tap do |json|
          SchemaValidator.validate!(json, Equilibrium::Schemas::EXPECTED_ACTUAL, error_prefix: error_prefix)
        end
      end
    end
  end
end
