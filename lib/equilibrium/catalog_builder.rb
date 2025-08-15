# frozen_string_literal: true

require "json"

module Equilibrium
  class CatalogBuilder
    class Error < StandardError; end

    def self.build_catalog(data)
      repository_name = data["repository_name"]
      repository_url = data["repository_url"]
      digests = data["digests"]
      canonical_versions = data["canonical_versions"]

      images = digests.map do |tag, digest|
        {
          "tag" => tag,
          "digest" => digest,
          "canonical_version" => canonical_versions[tag]
        }
      end

      {
        "repository_url" => repository_url,
        "repository_name" => repository_name,
        "images" => images
      }
    end

    def self.reverse_catalog(catalog_data)
      images = catalog_data["images"]
      repository_url = catalog_data["repository_url"]
      repository_name = catalog_data["repository_name"]

      if images.nil? || images.empty?
        return {
          "repository_url" => repository_url || "",
          "repository_name" => repository_name || "",
          "digests" => {},
          "canonical_versions" => {}
        }
      end

      digests = {}
      canonical_versions = {}

      images.each do |image|
        tag = image["tag"]
        digests[tag] = image["digest"]
        canonical_versions[tag] = image["canonical_version"]
      end

      {
        "repository_url" => repository_url,
        "repository_name" => repository_name,
        "digests" => digests,
        "canonical_versions" => canonical_versions
      }
    end
  end
end
