# frozen_string_literal: true

require "json"

module Equilibrium
  class TagProcessor
    def self.compute_virtual_tags(semantic_tags)
      new.compute_virtual_tags(semantic_tags)
    end

    def compute_virtual_tags(semantic_tags)
      return {"digests" => {}, "canonical_versions" => {}} if semantic_tags.empty?

      latest_version = nil
      major_versions = {}
      minor_versions = {}

      # Single pass to find all maximums
      semantic_tags.keys.each do |version_str|
        version = Gem::Version.new(version_str)

        # Track overall latest
        latest_version = version if !latest_version || version > latest_version

        # Track latest for each major
        major = version.segments[0]
        major_versions[major] = version if !major_versions[major] || version > major_versions[major]

        # Track latest for each minor
        major_minor = "#{version.segments[0]}.#{version.segments[1]}"
        minor_versions[major_minor] = version if !minor_versions[major_minor] || version > minor_versions[major_minor]
      end

      # Build result with both digest and canonical mappings
      digests = {}
      canonical_versions = {}

      if latest_version
        digests["latest"] = semantic_tags[latest_version.to_s]
        canonical_versions["latest"] = latest_version.to_s
      end

      major_versions.each do |_, v|
        tag = v.segments[0].to_s
        digests[tag] = semantic_tags[v.to_s]
        canonical_versions[tag] = v.to_s
      end

      minor_versions.each do |_, v|
        tag = "#{v.segments[0]}.#{v.segments[1]}"
        digests[tag] = semantic_tags[v.to_s]
        canonical_versions[tag] = v.to_s
      end

      {"digests" => digests, "canonical_versions" => canonical_versions}
    end

    def filter_semantic_tags(all_tags)
      # Filter semantic tags (canonical_tags.json): exact major.minor.patch format
      all_tags.select { |tag, _| semantic_version?(tag) }
    end

    def filter_mutable_tags(all_tags)
      # Filter mutable tags (actual_tags.json): latest, digits, or major.minor format
      all_tags.select { |tag, _| mutable_tag?(tag) }
    end

    # Sort tags in descending version order: latest first, then major versions (descending), then minor versions (descending)
    def sort_tags_descending(tags_hash)
      sorted = {}

      # Add latest first if present
      if tags_hash.key?("latest")
        sorted["latest"] = tags_hash["latest"]
      end

      # Sort other tags by version (descending)
      other_tags = tags_hash.keys.reject { |k| k == "latest" }
      sorted_tags = other_tags.sort_by do |tag|
        if tag.match?(/^[0-9]+$/)
          # Major version: sort by numeric value (descending)
          [-tag.to_i]
        elsif tag.match?(/^[0-9]+\.[0-9]+$/)
          # Minor version: sort by version (descending)
          parts = tag.split(".").map(&:to_i)
          [-parts[0], -parts[1]]
        else
          # Fallback for any unexpected formats - sort alphabetically
          [1, tag]
        end
      end

      sorted_tags.each do |tag|
        sorted[tag] = tags_hash[tag]
      end

      sorted
    end

    private

    def semantic_version?(tag)
      SemanticVersion.valid?(tag)
    end

    def mutable_tag?(tag)
      tag.match?(/^latest$/) ||
        tag.match?(/^[0-9]+$/) ||
        tag.match?(/^[0-9]+\.[0-9]+$/)
    end
  end
end
