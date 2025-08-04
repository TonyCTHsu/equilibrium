# frozen_string_literal: true

require "spec_helper"
require "digest"
require_relative "../lib/equilibrium/tag_processor"

RSpec.describe Equilibrium::TagProcessor do
  let(:processor) { described_class.new }

  # Generate consistent SHA256 digests for test data
  let(:latest_digest) { "sha256:#{Digest::SHA256.hexdigest("latest-1.2.3")}" }
  let(:v123_digest) { "sha256:#{Digest::SHA256.hexdigest("1.2.3")}" }
  let(:v122_digest) { "sha256:#{Digest::SHA256.hexdigest("1.2.2")}" }
  let(:v121_digest) { "sha256:#{Digest::SHA256.hexdigest("1.2.1")}" }
  let(:v110_digest) { "sha256:#{Digest::SHA256.hexdigest("1.1.0")}" }
  let(:v100_digest) { "sha256:#{Digest::SHA256.hexdigest("1.0.0")}" }
  let(:v090_digest) { "sha256:#{Digest::SHA256.hexdigest("0.9.0")}" }
  let(:v081_digest) { "sha256:#{Digest::SHA256.hexdigest("0.8.1")}" }
  let(:vwx_digest) { "sha256:#{Digest::SHA256.hexdigest("v1.2.3")}" }
  let(:main_digest) { "sha256:#{Digest::SHA256.hexdigest("main")}" }
  let(:dev_digest) { "sha256:#{Digest::SHA256.hexdigest("dev")}" }
  let(:existing1_digest) { "sha256:#{Digest::SHA256.hexdigest("existing-1")}" }
  let(:existing12_digest) { "sha256:#{Digest::SHA256.hexdigest("existing-1.2")}" }

  let(:sample_tags) do
    {
      "latest" => latest_digest,
      "1.2.3" => v123_digest,   # Latest version
      "1.2.2" => v122_digest,
      "1.2.1" => v121_digest,
      "1.1.0" => v110_digest,
      "1.0.0" => v100_digest,
      "0.9.0" => v090_digest,   # Latest 0.x
      "0.8.1" => v081_digest,
      "v1.2.3" => vwx_digest,  # Should be filtered out
      "main" => main_digest,   # Should be filtered out
      "dev" => dev_digest,    # Should be filtered out
      "1" => existing1_digest,    # Existing mutable tag
      "1.2" => existing12_digest  # Existing mutable tag
    }
  end

  describe "#filter_semantic_tags" do
    it "returns only semantic version tags" do
      result = processor.filter_semantic_tags(sample_tags)

      expected_tags = %w[1.2.3 1.2.2 1.2.1 1.1.0 1.0.0 0.9.0 0.8.1]
      expect(result.keys).to match_array(expected_tags)
    end

    it "excludes non-semantic tags" do
      result = processor.filter_semantic_tags(sample_tags)

      excluded_tags = %w[latest v1.2.3 main dev 1 1.2]
      excluded_tags.each do |tag|
        expect(result).not_to have_key(tag)
      end
    end

    it "preserves digests for semantic tags" do
      result = processor.filter_semantic_tags(sample_tags)

      expect(result["1.2.3"]).to eq(v123_digest)
      expect(result["0.9.0"]).to eq(v090_digest)
    end

    it "handles empty input" do
      result = processor.filter_semantic_tags({})
      expect(result).to be_empty
    end

    it "handles tags with prerelease suffixes" do
      tags_with_prerelease = {
        "1.0.0-alpha" => "sha256:#{Digest::SHA256.hexdigest("1.0.0-alpha")}",
        "1.0.0-beta.1" => "sha256:#{Digest::SHA256.hexdigest("1.0.0-beta.1")}",
        "1.0.0-rc.1" => "sha256:#{Digest::SHA256.hexdigest("1.0.0-rc.1")}",
        "1.0.0" => "sha256:#{Digest::SHA256.hexdigest("1.0.0-release")}"
      }

      result = processor.filter_semantic_tags(tags_with_prerelease)

      # Should only include pure semantic versions
      expect(result.keys).to eq(["1.0.0"])
      expect(result["1.0.0"]).to eq("sha256:#{Digest::SHA256.hexdigest("1.0.0-release")}")
    end
  end

  describe "#filter_mutable_tags" do
    it "returns only mutable tags" do
      result = processor.filter_mutable_tags(sample_tags)

      expected_patterns = /^(latest|\d+|\d+\.\d+)$/
      result.keys.each do |tag|
        expect(tag).to match(expected_patterns)
      end
    end

    it "includes latest tag" do
      result = processor.filter_mutable_tags(sample_tags)
      expect(result).to have_key("latest")
    end

    it "includes major version tags" do
      result = processor.filter_mutable_tags(sample_tags)
      expect(result).to have_key("1")
    end

    it "includes minor version tags" do
      result = processor.filter_mutable_tags(sample_tags)
      expect(result).to have_key("1.2")
    end

    it "excludes semantic version tags" do
      result = processor.filter_mutable_tags(sample_tags)

      semantic_tags = %w[1.2.3 1.2.2 1.1.0 0.9.0]
      semantic_tags.each do |tag|
        expect(result).not_to have_key(tag)
      end
    end

    it "excludes branch and v-prefixed tags" do
      result = processor.filter_mutable_tags(sample_tags)

      excluded_tags = %w[v1.2.3 main dev]
      excluded_tags.each do |tag|
        expect(result).not_to have_key(tag)
      end
    end
  end

  describe "#compute_virtual_tags" do
    let(:semantic_tags) do
      {
        "1.2.3" => v123_digest,  # Latest overall
        "1.2.2" => v122_digest,
        "1.2.1" => v121_digest,
        "1.1.0" => v110_digest,
        "1.0.0" => v100_digest,
        "0.9.0" => v090_digest,  # Latest 0.x
        "0.8.1" => v081_digest
      }
    end

    it "computes latest tag correctly" do
      result = processor.compute_virtual_tags(semantic_tags)
      expect(result["latest"]).to eq(v123_digest) # 1.2.3
    end

    it "computes major version tags correctly" do
      result = processor.compute_virtual_tags(semantic_tags)

      expect(result["1"]).to eq(v123_digest) # Latest 1.x.x (1.2.3)
      expect(result["0"]).to eq(v090_digest) # Latest 0.x.x (0.9.0)
    end

    it "computes minor version tags correctly" do
      result = processor.compute_virtual_tags(semantic_tags)

      expect(result["1.2"]).to eq(v123_digest) # Latest 1.2.x (1.2.3)
      expect(result["1.1"]).to eq(v110_digest) # Latest 1.1.x (1.1.0)
      expect(result["1.0"]).to eq(v100_digest) # Latest 1.0.x (1.0.0)
      expect(result["0.9"]).to eq(v090_digest) # Latest 0.9.x (0.9.0)
      expect(result["0.8"]).to eq(v081_digest) # Latest 0.8.x (0.8.1)
    end

    it "handles single version correctly" do
      single_digest = "sha256:#{Digest::SHA256.hexdigest("2.0.0-single")}"
      single_version = {"2.0.0" => single_digest}
      result = processor.compute_virtual_tags(single_version)

      expect(result["latest"]).to eq(single_digest)
      expect(result["2"]).to eq(single_digest)
      expect(result["2.0"]).to eq(single_digest)
    end

    it "handles versions with different patch levels" do
      patch_versions = {
        "1.0.5" => "sha256:#{Digest::SHA256.hexdigest("1.0.5")}",
        "1.0.3" => "sha256:#{Digest::SHA256.hexdigest("1.0.3")}",
        "1.0.0" => "sha256:#{Digest::SHA256.hexdigest("1.0.0")}"
      }
      result = processor.compute_virtual_tags(patch_versions)

      patch5_digest = "sha256:#{Digest::SHA256.hexdigest("1.0.5")}"
      expect(result["1.0"]).to eq(patch5_digest) # Latest 1.0.x
      expect(result["1"]).to eq(patch5_digest)   # Latest 1.x.x
      expect(result["latest"]).to eq(patch5_digest)
    end

    it "is idempotent" do
      result1 = processor.compute_virtual_tags(semantic_tags)
      result2 = processor.compute_virtual_tags(semantic_tags)

      expect(result1).to eq(result2)
    end

    it "handles empty input" do
      result = processor.compute_virtual_tags({})
      expect(result).to be_empty
    end

    it "sorts versions correctly" do
      old_digest = "sha256:#{Digest::SHA256.hexdigest("0.8.1")}"
      newest_digest = "sha256:#{Digest::SHA256.hexdigest("1.2.3")}"
      middle_digest = "sha256:#{Digest::SHA256.hexdigest("1.1.0")}"
      minor_digest = "sha256:#{Digest::SHA256.hexdigest("0.9.0")}"

      unsorted_versions = {
        "0.8.1" => old_digest,
        "1.2.3" => newest_digest,
        "1.1.0" => middle_digest,
        "0.9.0" => minor_digest
      }

      result = processor.compute_virtual_tags(unsorted_versions)

      # Latest should be the highest version
      expect(result["latest"]).to eq(newest_digest) # 1.2.3
      expect(result["1"]).to eq(newest_digest)      # 1.2.3
      expect(result["0"]).to eq(minor_digest)       # 0.9.0
    end

    it "handles zero major versions" do
      zero1_digest = "sha256:#{Digest::SHA256.hexdigest("0.1.0")}"
      zero2_digest = "sha256:#{Digest::SHA256.hexdigest("0.2.0")}"
      zero15_digest = "sha256:#{Digest::SHA256.hexdigest("0.1.5")}"

      zero_major = {
        "0.1.0" => zero1_digest,
        "0.2.0" => zero2_digest,
        "0.1.5" => zero15_digest
      }

      result = processor.compute_virtual_tags(zero_major)

      expect(result["latest"]).to eq(zero2_digest) # 0.2.0
      expect(result["0"]).to eq(zero2_digest)      # 0.2.0
      expect(result["0.2"]).to eq(zero2_digest)    # 0.2.0
      expect(result["0.1"]).to eq(zero15_digest)   # 0.1.5
    end
  end

  describe "integration" do
    it "processes tags end-to-end correctly" do
      # Start with all tags
      semantic_tags = processor.filter_semantic_tags(sample_tags)
      virtual_tags = processor.compute_virtual_tags(semantic_tags)
      mutable_tags = processor.filter_mutable_tags(sample_tags)

      # Virtual tags should be computed from semantic versions
      expect(virtual_tags["latest"]).to eq(v123_digest) # 1.2.3
      expect(virtual_tags["1"]).to eq(v123_digest)      # 1.2.3
      expect(virtual_tags["1.2"]).to eq(v123_digest)    # 1.2.3

      # Mutable tags should include existing mutable tags
      expect(mutable_tags["1"]).to eq(existing1_digest)
      expect(mutable_tags["1.2"]).to eq(existing12_digest)
      expect(mutable_tags["latest"]).to eq(latest_digest)
    end
  end
end
