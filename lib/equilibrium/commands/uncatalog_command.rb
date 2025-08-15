# frozen_string_literal: true

require_relative "../mixins/error_handling"
require_relative "../mixins/input_output"
require_relative "../schema_validator"
require_relative "../schemas/catalog"
require_relative "../catalog_builder"

module Equilibrium
  module Commands
    # Command for converting catalog format back to expected/actual format
    class UncatalogCommand
      include Mixins::ErrorHandling
      include Mixins::InputOutput
      include Mixins::SchemaValidation

      # Execute the uncatalog command
      # @param file_path [String, nil] Optional file path, uses stdin if nil
      def execute(file_path = nil)
        with_error_handling do
          # Read input from file or stdin
          input = read_input_data(file_path, "No input provided. Use: equilibrium catalog registry | equilibrium uncatalog")

          # Parse and validate JSON
          data = parse_json(input, "input")
          SchemaValidator.validate!(data, Equilibrium::Schemas::CATALOG, error_prefix: "Catalog schema validation failed")

          # Convert back to expected/actual format
          result = CatalogBuilder.reverse_catalog(data)

          # Output as JSON
          puts JSON.pretty_generate(result)
        end
      end
    end
  end
end
