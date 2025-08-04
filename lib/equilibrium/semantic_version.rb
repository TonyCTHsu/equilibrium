# frozen_string_literal: true

module Equilibrium
  module SemanticVersion
    # Strictly validate MAJOR.MINOR.PATCH format where:
    # - MAJOR, MINOR, PATCH are non-negative integers
    # - No leading zeros (except for '0' itself)
    # - No prefixes (like 'v1.2.3', 'release-1.2.3')
    # - No suffixes (like '1.2.3-alpha', '1.2.3+build')
    # - No prereleases (like '1.2.3-rc.1', '1.2.3-beta.2')
    def self.valid?(tag)
      # Strict regex: each component must be either '0' or a number without leading zeros
      return false unless tag.match?(/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/)

      # Additional validation: ensure it's a valid Gem::Version
      begin
        Gem::Version.new(tag)
        true
      rescue ArgumentError
        false
      end
    end
  end
end
