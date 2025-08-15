# frozen_string_literal: true

require_relative "tag_sorter"

module Equilibrium
  class TagDataBuilder
    def self.build_output(repository_url, repository_name, digests, canonical_versions)
      {
        "repository_url" => repository_url,
        "repository_name" => repository_name,
        "digests" => TagSorter.sort_descending(digests),
        "canonical_versions" => TagSorter.sort_descending(canonical_versions)
      }
    end
  end
end
