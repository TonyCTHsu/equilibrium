# frozen_string_literal: true

module Equilibrium
  class TagSorter
    # Sort tags in descending version order: latest first, then major versions (descending), then minor versions (descending)
    def self.sort_descending(tags_hash)
      new.sort_descending(tags_hash)
    end

    def sort_descending(tags_hash)
      return {} if tags_hash.nil? || tags_hash.empty?

      sorted = {}

      # Add latest first if present
      if tags_hash.key?("latest")
        sorted["latest"] = tags_hash["latest"]
      end

      # Sort other tags by version (descending)
      other_tags = tags_hash.keys.reject { |k| k == "latest" }
      sorted_tags = other_tags.sort_by do |tag|
        if major_version?(tag)
          # Major version: sort by numeric value (descending)
          [-tag.to_i]
        elsif minor_version?(tag)
          # Minor version: sort by version (descending)
          parts = tag.split(".").map(&:to_i)
          [-parts[0], -parts[1]]
        else
          # Fallback for any unexpected formats - sort alphabetically
          [1, tag]
        end
      end

      sorted_tags.each do |tag|
        sorted[tag] = tags_hash[tag]
      end

      sorted
    end

    private

    def major_version?(tag)
      tag.match?(/^[0-9]+$/)
    end

    def minor_version?(tag)
      tag.match?(/^[0-9]+\.[0-9]+$/)
    end
  end
end
