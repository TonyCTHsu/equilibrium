# frozen_string_literal: true

require "json"

module Equilibrium
  class CatalogBuilder
    class Error < StandardError; end

    def self.build_catalog(data)
      # Extract repository name, digests, and canonical versions from the validated data structure
      repository_name = data["repository_name"]
      digests = data["digests"]
      canonical_versions = data["canonical_versions"]

      images = digests.map do |tag, digest|
        {
          "name" => repository_name,
          "tag" => tag,
          "digest" => digest,
          "canonical_version" => canonical_versions[tag]
        }
      end

      {
        "images" => images
      }
    end

    def self.reverse_catalog(catalog_data)
      images = catalog_data["images"]

      return {"repository_name" => "", "digests" => {}, "canonical_versions" => {}} if images.nil? || images.empty?

      repository_name = images.first["name"]

      digests = {}
      canonical_versions = {}

      images.each do |image|
        tag = image["tag"]
        digests[tag] = image["digest"]
        canonical_versions[tag] = image["canonical_version"]
      end

      {
        "repository_name" => repository_name,
        "digests" => digests,
        "canonical_versions" => canonical_versions
      }
    end
  end
end
