# frozen_string_literal: true

require "uri"
require "json"
require "net/http"
require_relative "schema_validator"
require_relative "schemas/registry_api"

module Equilibrium
  # Registry client for Docker Registry v2 API
  #
  # Supports fetching container image tags from various registry providers.
  # Currently designed for registries that allow anonymous access (like public GCR).
  #
  # Google Container Registry (GCR) Pros and Cons:
  # ✅ Pros: Simple anonymous access for public repos, provides digest info via non-standard 'manifest' field
  # ❌ Cons: Being deprecated in favor of Artifact Registry, non-standard API extensions may not be portable
  #
  # Other registries require complex authentication and don't provide manifest field,
  # making it difficult to get digest information without separate API calls per tag:
  # - GitHub Container Registry (GHCR): Requires Bearer token auth
  # - Docker Hub: Requires token exchange auth flow
  # - AWS ECR Public: Requires AWS credentials even for public repos
  #
  # Note: The 'manifest' field in responses is a non-standard extension only provided
  # by some registries (like GCR). Most registries follow the Docker Registry v2 spec
  # which only returns 'name' and 'tags' fields. To get digest information, separate
  # calls to /v2/<name>/manifests/<tag> are required per the official specification.
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

      # The 'manifest' field is a non-standard extension provided by some registries (like GCR)
      # Most registries (GHCR, Docker Hub, ECR) only return 'name' and 'tags' per Docker Registry v2 spec
      # When manifest data is missing, digest information is not available from the tags endpoint
      tag_to_digest = build_digest_mapping(data["manifest"] || {})

      tags.each_with_object({}) do |tag, result|
        # Map tags to their digests. For registries without manifest data, digest will be nil
        # This is expected behavior - digest info requires separate manifest API calls per tag
        result[tag] = tag_to_digest[tag]
      end
    end

    def build_digest_mapping(manifests)
      # Build mapping from tag names to their SHA256 digests
      # Only works when registry provides non-standard 'manifest' field in tags response
      manifests.each_with_object({}) do |(digest, manifest_info), mapping|
        tags = manifest_info["tag"]
        tags.each { |tag| mapping[tag] = digest }
      end
    end
  end
end
