# frozen_string_literal: true

require "thor"

module Equilibrium
  class SummaryFormatter
    include Thor::Shell

    def initialize
      # Initialize Thor::Shell methods with empty arguments
      self.shell = Thor::Shell::Basic.new
    end

    def print_analysis_summary(analysis)
      say "Repository URL: #{analysis[:repository_url]}"
      say ""

      # Status overview table
      status_color = (analysis[:status] == "perfect") ? :green : :yellow
      status_symbol = (analysis[:status] == "perfect") ? "✓" : "⚠"

      overview_data = [
        ["Metric", "Count"],
        ["Expected tags", analysis[:expected_count].to_s],
        ["Actual tags", analysis[:actual_count].to_s],
        ["Missing tags", analysis[:missing_tags].size.to_s],
        ["Mismatched tags", analysis[:mismatched_tags].size.to_s],
        ["Unexpected tags", analysis[:unexpected_tags].size.to_s]
      ]

      say "Analysis Overview:"
      print_table(overview_data, borders: true)
      say ""

      say "#{status_symbol} Status: #{analysis[:status].upcase.tr("_", " ")}", status_color
      say ""

      # Show specific issue sections
      has_issues = false

      # Missing tags section
      if analysis[:missing_tags].any?
        has_issues = true
        say "Missing Tags (should be created):"
        missing_table = [["Tag", "Should Point To"]]
        analysis[:missing_tags].each do |tag, digest|
          short_digest = digest ? digest.split(":").last[0..11] : "unknown"
          missing_table << [tag, short_digest]
        end
        print_table(missing_table, borders: true)
        say ""
      end

      # Mismatched tags section
      if analysis[:mismatched_tags].any?
        has_issues = true
        say "Mismatched Tags (pointing to wrong version):"
        mismatched_table = [["Tag", "Expected", "Actual"]]
        analysis[:mismatched_tags].each do |tag, details|
          if details.is_a?(Hash)
            expected = details[:expected] ? details[:expected].split(":").last[0..11] : "unknown"
            actual = details[:actual] ? details[:actual].split(":").last[0..11] : "unknown"
          else
            expected = details ? details.split(":").last[0..11] : "unknown"
            actual = "unknown"
          end
          mismatched_table << [tag, expected, actual]
        end
        print_table(mismatched_table, borders: true)
        say ""
      end

      # Unexpected tags section
      if analysis[:unexpected_tags].any?
        has_issues = true
        say "Unexpected Tags (should be removed):"
        unexpected_table = [["Tag", "Currently Points To"]]
        analysis[:unexpected_tags].each do |tag, digest|
          short_digest = digest ? digest.split(":").last[0..11] : "unknown"
          unexpected_table << [tag, short_digest]
        end
        print_table(unexpected_table, borders: true)
        say ""
      end

      if has_issues
        say "To see detailed remediation commands, use:"
        say "  equilibrium analyze --expected expected.json --actual actual.json --format=json | jq '.remediation_plan'"
      else
        say "✓ Registry is in perfect equilibrium!", :green
      end
    end

    def print_tags_summary(output, type)
      say "Repository: #{output["repository_name"]}"
      say "URL: #{output["repository_url"]}"
      say ""

      mutable_tags = output["digests"]
      canonical_versions = output["canonical_versions"]

      say "#{type.capitalize} mutable tags (#{mutable_tags.size}):"
      say ""

      # Create table data: [["Tag", "Version", "Digest"]]
      table_data = [["Tag", "Version", "Digest"]]
      mutable_tags.keys.each do |tag|
        canonical_version = canonical_versions[tag]
        digest = mutable_tags[tag]
        table_data << [tag, canonical_version, digest]
      end

      print_table(table_data, borders: true)
    end
  end
end
