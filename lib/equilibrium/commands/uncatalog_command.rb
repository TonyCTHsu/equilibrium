# frozen_string_literal: true

require_relative "../command_base"
require_relative "../catalog_builder"

module Equilibrium
  module Commands
    # Command for converting catalog format back to expected/actual format
    class UncatalogCommand < CommandBase
      # Execute the uncatalog command
      # @param file_path [String, nil] Optional file path, uses stdin if nil
      def execute(file_path = nil)
        with_error_handling do
          # Read input from file or stdin
          input = read_input_data(file_path, "No input provided. Use: equilibrium catalog registry | equilibrium uncatalog")

          # Parse and validate JSON
          data = parse_json(input, "input")
          validate_catalog_schema(data)

          # Convert back to expected/actual format
          builder = CatalogBuilder.new
          result = builder.reverse_catalog(data)

          # Output as JSON
          puts JSON.pretty_generate(result)
        end
      rescue JSON::ParserError => e
        error_and_exit("Invalid JSON input: #{e.message}")
      rescue => e
        error_and_exit(e.message)
      end
    end
  end
end
