#!/usr/bin/env ruby

require "json"

# Mock gcloud script for testing
module MockGcloud
  # Raw gcloud response - includes ALL tag types that gcloud would return
  RAW_GCLOUD_RESPONSE = [
    {"tags" => "1.2.3", "digest" => "sha256:abc123"},
    {"tags" => "1.2.2", "digest" => "sha256:def456"},
    {"tags" => "2.0.0", "digest" => "sha256:ghi789"},
    {"tags" => "2.0.1", "digest" => "sha256:jkl012"},
    {"tags" => "latest", "digest" => "sha256:jkl012"},
    {"tags" => "1", "digest" => "sha256:abc123"},
    {"tags" => "1.2", "digest" => "sha256:abc123"},
    {"tags" => "2", "digest" => "sha256:jkl012"},
    {"tags" => "2.0", "digest" => "sha256:jkl012"},
    {"tags" => "v1.2.3", "digest" => "sha256:abc123"},
    {"tags" => "v2.0.0", "digest" => "sha256:ghi789"},
    {"tags" => "main", "digest" => "sha256:xyz789"},
    {"tags" => "dev", "digest" => "sha256:dev123"},
    {"tags" => "sha256:abc123", "digest" => "sha256:abc123"},
    {"tags" => "sha256:def456", "digest" => "sha256:def456"}
  ].freeze

  def self.create_script(response_data, script_path)
    script_content = <<~SCRIPT
      #!/bin/bash
      # Mock gcloud for testing - returns raw data like real gcloud
      echo '#{JSON.generate(response_data)}'
    SCRIPT

    File.write(script_path, script_content)
    File.chmod(0o755, script_path)
    script_path
  end

  def self.semantic_tags_script(script_path)
    # Both scripts use the same raw data - jq filtering will differentiate
    create_script(RAW_GCLOUD_RESPONSE, script_path)
  end

  def self.mutable_tags_script(script_path)
    # Both scripts use the same raw data - jq filtering will differentiate
    create_script(RAW_GCLOUD_RESPONSE, script_path)
  end
end
