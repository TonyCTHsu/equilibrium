# frozen_string_literal: true

require_relative "../version"

module Equilibrium
  module Commands
    # Command for displaying version information
    class VersionCommand
      # Execute the version command
      def self.execute
        puts "Equilibrium v#{Equilibrium::VERSION}"
        puts "Container tag validation tool"
      end
    end
  end
end
