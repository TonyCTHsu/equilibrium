# frozen_string_literal: true

require_relative "../command_base"
require_relative "../analyzer"

module Equilibrium
  module Commands
    # Command for analyzing expected vs actual tags and generating remediation plan
    class AnalyzeCommand < CommandBase
      # Execute the analyze command
      # @param options [Hash] Command options (expected, actual, format, etc.)
      def execute(options = {})
        with_error_handling do
          # Load and validate data files
          expected_data = load_and_validate_json_file(options[:expected])
          actual_data = load_and_validate_json_file(options[:actual])

          # Perform analysis
          analyzer = Analyzer.new
          analysis = analyzer.analyze(expected_data, actual_data)

          # Validate output schema
          validate_analyzer_output_schema(analysis)

          # Format and display output
          format_output(analysis, options[:format] || "summary", "analysis")
        end
      rescue => e
        error_and_exit(e.message)
      end
    end
  end
end
