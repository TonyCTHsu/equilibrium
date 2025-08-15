# frozen_string_literal: true

require "json"

module Equilibrium
  class Analyzer
    def self.analyze(expected_data, actual_data)
      new.analyze(expected_data, actual_data)
    end

    def analyze(expected_data, actual_data)
      # Extract digests from validated schema format
      expected_tags = expected_data["digests"]
      actual_tags = actual_data["digests"]

      # Extract and validate repository names match
      expected_name = expected_data["repository_name"]
      actual_name = actual_data["repository_name"]
      expected_url = expected_data["repository_url"]
      actual_url = actual_data["repository_url"]

      if expected_name != actual_name
        raise ArgumentError, "Repository names do not match: expected '#{expected_name}', actual '#{actual_name}'"
      end

      final_repository_name = expected_name
      final_repository_url = expected_url || actual_url

      analysis = {
        repository_url: final_repository_url,
        repository_name: final_repository_name,
        expected_count: expected_tags.size,
        actual_count: actual_tags.size,
        missing_tags: find_missing_tags(expected_tags, actual_tags),
        unexpected_tags: find_unexpected_tags(expected_tags, actual_tags),
        mismatched_tags: find_mismatched_tags(expected_tags, actual_tags),
        status: determine_status(expected_tags, actual_tags)
      }.compact

      # Add remediation plan for JSON format
      analysis[:remediation_plan] = generate_remediation_plan(analysis, final_repository_url, final_repository_name)
      analysis
    end

    private

    def generate_remediation_plan(analysis, repository_url, repository_name)
      plan = []

      analysis[:missing_tags].each do |tag, digest|
        plan << {
          action: "create_tag",
          tag: tag,
          digest: digest,
          command: "gcloud container images add-tag #{repository_url}@#{digest} #{repository_url}:#{tag}"
        }.compact
      end

      analysis[:mismatched_tags].each do |tag, data|
        plan << {
          action: "update_tag",
          tag: tag,
          old_digest: data[:actual],
          new_digest: data[:expected],
          command: "gcloud container images add-tag #{repository_url}@#{data[:expected]} #{repository_url}:#{tag}"
        }.compact
      end

      analysis[:unexpected_tags].each do |tag, digest|
        plan << {
          action: "remove_tag",
          tag: tag,
          digest: digest,
          command: "gcloud container images untag #{repository_url}:#{tag}"
        }.compact
      end

      plan
    end

    def find_missing_tags(expected, actual)
      expected.reject { |tag, digest| actual.key?(tag) }
    end

    def find_unexpected_tags(expected, actual)
      actual.reject { |tag, _| expected.key?(tag) }
    end

    def find_mismatched_tags(expected, actual)
      mismatched = {}
      expected.each do |tag, expected_digest|
        if actual.key?(tag) && actual[tag] != expected_digest
          mismatched[tag] = {
            expected: expected_digest,
            actual: actual[tag]
          }
        end
      end
      mismatched
    end

    def determine_status(expected, actual)
      return "perfect" if expected == actual
      return "mismatched" if find_mismatched_tags(expected, actual).any?
      return "missing_tags" if find_missing_tags(expected, actual).any?
      return "extra_tags" if find_unexpected_tags(expected, actual).any?

      "perfect"  # Default to perfect if no differences found
    end
  end
end
