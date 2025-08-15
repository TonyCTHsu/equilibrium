# frozen_string_literal: true

module Equilibrium
  # Maps mutable tags to their canonical semantic versions
  # Used primarily by the actual command to reverse-map tags to semantic versions
  class CanonicalVersionMapper
    # Map mutable tags to canonical versions using digest matching
    # @param mutable_tags [Hash] Hash of tag => digest mappings
    # @param semantic_tags [Hash] Hash of semantic_version => digest mappings
    # @return [Hash] Hash of tag => canonical_version mappings
    def self.map_to_canonical_versions(mutable_tags, semantic_tags)
      canonical_versions = {}

      mutable_tags.each do |mutable_tag, digest|
        # Find semantic tag with same digest
        canonical_version = semantic_tags.find { |_, sem_digest| sem_digest == digest }&.first
        canonical_versions[mutable_tag] = canonical_version if canonical_version
      end

      canonical_versions
    end
  end
end
