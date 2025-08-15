# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/equilibrium/repository_tags_service"

RSpec.describe Equilibrium::RepositoryTagsService do
  include EquilibriumTestHelpers

  let(:test_repository_url) { "gcr.io/test-project/test-image" }

  before do
    stub_registry_api(test_repository_url)
  end

  describe ".generate_expected_tags" do
    it "returns expected tag data structure" do
      result = described_class.generate_expected_tags(test_repository_url)

      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")
      expect(result["digests"]).to be_a(Hash)
      expect(result["canonical_versions"]).to be_a(Hash)
    end

    it "generates correct virtual tags" do
      result = described_class.generate_expected_tags(test_repository_url)

      # Should have latest pointing to highest version (1.2.3)
      expect(result["digests"]["latest"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")
      expect(result["canonical_versions"]["latest"]).to eq("1.2.3")
    end
  end

  describe ".generate_actual_tags" do
    it "returns actual tag data structure" do
      result = described_class.generate_actual_tags(test_repository_url)

      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")
      expect(result["digests"]).to be_a(Hash)
      expect(result["canonical_versions"]).to be_a(Hash)
    end

    it "includes only mutable tags" do
      result = described_class.generate_actual_tags(test_repository_url)

      # Should include mutable tags
      expect(result["digests"].keys).to include("latest")

      # Should exclude semantic version tags and branch names
      expect(result["digests"].keys).not_to include("1.2.3", "v1.2.3", "main", "dev")
    end

    it "maps mutable tags to canonical versions" do
      result = described_class.generate_actual_tags(test_repository_url)

      # Should have canonical version mappings for mutable tags
      result["digests"].keys.each do |tag|
        if result["canonical_versions"][tag]
          expect(result["canonical_versions"][tag]).to match(/^\d+\.\d+\.\d+$/)
        end
      end
    end
  end
end
