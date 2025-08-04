# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tempfile"
require_relative "../lib/equilibrium/cli"

RSpec.describe "Integration Tests" do
  let(:test_repository_url) { "gcr.io/test-project/test-image" }

  # Use WebMock stubs for integration tests
  before do
    stub_registry_api(test_repository_url)
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

  describe "end-to-end workflow" do
    it "processes expected -> catalog -> analyze pipeline" do
      cli = Equilibrium::CLI.new

      # Step 1: Generate expected tags
      expected_output = capture_stdout { cli.expected(test_repository_url) }
      expected_data = JSON.parse(expected_output)
      expect(expected_data).to have_key("repository_url")
      expect(expected_data).to have_key("repository_name")
      expect(expected_data).to have_key("tags")

      # Step 2: Generate actual tags
      actual_output = capture_stdout { cli.actual(test_repository_url) }
      actual_data = JSON.parse(actual_output)
      expect(actual_data).to have_key("repository_url")
      expect(actual_data).to have_key("tags")

      # Step 3: Convert expected to catalog format
      allow($stdin).to receive(:read).and_return(expected_output)
      catalog_output = capture_stdout { cli.catalog }
      catalog_data = JSON.parse(catalog_output)
      expect(catalog_data).to have_key("images")
      expect(catalog_data["images"]).to be_an(Array)

      # Step 4: Create temporary files for analysis
      expected_file = create_temp_json_file(expected_data)
      actual_file = create_temp_json_file(actual_data)

      # Step 5: Analyze for equilibrium
      analyze_output = capture_stdout do
        cli.invoke(:analyze, [], expected: expected_file, actual: actual_file, format: "json")
      end

      analysis_data = JSON.parse(analyze_output)
      expect(analysis_data).to have_key("status")
      expect(analysis_data).to have_key("repository_url")
      expect(analysis_data).to have_key("remediation_plan")
    end

    it "handles validation errors correctly" do
      # Test with invalid repository URL
      output, status = Open3.capture2e("./equilibrium expected invalid-name")
      expect(status.success?).to be false
      expect(output).to include("Repository URL must be full format")
    end

    it "validates schema compliance throughout pipeline" do
      cli = Equilibrium::CLI.new

      # Generate expected tags
      expected_output = capture_stdout do
        cli.invoke(:expected, [test_repository_url])
      end

      # Validate expected output schema
      expected_data = JSON.parse(expected_output)
      schemer = JSONSchemer.schema(Equilibrium::Schemas::EXPECTED_ACTUAL)
      errors = schemer.validate(expected_data).to_a
      expect(errors).to be_empty, "Expected output should pass schema validation"

      # Generate catalog and validate
      catalog_output = capture_stdout do
        allow($stdin).to receive(:read).and_return(expected_output)
        cli.invoke(:catalog, [])
      end

      catalog_data = JSON.parse(catalog_output)
      catalog_schemer = JSONSchemer.schema(Equilibrium::Schemas::CATALOG)
      catalog_errors = catalog_schemer.validate(catalog_data).to_a
      expect(catalog_errors).to be_empty, "Catalog output should pass schema validation"
    end
  end

  describe "command help and version" do
    it "shows help for all commands" do
      commands = %w[expected actual catalog analyze version]

      commands.each do |command|
        output, status = Open3.capture2("./equilibrium help #{command}")
        expect(status.success?).to be true
        expect(output).to include("Usage:")
      end
    end

    it "shows version information" do
      output, status = Open3.capture2("./equilibrium version")
      expect(status.success?).to be true
      expect(output).to include("Equilibrium v")
      expect(output).to include("Container tag validation tool")
    end

    it "shows main help when no command specified" do
      output, status = Open3.capture2("./equilibrium help")
      expect(status.success?).to be true
      expect(output).to include("Commands:")
      expect(output).to include("expected")
      expect(output).to include("actual")
      expect(output).to include("catalog")
      expect(output).to include("analyze")
    end
  end

  describe "error handling" do
    it "handles network errors gracefully" do
      # Stub a network error
      stub_request(:get, "https://gcr.io/v2/test-project/test-image/tags/list")
        .to_raise(SocketError.new("Network unreachable"))

      output, status = Open3.capture2e("./equilibrium expected #{test_repository_url}")
      expect(status.success?).to be false
      expect(output).to include("Request failed")
    end

    it "handles invalid JSON input to catalog command" do
      invalid_json = "{ invalid json"

      output, status = Open3.capture2e("./equilibrium catalog", stdin_data: invalid_json)
      expect(status.success?).to be false
      expect(output).to include("JSON")
    end

    it "validates required options for analyze command" do
      output, status = Open3.capture2e("./equilibrium analyze")
      expect(status.success?).to be false
      expect(output).to include("required")
    end
  end

  describe "Unix pipeline compatibility" do
    it "works with jq for JSON processing" do
      # Test that output can be processed with jq
      cli = Equilibrium::CLI.new
      expected_output = capture_stdout do
        cli.invoke(:expected, [test_repository_url])
      end

      # Extract repository name using jq
      repo_name, status = Open3.capture2("jq -r '.repository_name'", stdin_data: expected_output)
      expect(status.success?).to be true
      expect(repo_name.strip).to eq("test-image")

      # Count tags using jq
      tag_count, status = Open3.capture2("jq '.tags | length'", stdin_data: expected_output)
      expect(status.success?).to be true
      expect(tag_count.strip.to_i).to be > 0
    end

    it "supports file input and output redirection" do
      cli = Equilibrium::CLI.new

      # Test file-based workflow
      expected_file = Tempfile.new(["expected", ".json"])

      begin
        # Generate expected tags to file
        expected_output = capture_stdout do
          cli.invoke(:expected, [test_repository_url])
        end
        expected_file.write(expected_output)
        expected_file.close
        expect(File.exist?(expected_file.path)).to be true
        expect(File.size(expected_file.path)).to be > 0

        # Use file as input to catalog
        catalog_output = capture_stdout do
          cli.invoke(:catalog, [expected_file.path])
        end

        catalog_data = JSON.parse(catalog_output)
        expect(catalog_data).to have_key("images")
      ensure
        expected_file.unlink
      end
    end
  end

  describe "repository URL format validation" do
    let(:valid_urls) do
      [
        "gcr.io/project/image",
        "registry.example.com/namespace/repo",
        "my-registry.com/org/team/service"
      ]
    end

    let(:invalid_urls) do
      [
        "short-name",
        "just-one-part",
        "gcr.io/only-project"
      ]
    end

    it "accepts valid repository URLs" do
      cli = Equilibrium::CLI.new

      valid_urls.each do |url|
        stub_registry_api(url)
        expect {
          capture_stdout do
            cli.invoke(:expected, [url])
          end
        }.not_to raise_error
      end
    end

    it "rejects invalid repository URLs" do
      cli = Equilibrium::CLI.new

      invalid_urls.each do |url|
        expect {
          cli.expected(url)
        }.to raise_error(StandardError)
      end
    end
  end
end
