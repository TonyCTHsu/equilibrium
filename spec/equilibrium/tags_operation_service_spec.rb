# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/equilibrium/tags_operation_service"

RSpec.describe Equilibrium::TagsOperationService do
  include EquilibriumTestHelpers

  let(:service) { described_class.new }
  let(:test_repository_url) { "gcr.io/test-project/test-image" }

  before do
    stub_registry_api(test_repository_url)
  end

  describe "#generate_expected_output" do
    it "returns complete expected output structure" do
      result = service.generate_expected_output(test_repository_url)

      expect(result).to have_key("repository_url")
      expect(result).to have_key("repository_name")
      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")

      expect(result["repository_url"]).to eq(test_repository_url)
      expect(result["repository_name"]).to eq("test-image")
      expect(result["digests"]).to be_a(Hash)
      expect(result["canonical_versions"]).to be_a(Hash)
    end

    it "generates sorted expected tags" do
      result = service.generate_expected_output(test_repository_url)

      # Should have latest pointing to highest version (1.2.3)
      expect(result["digests"]["latest"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")
      expect(result["canonical_versions"]["latest"]).to eq("1.2.3")
    end

    it "validates against expected/actual schema structure" do
      result = service.generate_expected_output(test_repository_url)

      # Should have all required fields for expected/actual schema
      expect(result).to have_key("repository_url")
      expect(result).to have_key("repository_name")
      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")
    end
  end

  describe "#generate_actual_output" do
    it "returns complete actual output structure" do
      result = service.generate_actual_output(test_repository_url)

      expect(result).to have_key("repository_url")
      expect(result).to have_key("repository_name")
      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")

      expect(result["repository_url"]).to eq(test_repository_url)
      expect(result["repository_name"]).to eq("test-image")
      expect(result["digests"]).to be_a(Hash)
      expect(result["canonical_versions"]).to be_a(Hash)
    end

    it "includes only mutable tags in output" do
      result = service.generate_actual_output(test_repository_url)

      # Should include mutable tags
      expect(result["digests"].keys).to include("latest")

      # Should exclude semantic version tags and branch names
      expect(result["digests"].keys).not_to include("1.2.3", "v1.2.3", "main", "dev")
    end

    it "maps actual tags to canonical versions" do
      result = service.generate_actual_output(test_repository_url)

      # Should have canonical version mappings for mutable tags
      result["digests"].keys.each do |tag|
        if result["canonical_versions"][tag]
          expect(result["canonical_versions"][tag]).to match(/^\d+\.\d+\.\d+$/)
        end
      end
    end

    it "validates against expected/actual schema structure" do
      result = service.generate_actual_output(test_repository_url)

      # Should have all required fields for expected/actual schema
      expect(result).to have_key("repository_url")
      expect(result).to have_key("repository_name")
      expect(result).to have_key("digests")
      expect(result).to have_key("canonical_versions")
    end
  end
end
