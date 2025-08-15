# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/equilibrium/canonical_version_mapper"

RSpec.describe Equilibrium::CanonicalVersionMapper do
  describe ".map_to_canonical_versions" do
    let(:mutable_tags) do
      {
        "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1.2" => "sha256:def456789012345678901234567890123456789012345678901234567890abcd"
      }
    end

    let(:semantic_tags) do
      {
        "1.2.3" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1.2.2" => "sha256:def456789012345678901234567890123456789012345678901234567890abcd",
        "1.1.0" => "sha256:012345678901234567890123456789012345678901234567890123456789abcd"
      }
    end

    it "maps mutable tags to semantic versions by digest matching" do
      result = described_class.map_to_canonical_versions(mutable_tags, semantic_tags)

      expect(result["latest"]).to eq("1.2.3")
      expect(result["1"]).to eq("1.2.3")
      expect(result["1.2"]).to eq("1.2.2")
    end

    it "returns empty hash for empty input" do
      result = described_class.map_to_canonical_versions({}, {})

      expect(result).to eq({})
    end

    it "handles mutable tags without matching semantic versions" do
      mutable_tags_no_match = {
        "latest" => "sha256:nonexistent1234567890123456789012345678901234567890123456789012"
      }

      result = described_class.map_to_canonical_versions(mutable_tags_no_match, semantic_tags)

      expect(result).to eq({})
    end

    it "only includes tags with matching digests" do
      mixed_tags = {
        "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd", # matches 1.2.3
        "dev" => "sha256:nonexistent1234567890123456789012345678901234567890123456789012"      # no match
      }

      result = described_class.map_to_canonical_versions(mixed_tags, semantic_tags)

      expect(result).to eq({"latest" => "1.2.3"})
    end

    it "handles multiple tags with same digest" do
      same_digest_tags = {
        "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "stable" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd"
      }

      result = described_class.map_to_canonical_versions(same_digest_tags, semantic_tags)

      expect(result["latest"]).to eq("1.2.3")
      expect(result["1"]).to eq("1.2.3")
      expect(result["stable"]).to eq("1.2.3")
    end

    it "handles semantic tags with no matching mutable tags" do
      empty_mutable = {}
      non_empty_semantic = {
        "1.2.3" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd"
      }

      result = described_class.map_to_canonical_versions(empty_mutable, non_empty_semantic)

      expect(result).to eq({})
    end
  end
end
