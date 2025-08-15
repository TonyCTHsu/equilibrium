# frozen_string_literal: true

require_relative "registry_client"
require_relative "tag_processor"
require_relative "canonical_version_mapper"

module Equilibrium
  class RepositoryTagsService
    def self.generate_expected_tags(repository_url)
      registry_client = RegistryClient.new(repository_url)

      tagged_digests = registry_client.tagged_digests
      semantic_tags = TagProcessor.filter_semantic_tags(tagged_digests)
      TagProcessor.compute_virtual_tags(semantic_tags)
    end

    def self.generate_actual_tags(repository_url)
      registry_client = RegistryClient.new(repository_url)

      tagged_digests = registry_client.tagged_digests
      semantic_tags = TagProcessor.filter_semantic_tags(tagged_digests)

      mutable_tags = TagProcessor.filter_mutable_tags(tagged_digests)
      canonical_versions = CanonicalVersionMapper.map_to_canonical_versions(mutable_tags, semantic_tags)

      {
        "digests" => mutable_tags,
        "canonical_versions" => canonical_versions
      }
    end
  end
end
