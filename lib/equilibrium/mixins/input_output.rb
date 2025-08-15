# frozen_string_literal: true

require "json"
require_relative "../summary_formatter"

module Equilibrium
  module Mixins
    # Module for input/output operations - reading files, parsing JSON, formatting output
    module InputOutput
      # Read input from file or stdin with validation
      # @param file_path [String, nil] Optional file path, uses stdin if nil
      # @param usage_message [String] Error message for empty stdin
      # @return [String] Input content
      def read_input_data(file_path = nil, usage_message = "No input provided")
        if file_path
          unless File.exist?(file_path)
            error_and_exit("File not found: #{file_path}")
          end
          File.read(file_path).strip
        else
          input = $stdin.read.strip
          if input.empty?
            error_and_exit(usage_message.to_s)
          end
          input
        end
      end

      # Parse JSON with context-specific error messages
      # @param input [String] JSON string to parse
      # @param context [String] Context for error messages (e.g., "catalog input")
      # @return [Hash] Parsed JSON data
      def parse_json(input, context = "input")
        JSON.parse(input)
      rescue JSON::ParserError => e
        error_and_exit("Invalid JSON #{context}: #{e.message}")
      end

      # Format and display output based on format option
      # @param data [Hash] Data to output
      # @param format [String] Output format ("json" or "summary")
      # @param summary_type [String] Type for summary formatter (e.g., "expected", "actual")
      def format_output(data, format, summary_type = nil)
        case format
        when "json"
          puts JSON.pretty_generate(data)
        when "summary"
          if summary_type
            formatter = SummaryFormatter.new
            case summary_type
            when "expected", "actual"
              formatter.print_tags_summary(data, summary_type)
            when "analysis"
              formatter.print_analysis_summary(data)
            end
          else
            puts JSON.pretty_generate(data)
          end
        else
          puts JSON.pretty_generate(data)
        end
      end

      # Note: error_and_exit method is provided by ErrorHandling module
    end
  end
end
