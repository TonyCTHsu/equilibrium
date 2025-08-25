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

      {
        repository_url: final_repository_url,
        repository_name: final_repository_name,
        expected_count: expected_tags.size,
        actual_count: actual_tags.size,
        missing_tags: find_missing_tags(expected_tags, actual_tags),
        unexpected_tags: find_unexpected_tags(expected_tags, actual_tags),
        mismatched_tags: find_mismatched_tags(expected_tags, actual_tags),
        status: determine_status(expected_tags, actual_tags)
      }.compact
    end

    private

    def find_missing_tags(expected, actual)
      missing = {}
      expected.each do |tag, digest|
        unless actual.key?(tag)
          missing[tag] = {
            expected: digest,
            actual: ""
          }
        end
      end
      missing
    end

    def find_unexpected_tags(expected, actual)
      unexpected = {}
      actual.each do |tag, digest|
        unless expected.key?(tag)
          unexpected[tag] = {
            expected: "",
            actual: digest
          }
        end
      end
      unexpected
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
