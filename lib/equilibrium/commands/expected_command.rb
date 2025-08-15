# frozen_string_literal: true

require_relative "../command_base"
require_relative "../tags_operation_service"

module Equilibrium
  module Commands
    # Command for generating expected mutable tags based on semantic versions
    class ExpectedCommand < CommandBase
      # Execute the expected command
      # @param registry [String] Repository URL
      # @param options [Hash] Command options (format, etc.)
      def execute(registry, options = {})
        with_error_handling do
          full_repository_url = validate_repository_url(registry)

          # Generate complete expected output using high-level service
          service = TagsOperationService.new
          output = service.generate_expected_output(full_repository_url)

          # Validate output against schema before writing
          validate_expected_actual_schema(output)

          # Format and display output
          format_output(output, options[:format] || "summary", "expected")
        end
      end
    end
  end
end
