# frozen_string_literal: true

require "json"

module Equilibrium
  class TagProcessor
    def self.compute_virtual_tags(semantic_tags)
      new.compute_virtual_tags(semantic_tags)
    end

    def compute_virtual_tags(semantic_tags)
      return {} if semantic_tags.empty?

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

      # Build result
      result = {}
      result["latest"] = semantic_tags[latest_version.to_s] if latest_version

      major_versions.each { |_, v| result[v.segments[0].to_s] = semantic_tags[v.to_s] }
      minor_versions.each { |_, v| result["#{v.segments[0]}.#{v.segments[1]}"] = semantic_tags[v.to_s] }

      result
    end

    def filter_semantic_tags(all_tags)
      # Filter semantic tags (canonical_tags.json): exact major.minor.patch format
      filtered = all_tags.select { |tag, _| semantic_version?(tag) }
      # Sort by key in reverse order (matching original jq: sort_by(.key) | reverse)
      filtered.sort_by { |tag, _| tag }.reverse.to_h
    end

    def filter_mutable_tags(all_tags)
      # Filter mutable tags (actual_tags.json): latest, digits, or major.minor format
      filtered = all_tags.select { |tag, _| mutable_tag?(tag) }
      # Sort by key in reverse order (matching original jq: sort_by(.key) | reverse)
      filtered.sort_by { |tag, _| tag }.reverse.to_h
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
