# frozen_string_literal: true

require_relative "../mixins/error_handling"
require_relative "../mixins/input_output"
require_relative "../schema_validator"
require_relative "../schemas/expected_actual"
require_relative "../catalog_builder"

module Equilibrium
  module Commands
    # Command for converting expected tags JSON to catalog format
    class CatalogCommand
      include Mixins::ErrorHandling
      include Mixins::InputOutput
      include Mixins::SchemaValidation

      # Execute the catalog command
      # @param file_path [String, nil] Optional file path, uses stdin if nil
      def execute(file_path = nil)
        with_error_handling do
          # Read input from file or stdin
          input = read_input_data(file_path, "No input provided. Use: equilibrium expected registry | equilibrium catalog")

          # Parse and validate JSON
          data = parse_json(input, "input")
          SchemaValidator.validate!(data, Equilibrium::Schemas::EXPECTED_ACTUAL, error_prefix: "Schema validation failed")

          # Convert to catalog format
          catalog = CatalogBuilder.build_catalog(data)

          # Output as JSON
          puts JSON.pretty_generate(catalog)
        end
      end
    end
  end
end
