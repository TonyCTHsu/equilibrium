# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/equilibrium/registry_client"

RSpec.describe Equilibrium::RegistryClient do
  let(:client) { described_class.new }
  let(:test_repository_url) { "gcr.io/test-project/test-image" }

  describe "#list_tags" do
    context "with successful API response" do
      before do
        stub_registry_api(test_repository_url)
      end

      it "returns tag-to-digest mapping" do
        result = client.list_tags(test_repository_url)

        expect(result).to be_a(Hash)
        expect(result["latest"]).to match(/^sha256:[a-f0-9]{64}$/)
        expect(result["1.2.3"]).to match(/^sha256:[a-f0-9]{64}$/)
      end

      it "includes all tags from API response" do
        result = client.list_tags(test_repository_url)

        # Should include semantic version tags
        expect(result).to have_key("1.2.3")
        expect(result).to have_key("1.2.2")
        expect(result).to have_key("0.9.0")

        # Should include other tags
        expect(result).to have_key("latest")
        expect(result).to have_key("v1.2.3")
        expect(result).to have_key("main")
      end

      it "maps tags to correct digests" do
        result = client.list_tags(test_repository_url)

        # Verify specific tag mappings from the manifest data
        expect(result["1.2.3"]).to eq("sha256:abc123def456789012345678901234567890123456789012345678901234abcd")
        expect(result["1.1.0"]).to eq("sha256:012345678901234567890123456789012345678901234567890123456789abc1")
      end
    end

    context "with registry API errors" do
      it "handles 404 not found" do
        stub_request(:get, "https://gcr.io/v2/test-project/test-image/tags/list")
          .to_return(status: 404, body: "Not Found")

        expect {
          client.list_tags(test_repository_url)
        }.to raise_error(Equilibrium::RegistryClient::Error, /Request failed.*404/)
      end

      it "handles network errors" do
        stub_request(:get, "https://gcr.io/v2/test-project/test-image/tags/list")
          .to_raise(SocketError.new("getaddrinfo failed"))

        expect {
          client.list_tags(test_repository_url)
        }.to raise_error(Equilibrium::RegistryClient::Error, /Request failed.*getaddrinfo failed/)
      end

      it "handles invalid JSON response" do
        stub_request(:get, "https://gcr.io/v2/test-project/test-image/tags/list")
          .to_return(status: 200, body: "invalid json")

        expect {
          client.list_tags(test_repository_url)
        }.to raise_error(Equilibrium::RegistryClient::Error, /Invalid JSON response/)
      end
    end

    context "with invalid repository URL format" do
      it "handles repository URL with insufficient parts" do
        expect {
          client.list_tags("gcr.io/only-one-part")
        }.to raise_error(Equilibrium::RegistryClient::Error, /Invalid GCR registry format/)
      end
    end

    context "with different registry hosts" do
      it "works with different registry domains" do
        other_repo = "registry.example.com/namespace/image"
        stub_registry_api(other_repo)

        result = client.list_tags(other_repo)
        expect(result).to be_a(Hash)
      end

      it "constructs correct API URLs for different hosts" do
        repo = "my-registry.com/my-project/my-image"

        stub_request(:get, "https://my-registry.com/v2/my-project/my-image/tags/list")
          .to_return(status: 200, body: {
            "name" => repo,
            "tags" => ["latest"],
            "manifest" => {
              "sha256:abc123def456789012345678901234567890123456789012345678901234abcd" => {"tag" => ["latest"]}
            }
          }.to_json)

        result = client.list_tags(repo)
        expect(result).to have_key("latest")
      end
    end

    context "with nested image names" do
      it "handles multi-level repository paths" do
        nested_repo = "gcr.io/project/namespace/sub-namespace/image"

        stub_request(:get, "https://gcr.io/v2/project/namespace/sub-namespace/image/tags/list")
          .to_return(status: 200, body: {
            "name" => nested_repo,
            "tags" => ["latest"],
            "manifest" => {
              "sha256:abc123def456789012345678901234567890123456789012345678901234abcd" => {"tag" => ["latest"]}
            }
          }.to_json)

        result = client.list_tags(nested_repo)
        expect(result).to have_key("latest")
      end
    end
  end

  describe "#build_api_url" do
    it "constructs correct GCR API URL" do
      url = client.send(:build_api_url, "gcr.io/test-project/test-image")
      expect(url).to eq("https://gcr.io/v2/test-project/test-image/tags/list")
    end

    it "handles nested image paths" do
      url = client.send(:build_api_url, "gcr.io/project/team/service")
      expect(url).to eq("https://gcr.io/v2/project/team/service/tags/list")
    end

    it "raises error for invalid format" do
      expect {
        client.send(:build_api_url, "invalid-format")
      }.to raise_error(Equilibrium::RegistryClient::Error, /Invalid GCR registry format/)
    end
  end
end
