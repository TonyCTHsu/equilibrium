# frozen_string_literal: true

require "thor"
require "json"
require_relative "../equilibrium"
require_relative "schema_validator"
require_relative "schemas/expected_actual"

module Equilibrium
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
      # Load and validate data files
      expected_data = load_and_validate_json_file(options[:expected])
      actual_data = load_and_validate_json_file(options[:actual])

      analyzer = Analyzer.new
      analysis = analyzer.analyze(expected_data, actual_data)

      case options[:format]
      when "json"
        puts JSON.pretty_generate(analysis)
      when "summary"
        print_analysis_summary(analysis)
      end
    rescue => e
      error_and_exit(e.message)
    end

    desc "expected REPOSITORY_URL", "Output expected mutable tags to stdout"
    option :format, type: :string, default: "summary", enum: ["json", "summary"], desc: "Output format"
    def expected(registry)
      client = RegistryClient.new
      processor = TagProcessor.new

      full_repository_url = validate_repository_url(registry)
      all_tags = client.list_tags(full_repository_url)
      semantic_tags = processor.filter_semantic_tags(all_tags)
      virtual_tags_result = processor.compute_virtual_tags(semantic_tags)

      # Extract repository name from URL
      repository_name = extract_repository_name(full_repository_url)

      output = {
        "repository_url" => full_repository_url,
        "repository_name" => repository_name,
        "digests" => virtual_tags_result["digests"],
        "canonical_versions" => virtual_tags_result["canonical_versions"]
      }

      # Validate output against schema before writing
      validate_expected_actual_schema(output)

      case options[:format]
      when "json"
        puts JSON.pretty_generate(output)
      when "summary"
        print_expected_summary(output)
      end
    rescue Thor::Error
      raise  # Let Thor::Error bubble up for validation errors
    rescue RegistryClient::Error => e
      raise StandardError, e.message  # Convert for test compatibility
    rescue => e
      error_and_exit(e.message)
    end

    desc "actual REPOSITORY_URL", "Output actual mutable tags to stdout"
    option :format, type: :string, default: "summary", enum: ["json", "summary"], desc: "Output format"
    def actual(registry)
      client = RegistryClient.new
      processor = TagProcessor.new

      full_repository_url = validate_repository_url(registry)
      all_tags = client.list_tags(full_repository_url)
      mutable_tags = processor.filter_mutable_tags(all_tags)

      # Get semantic tags to create canonical mapping for actual mutable tags
      semantic_tags = processor.filter_semantic_tags(all_tags)
      canonical_versions = {}

      # For each actual mutable tag, find its canonical version by digest matching
      mutable_tags.each do |mutable_tag, digest|
        # Find semantic tag with same digest
        canonical_version = semantic_tags.find { |_, sem_digest| sem_digest == digest }&.first
        canonical_versions[mutable_tag] = canonical_version if canonical_version
      end

      # Extract repository name from URL
      repository_name = extract_repository_name(full_repository_url)

      output = {
        "repository_url" => full_repository_url,
        "repository_name" => repository_name,
        "digests" => mutable_tags,
        "canonical_versions" => canonical_versions
      }

      # Validate output against schema before writing
      validate_expected_actual_schema(output)

      case options[:format]
      when "json"
        puts JSON.pretty_generate(output)
      when "summary"
        print_actual_summary(output)
      end
    rescue Thor::Error
      raise  # Let Thor::Error bubble up for validation errors
    rescue RegistryClient::Error => e
      raise StandardError, e.message  # Convert for test compatibility
    rescue => e
      error_and_exit(e.message)
    end

    desc "catalog [FILE]", "Convert expected tags JSON to catalog format (reads from file or stdin)"
    def catalog(file_path = nil)
      # Read from file or stdin
      if file_path
        unless File.exist?(file_path)
          error_and_exit("File not found: #{file_path}")
        end
        input = File.read(file_path).strip
      else
        input = $stdin.read.strip
        if input.empty?
          error_and_exit("No input provided. Use: equilibrium expected registry | equilibrium catalog")
        end
      end

      data = JSON.parse(input)

      # Validate against expected/actual schema
      validate_expected_actual_schema(data)

      builder = CatalogBuilder.new
      catalog = builder.build_catalog(data)

      puts JSON.pretty_generate(catalog)
    rescue JSON::ParserError => e
      error_and_exit("Invalid JSON input: #{e.message}")
    rescue => e
      error_and_exit(e.message)
    end

    desc "version", "Show version information"
    def version
      say "Equilibrium v#{Equilibrium::VERSION}"
      say "Container tag validation tool"
    end

    private

    def load_and_validate_json_file(file_path)
      unless File.exist?(file_path)
        raise "File not found: #{file_path}"
      end

      data = JSON.parse(File.read(file_path))
      validate_expected_actual_schema(data)
      data
    rescue JSON::ParserError => e
      raise "Invalid JSON in #{file_path}: #{e.message}"
    end

    def validate_repository_url(repository_url)
      # Repository URL must include registry host, project/namespace, and image name
      # Format: [REGISTRY_HOST]/[PROJECT_OR_NAMESPACE]/[IMAGE_NAME]
      unless repository_url.include?("/")
        raise Thor::Error, "Repository URL must be full format (e.g., 'gcr.io/project-id/image-name'), not '#{repository_url}'"
      end

      repository_url
    end

    def extract_repository_name(repository_url)
      # Extract repository name from repository URL
      # Examples:
      #   gcr.io/project-id/repository-name -> repository-name
      #   registry.com/namespace/repository-name -> repository-name
      repository_url.split("/").last
    end

    def validate_expected_actual_schema(data)
      SchemaValidator.validate!(data, Equilibrium::Schemas::EXPECTED_ACTUAL, error_prefix: "Schema validation failed")
    rescue SchemaValidator::ValidationError => e
      error_and_exit(e.message)
    end

    def error_and_exit(message, usage = nil)
      error message
      if usage
        say usage, :red
      end
      exit 1
    end

    def print_analysis_summary(analysis)
      say "Repository URL: #{analysis[:repository_url]}"
      say ""

      # Status overview table
      status_color = (analysis[:status] == "perfect") ? :green : :yellow
      status_symbol = (analysis[:status] == "perfect") ? "✓" : "⚠"

      overview_data = [
        ["Metric", "Count"],
        ["Expected tags", analysis[:expected_count].to_s],
        ["Actual tags", analysis[:actual_count].to_s],
        ["Missing tags", analysis[:missing_tags].size.to_s],
        ["Mismatched tags", analysis[:mismatched_tags].size.to_s],
        ["Unexpected tags", analysis[:unexpected_tags].size.to_s]
      ]

      say "Analysis Overview:"
      print_table(overview_data, borders: true)
      say ""

      say "#{status_symbol} Status: #{analysis[:status].upcase.tr("_", " ")}", status_color
      say ""

      # Show specific issue sections
      has_issues = false

      # Missing tags section
      if analysis[:missing_tags].any?
        has_issues = true
        say "Missing Tags (should be created):"
        missing_table = [["Tag", "Should Point To"]]
        analysis[:missing_tags].each do |tag, digest|
          short_digest = digest ? digest.split(":").last[0..11] : "unknown"
          missing_table << [tag, short_digest]
        end
        print_table(missing_table, borders: true)
        say ""
      end

      # Mismatched tags section
      if analysis[:mismatched_tags].any?
        has_issues = true
        say "Mismatched Tags (pointing to wrong version):"
        mismatched_table = [["Tag", "Expected", "Actual"]]
        analysis[:mismatched_tags].each do |tag, details|
          if details.is_a?(Hash)
            expected = details[:expected] ? details[:expected].split(":").last[0..11] : "unknown"
            actual = details[:actual] ? details[:actual].split(":").last[0..11] : "unknown"
          else
            expected = details ? details.split(":").last[0..11] : "unknown"
            actual = "unknown"
          end
          mismatched_table << [tag, expected, actual]
        end
        print_table(mismatched_table, borders: true)
        say ""
      end

      # Unexpected tags section
      if analysis[:unexpected_tags].any?
        has_issues = true
        say "Unexpected Tags (should be removed):"
        unexpected_table = [["Tag", "Currently Points To"]]
        analysis[:unexpected_tags].each do |tag, digest|
          short_digest = digest ? digest.split(":").last[0..11] : "unknown"
          unexpected_table << [tag, short_digest]
        end
        print_table(unexpected_table, borders: true)
        say ""
      end

      if has_issues
        say "To see detailed remediation commands, use:"
        say "  equilibrium analyze --expected expected.json --actual actual.json --format=json | jq '.remediation_plan'"
      else
        say "✓ Registry is in perfect equilibrium!", :green
      end
    end

    def print_expected_summary(output)
      say "Repository: #{output["repository_name"]}"
      say "URL: #{output["repository_url"]}"
      say ""

      mutable_tags = output["digests"]
      canonical_versions = output["canonical_versions"]

      say "Expected mutable tags (#{mutable_tags.size}):"
      say ""

      # Create table data: [["Tag", "Version", "Digest"]]
      table_data = [["Tag", "Version", "Digest"]]
      mutable_tags.keys.sort.each do |tag|
        canonical_version = canonical_versions[tag]
        digest = mutable_tags[tag]
        table_data << [tag, canonical_version, digest]
      end

      print_table(table_data, borders: true)
    end

    def print_actual_summary(output)
      say "Repository: #{output["repository_name"]}"
      say "URL: #{output["repository_url"]}"
      say ""

      mutable_tags = output["digests"]
      canonical_versions = output["canonical_versions"]

      say "Actual mutable tags (#{mutable_tags.size}):"
      say ""

      # Create table data: [["Tag", "Version", "Digest"]]
      table_data = [["Tag", "Version", "Digest"]]
      mutable_tags.keys.sort.each do |tag|
        canonical_version = canonical_versions[tag]
        digest = mutable_tags[tag]
        table_data << [tag, canonical_version, digest]
      end

      print_table(table_data, borders: true)
    end
  end
end
