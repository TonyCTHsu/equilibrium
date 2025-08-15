# frozen_string_literal: true

require_relative "../spec_helper"
require "digest"
require_relative "../../lib/equilibrium/analyzer"

RSpec.describe Equilibrium::Analyzer do
  let(:repository_url) { "gcr.io/test-project/test-image" }

  # Generate consistent SHA256 digests for test data
  let(:perfect_digest) { "sha256:#{Digest::SHA256.hexdigest("perfect-123")}" }
  let(:missing_digest) { "sha256:#{Digest::SHA256.hexdigest("missing-123")}" }
  let(:extra_digest) { "sha256:#{Digest::SHA256.hexdigest("extra-123")}" }
  let(:different_digest) { "sha256:#{Digest::SHA256.hexdigest("different-123")}" }
  let(:wrong_digest) { "sha256:#{Digest::SHA256.hexdigest("wrong-123")}" }
  let(:old_digest) { "sha256:#{Digest::SHA256.hexdigest("old-123")}" }
  let(:new_digest) { "sha256:#{Digest::SHA256.hexdigest("new-123")}" }

  let(:perfect_expected_data) do
    {
      "repository_url" => repository_url,
      "repository_name" => "test-image",
      "digests" => {
        "latest" => perfect_digest,
        "1" => perfect_digest,
        "1.2" => perfect_digest
      },
      "canonical_versions" => {
        "latest" => "1.2.3",
        "1" => "1.2.3",
        "1.2" => "1.2.3"
      }
    }
  end

  let(:perfect_actual_data) do
    {
      "repository_url" => repository_url,
      "repository_name" => "test-image",
      "digests" => {
        "latest" => perfect_digest,
        "1" => perfect_digest,
        "1.2" => perfect_digest
      },
      "canonical_versions" => {
        "latest" => "1.2.3",
        "1" => "1.2.3",
        "1.2" => "1.2.3"
      }
    }
  end

  describe "#analyze" do
    it "analyzes perfect equilibrium" do
      result = described_class.analyze(perfect_expected_data, perfect_actual_data)

      expect(result[:status]).to eq("perfect")
      expect(result[:repository_url]).to eq(repository_url)
      expect(result[:expected_count]).to eq(3)
      expect(result[:actual_count]).to eq(3)
      expect(result[:missing_tags]).to be_empty
      expect(result[:unexpected_tags]).to be_empty
      expect(result[:mismatched_tags]).to be_empty
      expect(result[:remediation_plan]).to be_empty
    end

    it "detects missing tags" do
      actual_missing = {
        "repository_url" => repository_url,
        "repository_name" => "test-image",
        "digests" => {
          "latest" => perfect_digest
          # Missing "1" and "1.2"
        },
        "canonical_versions" => {
          "latest" => "1.2.3"
        }
      }

      result = described_class.analyze(perfect_expected_data, actual_missing)

      expect(result[:status]).to eq("missing_tags")
      expect(result[:missing_tags]).to have_key("1")
      expect(result[:missing_tags]).to have_key("1.2")
      expect(result[:missing_tags]["1"]).to eq(perfect_digest)
      expect(result[:remediation_plan].size).to eq(2)
    end

    it "detects unexpected tags" do
      actual_extra = {
        "repository_url" => repository_url,
        "repository_name" => "test-image",
        "digests" => {
          "latest" => perfect_digest,
          "1" => perfect_digest,
          "1.2" => perfect_digest,
          "dev" => extra_digest  # Unexpected tag
        },
        "canonical_versions" => {
          "latest" => "1.2.3",
          "1" => "1.2.3",
          "1.2" => "1.2.3",
          "dev" => "0.1.0"
        }
      }

      result = described_class.analyze(perfect_expected_data, actual_extra)

      expect(result[:status]).to eq("extra_tags")
      expect(result[:unexpected_tags]).to have_key("dev")
      expect(result[:unexpected_tags]["dev"]).to eq(extra_digest)
      expect(result[:remediation_plan].size).to eq(1)
      expect(result[:remediation_plan].first[:action]).to eq("remove_tag")
    end

    it "detects mismatched tags" do
      actual_mismatched = {
        "repository_url" => repository_url,
        "repository_name" => "test-image",
        "digests" => {
          "latest" => perfect_digest,
          "1" => different_digest,  # Wrong digest
          "1.2" => perfect_digest
        },
        "canonical_versions" => {
          "latest" => "1.2.3",
          "1" => "1.2.3",
          "1.2" => "1.2.3"
        }
      }

      result = described_class.analyze(perfect_expected_data, actual_mismatched)

      expect(result[:status]).to eq("mismatched")
      expect(result[:mismatched_tags]).to have_key("1")
      expect(result[:mismatched_tags]["1"][:expected]).to eq(perfect_digest)
      expect(result[:mismatched_tags]["1"][:actual]).to eq(different_digest)
      expect(result[:remediation_plan].size).to eq(1)
      expect(result[:remediation_plan].first[:action]).to eq("update_tag")
    end

    it "handles complex scenarios with multiple issues" do
      actual_complex = {
        "repository_url" => repository_url,
        "repository_name" => "test-image",
        "digests" => {
          "latest" => perfect_digest,      # Correct
          "1" => wrong_digest,         # Mismatched
          # Missing "1.2"
          "dev" => extra_digest       # Unexpected
        },
        "canonical_versions" => {
          "latest" => "1.2.3",
          "1" => "1.2.3",
          "dev" => "0.1.0"
        }
      }

      result = described_class.analyze(perfect_expected_data, actual_complex)

      expect(result[:status]).to eq("mismatched") # Prioritizes mismatched over missing
      expect(result[:missing_tags]).to have_key("1.2")
      expect(result[:unexpected_tags]).to have_key("dev")
      expect(result[:mismatched_tags]).to have_key("1")
      expect(result[:remediation_plan].size).to eq(3)
    end

    it "validates repository names match between expected and actual data" do
      mismatched_actual_data = perfect_actual_data.dup
      mismatched_actual_data["repository_name"] = "different-repo"

      expect {
        described_class.analyze(perfect_expected_data, mismatched_actual_data)
      }.to raise_error(ArgumentError, /Repository names do not match/)
    end
  end

  describe "#generate_remediation_plan" do
    let(:analysis_missing) do
      {
        missing_tags: {"1" => perfect_digest, "1.2" => missing_digest},
        unexpected_tags: {},
        mismatched_tags: {}
      }
    end

    let(:analysis_mismatched) do
      {
        missing_tags: {},
        unexpected_tags: {},
        mismatched_tags: {
          "latest" => {expected: new_digest, actual: old_digest}
        }
      }
    end

    let(:analysis_extra) do
      {
        missing_tags: {},
        unexpected_tags: {"dev" => extra_digest},
        mismatched_tags: {}
      }
    end

    it "generates create_tag commands for missing tags" do
      analyzer = described_class.new
      plan = analyzer.send(:generate_remediation_plan, analysis_missing, repository_url, "test-image")

      expect(plan.size).to eq(2)

      create_commands = plan.select { |item| item[:action] == "create_tag" }
      expect(create_commands.size).to eq(2)

      tag_1_command = create_commands.find { |cmd| cmd[:tag] == "1" }
      expect(tag_1_command[:digest]).to eq(perfect_digest)
      expect(tag_1_command[:command]).to include("gcloud container images add-tag")
      expect(tag_1_command[:command]).to include("#{repository_url}@#{perfect_digest}")
      expect(tag_1_command[:command]).to include("#{repository_url}:1")
    end

    it "generates update_tag commands for mismatched tags" do
      analyzer = described_class.new
      plan = analyzer.send(:generate_remediation_plan, analysis_mismatched, repository_url, "test-image")

      expect(plan.size).to eq(1)

      update_command = plan.first
      expect(update_command[:action]).to eq("update_tag")
      expect(update_command[:tag]).to eq("latest")
      expect(update_command[:old_digest]).to eq(old_digest)
      expect(update_command[:new_digest]).to eq(new_digest)
      expect(update_command[:command]).to include("gcloud container images add-tag")
    end

    it "generates remove_tag commands for unexpected tags" do
      analyzer = described_class.new
      plan = analyzer.send(:generate_remediation_plan, analysis_extra, repository_url, "test-image")

      expect(plan.size).to eq(1)

      remove_command = plan.first
      expect(remove_command[:action]).to eq("remove_tag")
      expect(remove_command[:tag]).to eq("dev")
      expect(remove_command[:digest]).to eq(extra_digest)
      expect(remove_command[:command]).to include("gcloud container images untag")
      expect(remove_command[:command]).to include("#{repository_url}:dev")
    end

    it "handles unknown repository URL" do
      analyzer = described_class.new
      plan = analyzer.send(:generate_remediation_plan, analysis_missing, "unknown", "test-image")

      expect(plan.size).to eq(2)
      plan.each do |command|
        expect(command[:command]).to include("unknown")
      end
    end

    it "handles missing repository URL" do
      analyzer = described_class.new
      plan = analyzer.send(:generate_remediation_plan, analysis_missing, nil, "test-image")

      expect(plan.size).to eq(2)
      plan.each do |command|
        expect(command).to have_key(:action)
        expect(command).to have_key(:tag)
        expect(command).to have_key(:digest)
        expect(command).not_to have_key(:command)
      end
    end
  end

  describe "#determine_status" do
    it "returns perfect for identical tags" do
      expected = {"latest" => perfect_digest, "1" => missing_digest}
      actual = {"latest" => perfect_digest, "1" => missing_digest}

      analyzer = described_class.new
      status = analyzer.send(:determine_status, expected, actual)
      expect(status).to eq("perfect")
    end

    it "returns missing_tags when actual is missing tags" do
      expected = {"latest" => perfect_digest, "1" => missing_digest}
      actual = {"latest" => perfect_digest}

      analyzer = described_class.new
      status = analyzer.send(:determine_status, expected, actual)
      expect(status).to eq("missing_tags")
    end

    it "returns extra_tags when actual has extra tags" do
      expected = {"latest" => perfect_digest}
      actual = {"latest" => perfect_digest, "dev" => extra_digest}

      analyzer = described_class.new
      status = analyzer.send(:determine_status, expected, actual)
      expect(status).to eq("extra_tags")
    end

    it "returns mismatched when digests don't match" do
      expected = {"latest" => perfect_digest, "1" => missing_digest}
      actual = {"latest" => different_digest, "1" => missing_digest}

      analyzer = described_class.new
      status = analyzer.send(:determine_status, expected, actual)
      expect(status).to eq("mismatched")
    end

    it "prioritizes mismatched over missing or extra" do
      expected = {"latest" => perfect_digest, "1" => missing_digest}
      actual = {"latest" => wrong_digest, "dev" => extra_digest} # missing "1", extra "dev", wrong "latest"

      analyzer = described_class.new
      status = analyzer.send(:determine_status, expected, actual)
      expect(status).to eq("mismatched")
    end
  end
end
