# frozen_string_literal: true

require "json"
require "json_schemer"
require_relative "schemas/catalog"

module Equilibrium
  class CatalogBuilder
    class Error < StandardError; end

    def build_catalog(data)
      # Extract repository name and tags from the validated data structure
      repository_name = data["repository_name"]
      virtual_tags = data["tags"]

      images = virtual_tags.map do |tag, digest|
        {
          "name" => repository_name,
          "tag" => tag,
          "digest" => digest
        }
      end

      catalog = {
        "images" => images
      }

      validate_catalog(catalog)
      catalog
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
