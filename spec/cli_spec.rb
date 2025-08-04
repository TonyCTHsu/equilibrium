# frozen_string_literal: true

require "spec_helper"
require "thor"
require_relative "../lib/equilibrium/cli"

RSpec.describe Equilibrium::CLI do
  include EquilibriumTestHelpers

  let(:cli) { described_class.new }
  let(:test_repository_url) { "gcr.io/test-project/test-image" }

  describe "#expected" do
    before do
      stub_registry_api(test_repository_url)
    end

    it "outputs expected mutable tags with correct schema" do
      output = capture_stdout { cli.expected(test_repository_url) }
      data = JSON.parse(output)

      expect(data).to have_key("repository_url")
      expect(data).to have_key("repository_name")
      expect(data).to have_key("tags")

      expect(data["repository_url"]).to eq(test_repository_url)
      expect(data["repository_name"]).to eq("test-image")
      expect(data["tags"]).to be_a(Hash)
    end

    it "validates output against expected/actual schema" do
      output = capture_stdout { cli.expected(test_repository_url) }
      data = JSON.parse(output)

      schemer = JSONSchemer.schema(Equilibrium::Schemas::EXPECTED_ACTUAL)
      errors = schemer.validate(data).to_a

      expect(errors).to be_empty, "Schema validation failed: #{errors.map(&:to_s).join("; ")}"
    end

    it "computes correct virtual tags" do
      output = capture_stdout { cli.expected(test_repository_url) }
      data = JSON.parse(output)
      tags = data["tags"]

      # Should have latest pointing to highest version (1.2.3)
      expect(tags["latest"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")

      # Should have major versions
      expect(tags["1"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")
      expect(tags["0"]).to eq("sha256:678901234567890123456789012345678901234567890123456789012345abc3")

      # Should have minor versions
      expect(tags["1.2"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")
      expect(tags["1.1"]).to eq("sha256:012345678901234567890123456789012345678901234567890123456789abc1")
      expect(tags["0.9"]).to eq("sha256:678901234567890123456789012345678901234567890123456789012345abc3")
    end

    it "requires full repository URL" do
      expect {
        capture_stdout { cli.expected("short-name") }
      }.to raise_error(Thor::Error, /Repository URL must be full format/)
    end

    it "handles registry API errors gracefully" do
      stub_request(:get, "https://gcr.io/v2/test-project/test-image/tags/list")
        .to_return(status: 404, body: "Not Found")

      expect {
        capture_stdout { cli.expected(test_repository_url) }
      }.to raise_error(/Request failed/)
    end
  end

  describe "#actual" do
    before do
      stub_registry_api(test_repository_url)
    end

    it "outputs actual mutable tags with correct schema" do
      output = capture_stdout { cli.actual(test_repository_url) }
      data = JSON.parse(output)

      expect(data).to have_key("repository_url")
      expect(data).to have_key("repository_name")
      expect(data).to have_key("tags")

      expect(data["repository_url"]).to eq(test_repository_url)
      expect(data["repository_name"]).to eq("test-image")
    end

    it "validates output against expected/actual schema" do
      output = capture_stdout { cli.actual(test_repository_url) }
      data = JSON.parse(output)

      schemer = JSONSchemer.schema(Equilibrium::Schemas::EXPECTED_ACTUAL)
      errors = schemer.validate(data).to_a

      expect(errors).to be_empty, "Schema validation failed: #{errors.map(&:to_s).join("; ")}"
    end

    it "filters out non-mutable tags" do
      output = capture_stdout { cli.actual(test_repository_url) }
      data = JSON.parse(output)
      tags = data["tags"]

      # Should include mutable tags
      expect(tags.keys).to include("latest")

      # Should exclude semantic version tags and branch names
      expect(tags.keys).not_to include("1.2.3", "v1.2.3", "main", "dev")

      # Should only include mutable tag patterns
      tags.keys.each do |tag|
        expect(tag).to match(/^(latest|\d+|\d+\.\d+)$/)
      end
    end
  end

  describe "#catalog" do
    let(:sample_input_data) do
      {
        "repository_url" => test_repository_url,
        "repository_name" => "test-image",
        "tags" => {
          "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
          "1" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
          "1.2" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd"
        }
      }
    end

    it "converts expected tags to catalog format from stdin" do
      allow($stdin).to receive(:read).and_return(JSON.pretty_generate(sample_input_data))

      output = capture_stdout { cli.catalog }
      data = JSON.parse(output)

      expect(data).to have_key("images")
      expect(data["images"]).to be_an(Array)
      expect(data["images"].size).to eq(3)

      # Check first image entry
      first_image = data["images"].first
      expect(first_image).to have_key("name")
      expect(first_image).to have_key("tag")
      expect(first_image).to have_key("digest")
      expect(first_image["name"]).to eq("test-image")
    end

    it "validates input against expected/actual schema" do
      invalid_input = {"invalid" => "data"}
      temp_file = create_temp_json_file(invalid_input)

      expect {
        capture_stdout { cli.catalog(temp_file) }
      }.to raise_error(SystemExit)
    end

    it "validates output against catalog schema" do
      allow($stdin).to receive(:read).and_return(JSON.pretty_generate(sample_input_data))

      output = capture_stdout { cli.catalog }
      data = JSON.parse(output)

      schemer = JSONSchemer.schema(Equilibrium::Schemas::CATALOG)
      errors = schemer.validate(data).to_a

      expect(errors).to be_empty, "Catalog schema validation failed: #{errors.map(&:to_s).join("; ")}"
    end
  end

  describe "#analyze" do
    let(:expected_data) { sample_input_data }
    let(:actual_data) { sample_input_data } # Perfect equilibrium
    let(:sample_input_data) do
      {
        "repository_url" => test_repository_url,
        "repository_name" => "test-image",
        "tags" => {
          "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
          "1" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
          "1.2" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd"
        }
      }
    end

    it "analyzes perfect equilibrium" do
      expected_file = create_temp_json_file(expected_data)
      actual_file = create_temp_json_file(actual_data)

      output = capture_stdout do
        cli.invoke(:analyze, [], expected: expected_file, actual: actual_file, format: "json")
      end

      data = JSON.parse(output)
      expect(data["status"]).to eq("perfect")
      expect(data["missing_tags"]).to be_empty
      expect(data["unexpected_tags"]).to be_empty
      expect(data["mismatched_tags"]).to be_empty
      expect(data["remediation_plan"]).to be_empty
    end

    it "detects missing tags" do
      actual_data_missing = {
        "repository_url" => test_repository_url,
        "repository_name" => "test-image",
        "tags" => {"latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd"} # Missing "1" and "1.2"
      }

      expected_file = create_temp_json_file(expected_data)
      actual_file = create_temp_json_file(actual_data_missing)

      output = capture_stdout do
        cli.invoke(:analyze, [], expected: expected_file, actual: actual_file, format: "json")
      end

      data = JSON.parse(output)
      expect(data["status"]).to eq("missing_tags")
      expect(data["missing_tags"]).to have_key("1")
      expect(data["missing_tags"]).to have_key("1.2")
      expect(data["remediation_plan"]).not_to be_empty
    end

    it "detects mismatched tags" do
      actual_data_mismatched = {
        "repository_url" => test_repository_url,
        "repository_name" => "test-image",
        "tags" => {
          "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
          "1" => "sha256:def456789012345678901234567890123456789012345678901234567890abcd", # Wrong digest
          "1.2" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd"
        }
      }

      expected_file = create_temp_json_file(expected_data)
      actual_file = create_temp_json_file(actual_data_mismatched)

      output = capture_stdout do
        cli.invoke(:analyze, [], expected: expected_file, actual: actual_file, format: "json")
      end

      data = JSON.parse(output)
      expect(data["status"]).to eq("mismatched")
      expect(data["mismatched_tags"]).to have_key("1")
      expect(data["mismatched_tags"]["1"]["expected"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")
      expect(data["mismatched_tags"]["1"]["actual"]).to eq("sha256:def456789012345678901234567890123456789012345678901234567890abcd")
    end

    it "shows summary format by default" do
      expected_file = create_temp_json_file(expected_data)
      actual_file = create_temp_json_file(actual_data)

      output = capture_stdout do
        cli.invoke(:analyze, [], expected: expected_file, actual: actual_file)
      end

      expect(output).to include("Repository URL: #{test_repository_url}")
      expect(output).to include("Status: PERFECT")
      expect(output).to include("✓ Registry is in perfect equilibrium!")
    end
  end

  describe "#version" do
    it "shows version information" do
      output = capture_stdout { cli.version }

      expect(output).to include("Equilibrium v")
      expect(output).to include("Container tag validation tool")
    end
  end

  # Helper method to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
