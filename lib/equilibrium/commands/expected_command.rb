# frozen_string_literal: true

require_relative "../mixins/error_handling"
require_relative "../mixins/input_output"
require_relative "../repository_url_validator"
require_relative "../schema_validator"
require_relative "../schemas/expected_actual"
require_relative "../tags_operation_service"

module Equilibrium
  module Commands
    # Command for generating expected mutable tags based on semantic versions
    class ExpectedCommand
      include Mixins::ErrorHandling
      include Mixins::InputOutput

      # Execute the expected command
      # @param registry [String] Repository URL
      # @param options [Hash] Command options (format, etc.)
      def execute(registry, options = {})
        with_error_handling do
          full_repository_url = RepositoryUrlValidator.validate(registry)

          # Generate complete expected output using high-level service
          output = TagsOperationService.generate_expected_output(full_repository_url)

          # Validate output against schema before writing
          SchemaValidator.validate!(output, Equilibrium::Schemas::EXPECTED_ACTUAL, error_prefix: "Schema validation failed")

          # Format and display output
          format_output(output, options[:format] || "summary", "expected")
        end
      end
    end
  end
end
