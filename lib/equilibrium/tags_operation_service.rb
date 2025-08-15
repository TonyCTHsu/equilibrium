# frozen_string_literal: true

require_relative "repository_tags_service"
require_relative "tag_data_builder"

module Equilibrium
  class TagsOperationService
    def self.generate_expected_output(repository_url)
      tag_data = RepositoryTagsService.generate_expected_tags(repository_url)
      repository_name = repository_url.split("/").last

      TagDataBuilder.build_output(
        repository_url,
        repository_name,
        tag_data["digests"],
        tag_data["canonical_versions"]
      )
    end

    def self.generate_actual_output(repository_url)
      tag_data = RepositoryTagsService.generate_actual_tags(repository_url)
      repository_name = repository_url.split("/").last

      TagDataBuilder.build_output(
        repository_url,
        repository_name,
        tag_data["digests"],
        tag_data["canonical_versions"]
      )
    end
  end
end
