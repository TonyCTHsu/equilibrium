# frozen_string_literal: true

require_relative "tag_sorter"

module Equilibrium
  # Builds standardized tag data output format
  # Handles sorting, formatting, and structure creation for expected/actual commands
  class TagDataBuilder
    # Build standardized output structure
    # @param repository_url [String] Full repository URL
    # @param repository_name [String] Extracted repository name
    # @param digests [Hash] Tag to digest mappings
    # @param canonical_versions [Hash] Tag to canonical version mappings
    # @return [Hash] Standardized output structure
    def build_output(repository_url, repository_name, digests, canonical_versions)
      {
        "repository_url" => repository_url,
        "repository_name" => repository_name,
        "digests" => TagSorter.sort_descending(digests),
        "canonical_versions" => TagSorter.sort_descending(canonical_versions)
      }
    end

    # Extract repository name from repository URL
    # @param repository_url [String] Full repository URL
    # @return [String] Repository name
    def extract_repository_name(repository_url)
      repository_url.split("/").last
    end
  end
end
