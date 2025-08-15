# frozen_string_literal: true

require "thor"
require_relative "commands/analyze_command"
require_relative "commands/expected_command"
require_relative "commands/actual_command"
require_relative "commands/catalog_command"
require_relative "commands/uncatalog_command"
require_relative "commands/version_command"

module Equilibrium
  # Main CLI class - acts as a router to individual command classes
  # Each command delegates to its respective command class for execution
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "analyze", "Compare expected vs actual tags and generate remediation plan"
    option :expected, type: :string, required: true, desc: "Expected tags JSON file"
    option :actual, type: :string, required: true, desc: "Actual tags JSON file"
    option :registry, type: :string, desc: "Repository URL for output"
    option :format, type: :string, default: "summary", enum: ["json", "summary"], desc: "Output format"
    def analyze
      Commands::AnalyzeCommand.new.execute(options)
    end

    desc "expected REPOSITORY_URL", "Output expected mutable tags to stdout"
    option :format, type: :string, default: "summary", enum: ["json", "summary"], desc: "Output format"
    def expected(registry)
      Commands::ExpectedCommand.new.execute(registry, options)
    end

    desc "actual REPOSITORY_URL", "Output actual mutable tags to stdout"
    option :format, type: :string, default: "summary", enum: ["json", "summary"], desc: "Output format"
    def actual(registry)
      Commands::ActualCommand.new.execute(registry, options)
    end

    desc "catalog [FILE]", "Convert expected tags JSON to catalog format (reads from file or stdin)"
    def catalog(file_path = nil)
      Commands::CatalogCommand.new.execute(file_path)
    end

    desc "uncatalog [FILE]", "Convert catalog format back to expected/actual format (reads from file or stdin)"
    def uncatalog(file_path = nil)
      Commands::UncatalogCommand.new.execute(file_path)
    end

    desc "version", "Show version information"
    def version
      Commands::VersionCommand.new.execute
    end
  end
end
