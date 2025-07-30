require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"
require "tty-command"
require "climate_control"
require_relative "support/mock_gcloud"

RSpec.describe "import-mutable-tags.sh" do
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
        cmd.run("./src/import-mutable-tags.sh")
      }.to raise_error(TTY::Command::ExitError) do |error|
        expect(error.message).to include("Usage:")
      end
    end
  end

  context "with mocked gcloud" do
    let(:mock_gcloud_script) { File.join(Dir.pwd, "tmp", "mock_gcloud_mutable.sh") }

    before do
      MockGcloud.mutable_tags_script(mock_gcloud_script)
    end

    around do |example|
      ClimateControl.modify GCLOUD_CMD: mock_gcloud_script do
        example.run
      end
    end

    it "creates output directory" do
      result = cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      expect(result.success?).to be true
      expect(Dir.exist?(output_dir)).to be true
    end

    it "stores registry name" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      expect(File.read("#{output_dir}/registry.txt").strip).to eq(test_registry)
    end

    it "creates actual_mutable_tags.json file" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      expect(File.exist?("#{output_dir}/actual_mutable_tags.json")).to be true
    end

    it "filters mutable tags correctly" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # Should include latest, major versions, and minor versions
      expect(mutable_data.keys).to include("latest", "1", "1.2", "2", "2.0")

      # Should exclude semantic versions and v-prefixed tags
      expect(mutable_data.keys).not_to include("1.2.3", "v1.2.3")
    end

    it "includes latest tag" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))
      expect(mutable_data).to have_key("latest")
    end

    it "includes major version tags" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # Should include major version tags (single digits)
      major_tags = mutable_data.keys.select { |k| /^\d+$/.match?(k) }
      expect(major_tags).to include("1", "2")
    end

    it "includes minor version tags" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # Should include minor version tags (major.minor format)
      minor_tags = mutable_data.keys.select { |k| /^\d+\.\d+$/.match?(k) }
      expect(minor_tags).to include("1.2", "2.0")
    end

    it "excludes semantic version tags" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # Should not include full semantic versions
      semantic_tags = mutable_data.keys.select { |k| /^\d+\.\d+\.\d+$/.match?(k) }
      expect(semantic_tags).to be_empty
    end

    it "excludes v-prefixed tags" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # Should not include v-prefixed tags (testing jq filter)
      v_prefixed_tags = mutable_data.keys.select { |k| k.start_with?("v") }
      expect(v_prefixed_tags).to be_empty

      # Verify raw data had v-prefixed tags (so our filter is actually working)
      raw_data = MockGcloud::RAW_GCLOUD_RESPONSE
      raw_v_tags = raw_data.select { |item| item["tags"].start_with?("v") }
      expect(raw_v_tags).not_to be_empty # Raw data should have v-tags
    end

    it "excludes non-mutable tags from raw data" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # Should not include branch names or sha256 digest tags
      expect(mutable_data.keys).not_to include("main", "dev")

      # Should not include sha256 digest tags
      sha_tags = mutable_data.keys.select { |k| k.start_with?("sha256:") }
      expect(sha_tags).to be_empty

      # Should not include full semantic versions
      full_semantic = mutable_data.keys.select { |k| /^\d+\.\d+\.\d+$/.match?(k) }
      expect(full_semantic).to be_empty
    end

    it "applies correct jq regex patterns for mutable tags" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      # All keys should match mutable tag patterns: latest, major, or minor versions
      mutable_data.keys.each do |key|
        expect(key).to match(/^(latest|\d+|\d+\.\d+)$/)
      end

      # Verify we have expected count (testing jq filter effectiveness)
      expected_mutable_count = MockGcloud::RAW_GCLOUD_RESPONSE.count do |item|
        tag = item["tags"]
        tag == "latest" || /^\d+$/.match?(tag) || /^\d+\.\d+$/.match?(tag)
      end
      expect(mutable_data.keys.count).to eq(expected_mutable_count)
    end

    it "sorts tags in reverse order" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))
      keys = mutable_data.keys

      # Should be sorted in reverse order
      expect(keys).to eq(keys.sort.reverse)
    end

    it "includes correct digest mappings" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      mutable_data = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))
      expect(mutable_data["latest"]).to eq("sha256:jkl012")
      expect(mutable_data["2"]).to eq("sha256:jkl012")
      expect(mutable_data["1"]).to eq("sha256:abc123")
      expect(mutable_data["1.2"]).to eq("sha256:abc123")
      expect(mutable_data["2.0"]).to eq("sha256:jkl012")
    end

    it "generates valid JSON format" do
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")

      # Should not raise JSON parse error
      expect { JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json")) }.not_to raise_error
    end

    it "handles registry name sanitization" do
      special_registry = "gcr.io/test-project/my-image"
      special_safe_name = "gcr_io_test_project_my_image"
      special_output_dir = "fixtures/#{special_safe_name}"

      cmd.run("./src/import-mutable-tags.sh #{special_registry}")

      expect(Dir.exist?(special_output_dir)).to be true
      expect(File.read("#{special_output_dir}/registry.txt").strip).to eq(special_registry)

      # Clean up
      FileUtils.rm_rf(special_output_dir) if Dir.exist?(special_output_dir)
    end

    it "produces consistent results across multiple runs" do
      # Run twice and compare results
      cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      first_result = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      cmd.run("./src/import-mutable-tags.sh #{test_registry}")
      second_result = JSON.parse(File.read("#{output_dir}/actual_mutable_tags.json"))

      expect(first_result).to eq(second_result)
    end
  end
end
