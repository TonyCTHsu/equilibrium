# frozen_string_literal: true

require "json"

module Equilibrium
  class Analyzer
    # Analyzes validated expected/actual data in schema format
    def self.analyze(expected_data, actual_data)
      # Extract digests from validated schema format
      expected_tags = expected_data["digests"]
      actual_tags = actual_data["digests"]

      # Extract and validate repository URLs match
      expected_url = expected_data["repository_url"]
      actual_url = actual_data["repository_url"]

      if expected_url != actual_url
        raise ArgumentError, "Repository URLs do not match: expected '#{expected_url}', actual '#{actual_url}'"
      end

      final_repository_url = expected_url

      analysis = {
        repository_url: final_repository_url,
        expected_count: expected_tags.size,
        actual_count: actual_tags.size,
        missing_tags: find_missing_tags(expected_tags, actual_tags),
        unexpected_tags: find_unexpected_tags(expected_tags, actual_tags),
        mismatched_tags: find_mismatched_tags(expected_tags, actual_tags),
        status: determine_status(expected_tags, actual_tags)
      }

      # Add remediation plan for JSON format
      analysis[:remediation_plan] = generate_remediation_plan(analysis, final_repository_url)
      analysis
    end

    private_class_method def self.generate_remediation_plan(analysis, repository_url)
      plan = []

      analysis[:missing_tags].each do |tag, digest|
        plan << {
          action: "create_tag",
          tag: tag,
          digest: digest,
          command: "gcloud container images add-tag #{repository_url}@#{digest} #{repository_url}:#{tag}"
        }
      end

      analysis[:mismatched_tags].each do |tag, data|
        plan << {
          action: "update_tag",
          tag: tag,
          old_digest: data[:actual],
          new_digest: data[:expected],
          command: "gcloud container images add-tag #{repository_url}@#{data[:expected]} #{repository_url}:#{tag}"
        }
      end

      analysis[:unexpected_tags].each do |tag, digest|
        plan << {
          action: "remove_tag",
          tag: tag,
          digest: digest,
          command: "gcloud container images untag #{repository_url}:#{tag}"
        }
      end

      plan
    end

    private_class_method def self.find_missing_tags(expected, actual)
      expected.reject { |tag, digest| actual.key?(tag) }
    end

    def self.find_unexpected_tags(expected, actual)
      actual.reject { |tag, _| expected.key?(tag) }
    end

    def self.find_mismatched_tags(expected, actual)
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

    def self.determine_status(expected, actual)
      return "perfect" if expected == actual
      return "mismatched" if find_mismatched_tags(expected, actual).any?
      return "missing_tags" if find_missing_tags(expected, actual).any?
      return "extra_tags" if find_unexpected_tags(expected, actual).any?

      "perfect"  # Default to perfect if no differences found
    end
  end
end
