# frozen_string_literal: true

require "json"
require "json_schemer"
require_relative "schemas/catalog"

module Equilibrium
  class CatalogBuilder
    class Error < StandardError; end

    def build_catalog(data)
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

      catalog = {
        "images" => images
      }

      validate_catalog(catalog)
      catalog
    end

    def reverse_catalog(catalog_data)
      validate_catalog(catalog_data)

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

    private

    def validate_catalog(catalog)
      schemer = JSONSchemer.schema(Equilibrium::Schemas::CATALOG)
      errors = schemer.validate(catalog).to_a

      unless errors.empty?
        raise Error, "Catalog validation failed: #{errors.map(&:to_s).join(", ")}"
      end
    end
  end
end
