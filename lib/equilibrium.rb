# frozen_string_literal: true

require_relative "equilibrium/version"
require_relative "equilibrium/semantic_version"
require_relative "equilibrium/registry_client"
require_relative "equilibrium/tag_processor"
require_relative "equilibrium/catalog_builder"
require_relative "equilibrium/analyzer"
require_relative "equilibrium/schemas/expected_actual"

module Equilibrium
  class Error < StandardError; end
end
