# frozen_string_literal: true

module Equilibrium
  class CanonicalVersionMapper
    def self.map_to_canonical_versions(mutable_tags, semantic_tags)
      canonical_versions = {}

      mutable_tags.each do |mutable_tag, m_digest|
        # Find semantic tag with same digest, raise if not found
        canonical_version = semantic_tags.key(m_digest) ||
          (raise "No semantic tag found with digest #{m_digest} for mutable tag '#{mutable_tag}'")

        canonical_versions[mutable_tag] = canonical_version
      end

      canonical_versions
    end
  end
end
