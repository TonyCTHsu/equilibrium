# frozen_string_literal: true

require "spec_helper"
require "rantly/rspec_extensions"

RSpec.describe Equilibrium::TagProcessor do
  describe "property-based tests for virtual tag computation" do
    it "compute_virtual_tags always produces valid mutable tags" do
      property_of {
        semantic_tags = {}
        range(1, 8).times do
          major = range(0, 5)
          minor = range(0, 10)
          patch = range(0, 15)
          version = "#{major}.#{minor}.#{patch}"
          semantic_tags[version] = "sha256:#{range(100000, 999999)}"
        end
        semantic_tags
      }.check do |semantic_tags|
        processor = Equilibrium::TagProcessor.new
        result = processor.compute_virtual_tags(semantic_tags)

        result["digests"].keys.each do |virtual_tag|
          expect(processor.send(:mutable_tag?, virtual_tag)).to be true
        end

        result["canonical_versions"].keys.each do |virtual_tag|
          expect(processor.send(:mutable_tag?, virtual_tag)).to be true
        end
      end
    end

    it "compute_virtual_tags produces consistent digest and canonical_version mappings" do
      property_of {
        semantic_tags = {}
        range(1, 6).times do
          major = range(0, 3)
          minor = range(0, 5)
          patch = range(0, 10)
          version = "#{major}.#{minor}.#{patch}"
          semantic_tags[version] = "sha256:#{range(100000, 999999)}"
        end
        semantic_tags
      }.check do |semantic_tags|
        result = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)

        expect(result["digests"].keys.sort).to eq(result["canonical_versions"].keys.sort)

        # Each virtual tag should map to a valid semantic version that exists in input
        result["canonical_versions"].each do |virtual_tag, canonical_version|
          expect(semantic_tags).to have_key(canonical_version)
          expect(result["digests"][virtual_tag]).to eq(semantic_tags[canonical_version])
        end
      end
    end

    it "latest tag always points to highest semantic version" do
      property_of {
        semantic_tags = {}
        range(2, 6).times do
          major = range(0, 3)
          minor = range(0, 5)
          patch = range(0, 10)
          version = "#{major}.#{minor}.#{patch}"
          semantic_tags[version] = "sha256:#{range(100000, 999999)}"
        end
        semantic_tags
      }.check do |semantic_tags|
        result = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)

        if result["canonical_versions"]["latest"]
          highest_version = semantic_tags.keys.map { |v| Gem::Version.new(v) }.max.to_s
          expect(result["canonical_versions"]["latest"]).to eq(highest_version)
        end
      end
    end

    it "major version tags point to highest patch for that major" do
      property_of {
        # Generate versions within same major to ensure we have collisions
        semantic_tags = {}
        major_base = range(0, 3)
        range(2, 6).times do
          minor = range(0, 5)
          patch = range(0, 10)
          version = "#{major_base}.#{minor}.#{patch}"
          semantic_tags[version] = "sha256:#{range(100000, 999999)}"
        end
        semantic_tags
      }.check do |semantic_tags|
        result = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)

        # Group semantic versions by major
        by_major = semantic_tags.keys.group_by { |v| Gem::Version.new(v).segments[0] }

        by_major.each do |major, versions|
          major_tag = major.to_s
          if result["canonical_versions"][major_tag]
            highest_for_major = versions.map { |v| Gem::Version.new(v) }.max.to_s
            expect(result["canonical_versions"][major_tag]).to eq(highest_for_major)
          end
        end
      end
    end

    it "minor version tags point to highest patch for that major.minor" do
      property_of {
        # Generate versions within same major.minor to ensure we have collisions
        semantic_tags = {}
        major_base = range(0, 2)
        minor_base = range(0, 3)
        range(2, 5).times do
          patch = range(0, 10)
          version = "#{major_base}.#{minor_base}.#{patch}"
          semantic_tags[version] = "sha256:#{range(100000, 999999)}"
        end
        semantic_tags
      }.check do |semantic_tags|
        result = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)

        # Group semantic versions by major.minor
        by_minor = semantic_tags.keys.group_by do |v|
          segments = Gem::Version.new(v).segments
          "#{segments[0]}.#{segments[1]}"
        end

        by_minor.each do |minor_key, versions|
          if result["canonical_versions"][minor_key]
            highest_for_minor = versions.map { |v| Gem::Version.new(v) }.max.to_s
            expect(result["canonical_versions"][minor_key]).to eq(highest_for_minor)
          end
        end
      end
    end

    it "is idempotent when semantic tags don't change" do
      property_of {
        semantic_tags = {}
        range(1, 6).times do
          major = range(0, 3)
          minor = range(0, 5)
          patch = range(0, 10)
          version = "#{major}.#{minor}.#{patch}"
          semantic_tags[version] = "sha256:#{range(100000, 999999)}"
        end
        semantic_tags
      }.check do |semantic_tags|
        result1 = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)
        result2 = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)

        expect(result1).to eq(result2)
      end
    end

    it "handles edge cases gracefully" do
      property_of {
        choose(
          {},
          {"0.0.0" => "sha256:zero"},
          {"999.999.999" => "sha256:huge"},
          {"1.0.0" => "sha256:one", "2.0.0" => "sha256:two"},
          {"1.1.0" => "sha256:a", "1.1.1" => "sha256:b", "1.1.2" => "sha256:c"}
        )
      }.check do |semantic_tags|
        expect { Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags) }.not_to raise_error

        result = Equilibrium::TagProcessor.compute_virtual_tags(semantic_tags)
        expect(result).to have_key("digests")
        expect(result).to have_key("canonical_versions")
      end
    end
  end
end
