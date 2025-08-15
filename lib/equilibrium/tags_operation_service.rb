# frozen_string_literal: true

require_relative "repository_tags_service"
require_relative "tag_data_builder"

module Equilibrium
  # High-level service for tag operations
  # Orchestrates repository tag retrieval and data formatting for expected/actual commands
  # Provides a single entry point for complete tag generation workflows
  class TagsOperationService
    # Generate complete expected tags output
    # @param repository_url [String] Full repository URL (already validated)
    # @return [Hash] Complete expected tags output with repository metadata
    def self.generate_expected_output(repository_url)
      tag_data = RepositoryTagsService.generate_expected_tags(repository_url)
      repository_name = TagDataBuilder.extract_repository_name(repository_url)

      TagDataBuilder.build_output(
        repository_url,
        repository_name,
        tag_data["digests"],
        tag_data["canonical_versions"]
      )
    end

    # Generate complete actual tags output
    # @param repository_url [String] Full repository URL (already validated)
    # @return [Hash] Complete actual tags output with repository metadata
    def self.generate_actual_output(repository_url)
      tag_data = RepositoryTagsService.generate_actual_tags(repository_url)
      repository_name = TagDataBuilder.extract_repository_name(repository_url)

      TagDataBuilder.build_output(
        repository_url,
        repository_name,
        tag_data["digests"],
        tag_data["canonical_versions"]
      )
    end
  end
end
