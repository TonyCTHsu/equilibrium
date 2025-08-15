# frozen_string_literal: true

require_relative "../mixins/error_handling"
require_relative "../mixins/input_output"
require_relative "../repository_url_validator"
require_relative "../schema_validator"
require_relative "../schemas/expected_actual"
require_relative "../tags_operation_service"

module Equilibrium
  module Commands
    # Command for generating actual mutable tags from registry
    class ActualCommand
      include Mixins::ErrorHandling
      include Mixins::InputOutput

      # Execute the actual command
      # @param registry [String] Repository URL
      # @param options [Hash] Command options (format, etc.)
      def execute(registry, options = {})
        with_error_handling do
          full_repository_url = RepositoryUrlValidator.validate(registry)

          # Generate complete actual output using high-level service
          output = TagsOperationService.generate_actual_output(full_repository_url)

          # Validate output against schema before writing
          SchemaValidator.validate!(output, Equilibrium::Schemas::EXPECTED_ACTUAL, error_prefix: "Schema validation failed")

          # Format and display output
          format_output(output, options[:format] || "summary", "actual")
        end
      end
    end
  end
end
