# frozen_string_literal: true

require "spec_helper"
require "rantly/rspec_extensions"

RSpec.describe Equilibrium::TagSorter do
  describe "property-based tests" do
    it "always places latest tag first when present" do
      property_of {
        tags = {}
        tags["latest"] = "sha256:latest"

        # Add some other tags
        range(1, 5).times do
          major = range(0, 20)
          tags[major.to_s] = "sha256:#{major}"
        end

        tags
      }.check do |tags|
        sorted = Equilibrium::TagSorter.sort_descending(tags)
        expect(sorted.keys.first).to eq("latest")
      end
    end

    it "maintains ordering invariants for major versions" do
      property_of {
        tags = {}
        range(2, 8).times do
          major = range(0, 50)
          tags[major.to_s] = "sha256:#{major}"
        end
        tags
      }.check do |tags|
        sorted = Equilibrium::TagSorter.sort_descending(tags)
        major_keys = sorted.keys.select { |k| k.match?(/^[0-9]+$/) }
        major_versions = major_keys.map(&:to_i)
        expect(major_versions).to eq(major_versions.sort.reverse)
      end
    end

    it "maintains ordering invariants for minor versions" do
      property_of {
        tags = {}
        range(2, 8).times do
          major = range(0, 10)
          minor = range(0, 20)
          tags["#{major}.#{minor}"] = "sha256:#{major}.#{minor}"
        end
        tags
      }.check do |tags|
        sorted = Equilibrium::TagSorter.sort_descending(tags)
        minor_keys = sorted.keys.select { |k| k.match?(/^[0-9]+\.[0-9]+$/) }

        # Group by major version and verify descending order within each major
        grouped = minor_keys.group_by { |k| k.split(".")[0] }
        grouped.each do |major, minors|
          minor_versions = minors.map { |m| m.split(".")[1].to_i }
          expect(minor_versions).to eq(minor_versions.sort.reverse)
        end
      end
    end

    it "is idempotent" do
      property_of {
        tags = {}

        # Add latest maybe
        tags["latest"] = "sha256:latest" if boolean

        # Add some major versions
        range(0, 5).times do
          major = range(0, 20)
          tags[major.to_s] = "sha256:#{major}"
        end

        # Add some minor versions
        range(0, 5).times do
          major = range(0, 10)
          minor = range(0, 20)
          tags["#{major}.#{minor}"] = "sha256:#{major}.#{minor}"
        end

        tags
      }.check do |tags|
        sorted_once = Equilibrium::TagSorter.sort_descending(tags)
        sorted_twice = Equilibrium::TagSorter.sort_descending(sorted_once)
        expect(sorted_once).to eq(sorted_twice)
      end
    end

    it "preserves all tag-digest mappings" do
      property_of {
        tags = {}

        range(1, 8).times do
          tag_type = choose(:latest, :major, :minor)
          case tag_type
          when :latest
            tags["latest"] = "sha256:latest"
          when :major
            major = range(0, 20)
            tags[major.to_s] = "sha256:#{major}"
          when :minor
            major = range(0, 10)
            minor = range(0, 20)
            tags["#{major}.#{minor}"] = "sha256:#{major}.#{minor}"
          end
        end

        tags
      }.check do |tags|
        sorted = Equilibrium::TagSorter.sort_descending(tags)
        expect(sorted.keys.sort).to eq(tags.keys.sort)
        tags.each do |tag, digest|
          expect(sorted[tag]).to eq(digest)
        end
      end
    end

    it "handles edge cases gracefully" do
      property_of {
        choose(
          {},
          {"latest" => "sha256:abc"},
          {"0" => "sha256:def"},
          {"999" => "sha256:ghi"},
          {"0.0" => "sha256:jkl"}
        )
      }.check do |tags|
        expect { Equilibrium::TagSorter.sort_descending(tags) }.not_to raise_error
      end
    end
  end
end
