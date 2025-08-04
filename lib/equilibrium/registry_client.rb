# frozen_string_literal: true

require "uri"
require "json"
require "net/http"
require_relative "schema_validator"
require_relative "schemas/registry_api"

module Equilibrium
  class RegistryClient
    class Error < StandardError; end

    def list_tags(registry)
      url = build_api_url(registry)
      data = fetch_tags_data(url)
      parse_response(data)
    end

    private

    def build_api_url(registry)
      parts = registry.split("/")
      raise Error, "Invalid GCR registry format: #{registry}" if parts.length < 3

      host, project, *image = parts
      # Uses Docker Registry v2 API endpoint for listing tags
      # https://docs.docker.com/registry/spec/api/#listing-image-tags
      "https://#{host}/v2/#{project}/#{image.join("/")}/tags/list"
    end

    def fetch_tags_data(url)
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      response = http.request(Net::HTTP::Get.new(uri))

      raise Error, "API request failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      validate_registry_response(data)
      data
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON response: #{e.message}"
    rescue => e
      raise Error, "Request failed: #{e.message}"
    end

    def validate_registry_response(data)
      SchemaValidator.validate!(data, Equilibrium::Schemas::REGISTRY_API_RESPONSE, error_prefix: "Registry API response validation failed")
    rescue SchemaValidator::ValidationError => e
      raise Error, e.message
    end

    def parse_response(data)
      # Data is already validated by schema, safe to process
      tags = data["tags"]
      tag_to_digest = build_digest_mapping(data["manifest"] || {})

      tags.each_with_object({}) do |tag, result|
        result[tag] = tag_to_digest[tag]
      end
    end

    def build_digest_mapping(manifests)
      manifests.each_with_object({}) do |(digest, manifest_info), mapping|
        tags = manifest_info["tag"]
        tags.each { |tag| mapping[tag] = digest }
      end
    end
  end
end
