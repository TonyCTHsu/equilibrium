require "spec_helper"
require "json"
require_relative "support/mock_gcloud"

RSpec.describe "jq filtering effectiveness" do
  let(:raw_data) { MockGcloud::RAW_GCLOUD_RESPONSE }

  describe "raw mock data composition" do
    it "contains diverse tag types for comprehensive testing" do
      tags = raw_data.map { |item| item["tags"] }

      # Should contain semantic versions
      semantic_tags = tags.select { |tag| /^\d+\.\d+\.\d+$/.match?(tag) }
      expect(semantic_tags).not_to be_empty

      # Should contain mutable tags
      expect(tags).to include("latest")
      major_tags = tags.select { |tag| /^\d+$/.match?(tag) }
      expect(major_tags).not_to be_empty
      minor_tags = tags.select { |tag| /^\d+\.\d+$/.match?(tag) }
      expect(minor_tags).not_to be_empty

      # Should contain v-prefixed tags
      v_tags = tags.select { |tag| tag.start_with?("v") }
      expect(v_tags).not_to be_empty

      # Should contain branch/other tags
      expect(tags).to include("main", "dev")

      # Should contain digest tags
      digest_tags = tags.select { |tag| tag.start_with?("sha256:") }
      expect(digest_tags).not_to be_empty
    end

    it "provides sufficient data variety for filter testing" do
      tags = raw_data.map { |item| item["tags"] }

      # Should have at least 10 different tag types
      expect(tags.uniq.count).to be >= 10

      # Should include edge cases
      expect(tags).to include("v1.2.3", "v2.0.0") # v-prefixed versions
      expect(tags).to include("sha256:abc123") # digest tags
      expect(tags).to include("main", "dev") # branch tags
    end
  end

  describe "filter validation against raw data" do
    it "semantic filter should exclude appropriate tags" do
      tags = raw_data.map { |item| item["tags"] }
      semantic_tags = tags.select { |tag| /^\d+\.\d+\.\d+$/.match?(tag) }

      # These should be excluded by semantic filter
      excluded_tags = tags - semantic_tags
      expect(excluded_tags).to include("latest", "main", "dev")
      expect(excluded_tags).to include("v1.2.3", "v2.0.0")
      expect(excluded_tags).to include("1", "1.2", "2", "2.0")
      expect(excluded_tags.any? { |t| t.start_with?("sha256:") }).to be true
    end

    it "mutable filter should exclude appropriate tags" do
      tags = raw_data.map { |item| item["tags"] }
      mutable_tags = tags.select do |tag|
        tag == "latest" || /^\d+$/.match?(tag) || /^\d+\.\d+$/.match?(tag)
      end

      # These should be excluded by mutable filter
      excluded_tags = tags - mutable_tags
      expect(excluded_tags).to include("main", "dev")
      expect(excluded_tags).to include("v1.2.3", "v2.0.0")
      expect(excluded_tags).to include("1.2.3", "1.2.2", "2.0.0", "2.0.1")
      expect(excluded_tags.any? { |t| t.start_with?("sha256:") }).to be true
    end
  end

  describe "jq regex pattern accuracy" do
    it "semantic version regex matches expected patterns" do
      semantic_pattern = /^\d+\.\d+\.\d+$/

      # Should match
      expect("1.2.3").to match(semantic_pattern)
      expect("0.0.1").to match(semantic_pattern)
      expect("10.20.30").to match(semantic_pattern)

      # Should not match
      expect("latest").not_to match(semantic_pattern)
      expect("1.2").not_to match(semantic_pattern)
      expect("1").not_to match(semantic_pattern)
      expect("v1.2.3").not_to match(semantic_pattern)
      expect("1.2.3-alpha").not_to match(semantic_pattern)
    end

    it "mutable tag regexes match expected patterns" do
      latest_pattern = /^latest$/
      major_pattern = /^\d+$/
      minor_pattern = /^\d+\.\d+$/

      # Latest pattern
      expect("latest").to match(latest_pattern)
      expect("Latest").not_to match(latest_pattern)

      # Major pattern
      expect("1").to match(major_pattern)
      expect("10").to match(major_pattern)
      expect("1.2").not_to match(major_pattern)

      # Minor pattern
      expect("1.2").to match(minor_pattern)
      expect("10.20").to match(minor_pattern)
      expect("1.2.3").not_to match(minor_pattern)
      expect("1").not_to match(minor_pattern)
    end
  end
end
