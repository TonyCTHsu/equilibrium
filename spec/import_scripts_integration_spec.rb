require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"
require "tty-command"
require "climate_control"
require_relative "support/mock_gcloud"

RSpec.describe "Import scripts integration" do
  let(:test_registry) { "gcr.io/test/example" }
  let(:safe_name) { "gcr_io_test_example" }
  let(:output_dir) { "fixtures/#{safe_name}" }
  let(:cmd) { TTY::Command.new(printer: :null) }

  before do
    # Clean up any existing test fixtures
    FileUtils.rm_rf("fixtures/#{safe_name}") if Dir.exist?("fixtures/#{safe_name}")
  end

  after do
    # Clean up test fixtures
    FileUtils.rm_rf("fixtures/#{safe_name}") if Dir.exist?("fixtures/#{safe_name}")
  end

  context "when both scripts run in sequence" do
    let(:semantic_mock_script) { File.join(Dir.pwd, "tmp", "mock_gcloud_semantic_integration.sh") }
    let(:mutable_mock_script) { File.join(Dir.pwd, "tmp", "mock_gcloud_mutable_integration.sh") }

    before do
      MockGcloud.semantic_tags_script(semantic_mock_script)
      MockGcloud.mutable_tags_script(mutable_mock_script)
    end

    it "creates all required output files" do
      # Run semantic tags import first
      result1 = ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end
      expect(result1.success?).to be true

      # Run mutable tags import second
      result2 = ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end
      expect(result2.success?).to be true

      # Verify all expected files exist
      expect(File.exist?("#{output_dir}/registry.txt")).to be true
      expect(File.exist?("#{output_dir}/canonical_tags.json")).to be true
      expect(File.exist?("#{output_dir}/actual_tags.json")).to be true
      expect(File.exist?("#{output_dir}/virtual_tags.json")).to be true
    end

    it "generates valid JSON in all output files" do
      # Run both scripts
      ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end

      ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end

      # All JSON files should be valid
      expect { JSON.parse(File.read("#{output_dir}/canonical_tags.json")) }.not_to raise_error
      expect { JSON.parse(File.read("#{output_dir}/actual_tags.json")) }.not_to raise_error
      expect { JSON.parse(File.read("#{output_dir}/virtual_tags.json")) }.not_to raise_error
    end

    it "produces files compatible with equilibrium spec" do
      # Run both import scripts
      ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end

      ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end

      # Load the generated data
      actual_data = JSON.parse(File.read("#{output_dir}/actual_tags.json"))
      expected_data = JSON.parse(File.read("#{output_dir}/virtual_tags.json"))

      # Should have expected keys
      expect(actual_data).to have_key("latest")
      expect(expected_data).to have_key("latest")

      # Should have compatible structure for equilibrium testing
      expect(actual_data.keys.sort).to eq(expected_data.keys.sort)
    end

    it "maintains consistent registry information across scripts" do
      # Run both scripts
      ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end

      ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end

      # Registry name should be consistent
      registry_content = File.read("#{output_dir}/registry.txt").strip
      expect(registry_content).to eq(test_registry)
    end

    it "generates expected mutable tags that align with actual mutable tags" do
      # Run both scripts
      ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end

      ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end

      # Load data
      actual_data = JSON.parse(File.read("#{output_dir}/actual_tags.json"))
      expected_data = JSON.parse(File.read("#{output_dir}/virtual_tags.json"))

      # Key structure should match
      expect(actual_data.keys.sort).to eq(expected_data.keys.sort)

      # Common tags should have same digest values
      common_keys = actual_data.keys & expected_data.keys
      common_keys.each do |key|
        expect(actual_data[key]).to eq(expected_data[key]),
          "Mismatch for key '#{key}': actual='#{actual_data[key]}' vs expected='#{expected_data[key]}'"
      end
    end

    it "handles the workflow in proper dependency order" do
      # Mutable tags script should work even if run first (standalone)
      result1 = ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end
      expect(result1.success?).to be true
      expect(File.exist?("#{output_dir}/actual_tags.json")).to be true

      # Semantic tags script should work and generate expected tags
      result2 = ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end
      expect(result2.success?).to be true
      expect(File.exist?("#{output_dir}/virtual_tags.json")).to be true
    end

    it "produces files with correct data relationships" do
      # Run both scripts
      ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
        cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      end

      ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
        cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      end

      # Load all data
      semantic_data = JSON.parse(File.read("#{output_dir}/canonical_tags.json"))
      actual_data = JSON.parse(File.read("#{output_dir}/actual_tags.json"))
      expected_data = JSON.parse(File.read("#{output_dir}/virtual_tags.json"))

      # Expected mutable tags should be derived from semantic versions
      expect(semantic_data).to have_key("2.0.1")
      expect(semantic_data).to have_key("2.0.0")
      expect(semantic_data).to have_key("1.2.3")

      # Latest in expected should match highest semantic version (2.0.1)
      highest_version_digest = semantic_data["2.0.1"]
      expect(expected_data["latest"]).to eq(highest_version_digest)

      # Actual should have compatible structure
      expect(actual_data).to have_key("latest")
    end

    it "supports different registry formats" do
      different_registries = [
        "gcr.io/my-project/my-app",
        "us.gcr.io/another-project/service",
        "eu.gcr.io/third-project/worker"
      ]

      different_registries.each do |registry|
        safe_name = registry.gsub(/[^a-zA-Z0-9]/, "_")
        output_dir = "fixtures/#{safe_name}"

        # Run both scripts for this registry
        ClimateControl.modify(GCLOUD_CMD: semantic_mock_script) do
          cmd.run("./src/import-semantic-tags.sh #{registry}")
        end

        ClimateControl.modify(GCLOUD_CMD: mutable_mock_script) do
          cmd.run("./src/import-mutable-tags.sh #{registry}")
        end

        # Verify files created with correct registry info
        expect(File.exist?("#{output_dir}/registry.txt")).to be true
        expect(File.read("#{output_dir}/registry.txt").strip).to eq(registry)

        # Clean up
        FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
      end
    end
  end
end
