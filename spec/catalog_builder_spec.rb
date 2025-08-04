# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/equilibrium/schemas/catalog"
require_relative "../lib/equilibrium/catalog_builder"

RSpec.describe Equilibrium::CatalogBuilder do
  let(:builder) { described_class.new }

  let(:sample_data) do
    {
      "repository_url" => "gcr.io/test-project/test-image",
      "repository_name" => "test-image",
      "digests" => {
        "latest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1.2" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
        "1.1" => "sha256:def456789012345678901234567890123456789012345678901234567890abcd",
        "0" => "sha256:012345678901234567890123456789012345678901234567890123456789abcd"
      },
      "canonical_versions" => {
        "latest" => "1.2.3",
        "1" => "1.2.3",
        "1.2" => "1.2.3",
        "1.1" => "1.1.0",
        "0" => "0.9.0"
      }
    }
  end

  # Legacy format for backward compatibility tests
  let(:sample_virtual_tags) { sample_data["digests"] }

  describe "#build_catalog" do
    it "builds catalog with correct structure" do
      catalog = builder.build_catalog(sample_data)

      expect(catalog).to have_key("images")
      expect(catalog["images"]).to be_an(Array)
      expect(catalog["images"].size).to eq(5)
    end

    it "creates correct image entries" do
      catalog = builder.build_catalog(sample_data)

      first_image = catalog["images"].first
      expect(first_image).to have_key("name")
      expect(first_image).to have_key("tag")
      expect(first_image).to have_key("digest")

      expect(first_image["name"]).to eq("test-image")
      expect(first_image["tag"]).to match(/^(latest|\d+|\d+\.\d+)$/)
      expect(first_image["digest"]).to match(/^sha256:[a-f0-9]{64}$/)
    end

    it "includes all virtual tags" do
      catalog = builder.build_catalog(sample_data)

      tags = catalog["images"].map { |img| img["tag"] }
      expect(tags).to match_array(sample_virtual_tags.keys)
    end

    it "maps tags to correct digests" do
      catalog = builder.build_catalog(sample_data)

      latest_entry = catalog["images"].find { |img| img["tag"] == "latest" }
      expect(latest_entry["digest"]).to eq(sample_virtual_tags["latest"])

      major_1_entry = catalog["images"].find { |img| img["tag"] == "1" }
      expect(major_1_entry["digest"]).to eq(sample_virtual_tags["1"])
    end

    it "validates against catalog schema" do
      catalog = builder.build_catalog(sample_data)

      schemer = JSONSchemer.schema(Equilibrium::Schemas::CATALOG)
      errors = schemer.validate(catalog).to_a

      expect(errors).to be_empty, "Catalog schema validation failed: #{errors.map(&:to_s).join("; ")}"
    end
  end

  describe "CATALOG_SCHEMA" do
    let(:schema) { Equilibrium::Schemas::CATALOG }

    it "defines correct schema structure" do
      expect(schema).to have_key("$schema")
      expect(schema).to have_key("title")
      expect(schema).to have_key("type")
      expect(schema).to have_key("properties")

      expect(schema["type"]).to eq("object")
      expect(schema["properties"]).to have_key("images")
    end

    it "validates correct catalog format" do
      valid_catalog = {
        "images" => [
          {
            "name" => "test-image",
            "tag" => "latest",
            "digest" => "sha256:abc123def456789012345678901234567890123456789012345678901234abcd",
            "canonical_version" => "1.2.3"
          },
          {
            "name" => "test-image",
            "tag" => "1",
            "digest" => "sha256:def456789012345678901234567890123456789012345678901234567890abcd",
            "canonical_version" => "1.2.3"
          }
        ]
      }

      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(valid_catalog).to_a

      expect(errors).to be_empty
    end

    it "rejects invalid catalog format" do
      invalid_catalog = {
        "images" => [
          {
            "name" => "test-image",
            "tag" => "latest"
            # Missing required "digest" field
          }
        ]
      }

      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(invalid_catalog).to_a

      expect(errors).not_to be_empty
    end

    it "rejects catalog with extra properties" do
      invalid_catalog = {
        "images" => [
          {
            "name" => "test-image",
            "tag" => "latest",
            "digest" => "sha256:abc123def456ghi789jkl012mno345pqr678stu901vwx234yzab567cdef8901",
            "extra_field" => "not_allowed"
          }
        ]
      }

      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(invalid_catalog).to_a

      expect(errors).not_to be_empty
    end

    it "validates digest format" do
      invalid_digest_catalog = {
        "images" => [
          {
            "name" => "test-image",
            "tag" => "latest",
            "digest" => "invalid-digest-format"
          }
        ]
      }

      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(invalid_digest_catalog).to_a

      expect(errors).not_to be_empty
    end

    it "allows empty images array" do
      empty_catalog = {"images" => []}

      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(empty_catalog).to_a

      expect(errors).to be_empty
    end
  end

  describe "integration with real data" do
    it "works with actual virtual tag computation results" do
      # This would be the result from expected/actual data structure
      realistic_data = {
        "repository_url" => "gcr.io/datadoghq/apm-inject",
        "repository_name" => "apm-inject",
        "digests" => {
          "latest" => "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
          "0" => "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
          "0.43" => "sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c",
          "0.42" => "sha256:c7a822d271eb72e6c3bee2aaf579c8a3732eda9710d27effdca6beb3f5f63b0e"
        },
        "canonical_versions" => {
          "latest" => "0.43.2",
          "0" => "0.43.2",
          "0.43" => "0.43.1",
          "0.42" => "0.42.3"
        }
      }

      catalog = builder.build_catalog(realistic_data)

      # Validate structure
      expect(catalog["images"].size).to eq(4)

      # Validate content
      latest_image = catalog["images"].find { |img| img["tag"] == "latest" }
      expect(latest_image["name"]).to eq("apm-inject")
      expect(latest_image["digest"]).to eq("sha256:5fcfe7ac14f6eeb0fe086ac7021d013d764af573b8c2d98113abf26b4d09b58c")

      # Validate schema compliance
      schemer = JSONSchemer.schema(Equilibrium::Schemas::CATALOG)
      errors = schemer.validate(catalog).to_a
      expect(errors).to be_empty
    end
  end
end
