# frozen_string_literal: true

require "aruba/rspec"

RSpec.configure do |config|
  config.include Aruba::Api, type: :aruba
end

Aruba.configure do |config|
  config.exit_timeout = 10
  config.io_wait_timeout = 5
  config.working_directory = "tmp/aruba"
  config.command_runtime_environment = {
    "BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__),
    "RUBYLIB" => File.expand_path("../../lib", __dir__)
  }
end
