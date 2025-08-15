# frozen_string_literal: true

require "json"
require "thor"
require_relative "../schema_validator"

module Equilibrium
  module Mixins
    # Module for consistent error handling across all commands
    module ErrorHandling
      # Execute command with comprehensive error handling
      # Handles all common error types consistently across all commands
      def with_error_handling(&block)
        block.call
      rescue Thor::Error
        raise  # Let Thor::Error bubble up for validation errors
      rescue RegistryClient::Error => e
        raise StandardError, e.message  # Convert for test compatibility
      rescue SchemaValidator::ValidationError => e
        error_and_exit(e.message)
      rescue JSON::ParserError => e
        error_and_exit("Invalid JSON input: #{e.message}")
      rescue => e
        error_and_exit(e.message)
      end

      private

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
end
