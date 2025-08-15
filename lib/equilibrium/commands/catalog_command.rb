# frozen_string_literal: true

require_relative "../command_base"
require_relative "../catalog_builder"

module Equilibrium
  module Commands
    # Command for converting expected tags JSON to catalog format
    class CatalogCommand < CommandBase
      # Execute the catalog command
      # @param file_path [String, nil] Optional file path, uses stdin if nil
      def execute(file_path = nil)
        with_error_handling do
          # Read input from file or stdin
          input = read_input_data(file_path, "No input provided. Use: equilibrium expected registry | equilibrium catalog")

          # Parse and validate JSON
          data = parse_json(input, "input")
          validate_expected_actual_schema(data)

          # Convert to catalog format
          builder = CatalogBuilder.new
          catalog = builder.build_catalog(data)

          # Output as JSON
          puts JSON.pretty_generate(catalog)
        end
      rescue JSON::ParserError => e
        error_and_exit("Invalid JSON input: #{e.message}")
      rescue => e
        error_and_exit(e.message)
      end
    end
  end
end
