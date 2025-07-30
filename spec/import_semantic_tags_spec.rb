require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"
require "tty-command"
require "climate_control"
require_relative "support/mock_gcloud"

RSpec.describe "import-semantic-tags.sh" do
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

  context "with no arguments" do
    it "shows usage message" do
      expect {
        cmd.run("./src/import-semantic-tags.sh")
      }.to raise_error(TTY::Command::ExitError) do |error|
        expect(error.message).to include("Usage:")
      end
    end
  end

  context "with mocked gcloud" do
    let(:mock_gcloud_script) { File.join(Dir.pwd, "tmp", "mock_gcloud_semantic.sh") }

    before do
      MockGcloud.semantic_tags_script(mock_gcloud_script)
    end

    around do |example|
      ClimateControl.modify GCLOUD_CMD: mock_gcloud_script do
        example.run
      end
    end

    it "creates output directory" do
      result = cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      expect(result.success?).to be true
      expect(Dir.exist?(output_dir)).to be true
    end

    it "stores registry name" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      expect(File.read("#{output_dir}/registry.txt").strip).to eq(test_registry)
    end

    it "creates semantic_versions.json file" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")
      expect(File.exist?("#{output_dir}/semantic_versions.json")).to be true
    end

    it "filters semantic version tags correctly" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      semantic_data = JSON.parse(File.read("#{output_dir}/semantic_versions.json"))

      expect(semantic_data.keys).to match_array(["1.2.3", "1.2.2", "2.0.0", "2.0.1"])
      expect(semantic_data.keys).not_to include("latest")
    end

    it "excludes v-prefixed tags" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      semantic_data = JSON.parse(File.read("#{output_dir}/semantic_versions.json"))

      # Should not include any v-prefixed versions (testing jq filter)
      v_prefixed_keys = semantic_data.keys.select { |k| k.start_with?("v") }
      expect(v_prefixed_keys).to be_empty

      # Verify raw data had v-prefixed tags (so our filter is actually working)
      raw_data = MockGcloud::RAW_GCLOUD_RESPONSE
      raw_v_tags = raw_data.select { |item| item["tags"].start_with?("v") }
      expect(raw_v_tags).not_to be_empty # Raw data should have v-tags
    end

    it "excludes non-semantic version tags from raw data" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      semantic_data = JSON.parse(File.read("#{output_dir}/semantic_versions.json"))

      # Should not include latest, main, dev, sha256 tags
      expect(semantic_data.keys).not_to include("latest", "main", "dev")
      expect(semantic_data.keys).not_to include("1", "1.2", "2", "2.0") # mutable tags

      # Should not include sha256 digest tags
      sha_tags = semantic_data.keys.select { |k| k.start_with?("sha256:") }
      expect(sha_tags).to be_empty
    end

    it "applies correct jq regex pattern for semantic versions" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      semantic_data = JSON.parse(File.read("#{output_dir}/semantic_versions.json"))

      # All keys should match the semantic version pattern: x.y.z
      semantic_data.keys.each do |key|
        expect(key).to match(/^\d+\.\d+\.\d+$/)
      end

      # Verify we have expected count (testing jq filter effectiveness)
      expected_semantic_count = MockGcloud::RAW_GCLOUD_RESPONSE.count do |item|
        /^\d+\.\d+\.\d+$/.match?(item["tags"])
      end
      expect(semantic_data.keys.count).to eq(expected_semantic_count)
    end

    it "includes correct digest mappings" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      semantic_data = JSON.parse(File.read("#{output_dir}/semantic_versions.json"))
      expect(semantic_data["2.0.1"]).to eq("sha256:jkl012")
      expect(semantic_data["2.0.0"]).to eq("sha256:ghi789")
      expect(semantic_data["1.2.3"]).to eq("sha256:abc123")
      expect(semantic_data["1.2.2"]).to eq("sha256:def456")
    end

    it "generates valid JSON format" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      # Should not raise JSON parse error
      expect { JSON.parse(File.read("#{output_dir}/semantic_versions.json")) }.not_to raise_error
    end

    it "sorts tags in reverse order" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      semantic_data = JSON.parse(File.read("#{output_dir}/semantic_versions.json"))
      keys = semantic_data.keys

      # Should be sorted in reverse order
      expect(keys).to eq(keys.sort.reverse)
    end

    it "generates expected mutable tags" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      expect(File.exist?("#{output_dir}/expected_mutable_tags.json")).to be true

      expected_data = JSON.parse(File.read("#{output_dir}/expected_mutable_tags.json"))
      expect(expected_data).to have_key("latest")
      expect(expected_data).to have_key("2")
      expect(expected_data).to have_key("1")
    end

    it "generates expected mutable tags with correct mappings" do
      cmd.run("./src/import-semantic-tags.sh #{test_registry}")

      expected_data = JSON.parse(File.read("#{output_dir}/expected_mutable_tags.json"))

      # Latest should point to highest version (2.0.1)
      expect(expected_data["latest"]).to eq("sha256:jkl012")

      # Major version 2 should point to 2.0.1
      expect(expected_data["2"]).to eq("sha256:jkl012")

      # Major version 1 should point to highest 1.x.x (1.2.3)
      expect(expected_data["1"]).to eq("sha256:abc123")
    end

    it "handles registry name sanitization" do
      special_registry = "gcr.io/test-project/my-image"
      special_safe_name = "gcr_io_test_project_my_image"
      special_output_dir = "fixtures/#{special_safe_name}"

      cmd.run("./src/import-semantic-tags.sh #{special_registry}")

      expect(Dir.exist?(special_output_dir)).to be true
      expect(File.read("#{special_output_dir}/registry.txt").strip).to eq(special_registry)

      # Clean up
      FileUtils.rm_rf(special_output_dir) if Dir.exist?(special_output_dir)
    end
  end
end
