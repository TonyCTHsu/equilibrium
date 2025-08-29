# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
])
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
end

require "rspec"
require "json"
require "json_schemer"
require "webmock/rspec"

# Load the main library
require_relative "../lib/equilibrium"

# Load support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable WebMock for HTTP request stubbing
  WebMock.disable_net_connect!(allow_localhost: true)

  # Clean up any temporary files after tests
  config.after(:suite) do
    Dir.glob("tmp/*").each do |file|
      FileUtils.rm_rf(file) unless file.end_with?(".gitkeep")
    end
  end

  # Include test helpers
  config.include EquilibriumTestHelpers
end
