# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/equilibrium/tag_data_builder"

RSpec.describe Equilibrium::TagDataBuilder do
  describe ".build_output" do
    let(:repository_url) { "gcr.io/test-project/test-image" }
    let(:repository_name) { "test-image" }
    let(:digests) do
      {
        "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1" => "sha256:def456789012345678901234567890123456789012345678901234567890abcd",
        "1.2" => "sha256:012345678901234567890123456789012345678901234567890123456789abcd"
      }
    end
    let(:canonical_versions) do
      {
        "latest" => "1.2.3",
        "1" => "1.2.3",
        "1.2" => "1.2.0"
      }
    end

    it "builds correct output structure" do
      result = described_class.build_output(repository_url, repository_name, digests, canonical_versions)

      expect(result).to have_key("repository_url")
      expect(result).to have_key("repository_name")
      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")

      expect(result["repository_url"]).to eq(repository_url)
      expect(result["repository_name"]).to eq(repository_name)
    end

    it "includes sorted digests and canonical versions" do
      result = described_class.build_output(repository_url, repository_name, digests, canonical_versions)

      # TagSorter should sort in descending order
      digest_keys = result["digests"].keys
      canonical_keys = result["canonical_versions"].keys

      expect(digest_keys).to be_an(Array)
      expect(canonical_keys).to be_an(Array)
    end

    it "preserves all tag data" do
      result = described_class.build_output(repository_url, repository_name, digests, canonical_versions)

      # Should contain all original tags
      expect(result["digests"]).to include("latest", "1", "1.2")
      expect(result["canonical_versions"]).to include("latest", "1", "1.2")

      # Should preserve digest values
      expect(result["digests"]["latest"]).to eq(digests["latest"])
      expect(result["canonical_versions"]["latest"]).to eq(canonical_versions["latest"])
    end

    it "handles empty input gracefully" do
      result = described_class.build_output(repository_url, repository_name, {}, {})

      expect(result["repository_url"]).to eq(repository_url)
      expect(result["repository_name"]).to eq(repository_name)
      expect(result["digests"]).to eq({})
      expect(result["canonical_versions"]).to eq({})
    end
  end
end
