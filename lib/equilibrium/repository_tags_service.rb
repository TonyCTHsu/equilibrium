# frozen_string_literal: true

require_relative "registry_client"
require_relative "tag_processor"
require_relative "canonical_version_mapper"

module Equilibrium
  # Service for retrieving and processing repository tag data
  # Coordinates registry client and tag processor to generate expected/actual tag data
  class RepositoryTagsService
    # Generate expected mutable tags based on semantic versions
    # @param repository_url [String] Full repository URL
    # @return [Hash] Expected tags with digests and canonical versions
    def self.generate_expected_tags(repository_url)
      registry_client = RegistryClient.new
      tag_processor = TagProcessor.new

      all_tags = registry_client.list_tags(repository_url)
      semantic_tags = tag_processor.filter_semantic_tags(all_tags)
      tag_processor.compute_virtual_tags(semantic_tags)
    end

    # Generate actual mutable tags with canonical version mapping
    # @param repository_url [String] Full repository URL
    # @return [Hash] Actual tags with digests and canonical versions
    def self.generate_actual_tags(repository_url)
      registry_client = RegistryClient.new
      tag_processor = TagProcessor.new

      all_tags = registry_client.list_tags(repository_url)
      mutable_tags = tag_processor.filter_mutable_tags(all_tags)
      semantic_tags = tag_processor.filter_semantic_tags(all_tags)

      canonical_versions = CanonicalVersionMapper.map_to_canonical_versions(mutable_tags, semantic_tags)

      {
        "digests" => mutable_tags,
        "canonical_versions" => canonical_versions
      }
    end
  end
end
