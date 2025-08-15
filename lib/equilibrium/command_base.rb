# frozen_string_literal: true

require "json"
require "thor"
require_relative "schema_validator"
require_relative "schemas/expected_actual"
require_relative "schemas/catalog"
require_relative "schemas/analyzer_output"
require_relative "summary_formatter"

module Equilibrium
  # Base class for all CLI commands
  # Provides shared functionality for input/output handling, validation, and error handling
  class CommandBase
    # Execute command with consistent error handling
    def with_error_handling(&block)
      block.call
    rescue Thor::Error
      raise  # Let Thor::Error bubble up for validation errors
    rescue RegistryClient::Error => e
      raise StandardError, e.message  # Convert for test compatibility
    rescue => e
      error_and_exit(e.message)
    end

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

    # Exit with error message
    def error_and_exit(message, usage = nil)
      warn message
      if usage
        warn usage
      end
      exit 1
    end
  end
end
