# frozen_string_literal: true

require "json"

module Equilibrium
  class TagProcessor
    def self.compute_virtual_tags(semantic_tags)
      new.compute_virtual_tags(semantic_tags)
    end

    def self.filter_semantic_tags(tagged_digests)
      new.filter_semantic_tags(tagged_digests)
    end

    def self.filter_mutable_tags(tagged_digests)
      new.filter_mutable_tags(tagged_digests)
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

    def filter_semantic_tags(tagged_digests)
      tagged_digests.select { |tag, _| semantic_version?(tag) }
    end

    def filter_mutable_tags(tagged_digests)
      tagged_digests.select { |tag, _| mutable_tag?(tag) }
    end

    private

    def semantic_version?(tag)
      # Strictly validate MAJOR.MINOR.PATCH format where:
      # - MAJOR, MINOR, PATCH are non-negative integers
      # - No leading zeros (except for '0' itself)
      # - No prefixes (like 'v1.2.3', 'release-1.2.3')
      # - No suffixes (like '1.2.3-alpha', '1.2.3+build')
      # - No prereleases (like '1.2.3-rc.1', '1.2.3-beta.2')
      tag.match?(/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/)
    end

    def mutable_tag?(tag)
      # Validate mutable tags: latest, major versions (digits only), or major.minor format
      # - 'latest' is the special case for the highest overall version
      # - Major versions: non-negative integers without leading zeros (e.g., '1', '0', '42')
      # - Minor versions: MAJOR.MINOR format with same zero-leading rules (e.g., '1.2', '0.9')
      tag.match?(/^(latest|(0|[1-9]\d*)(\.(0|[1-9]\d*))?)$/)
    end
  end
end
