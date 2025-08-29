# frozen_string_literal: true

require "spec_helper"
require "rantly/rspec_extensions"

RSpec.describe Equilibrium::TagProcessor do
  describe "property-based tests for version parsing" do
    it "semantic_version? regex correctly validates semantic versions" do
      property_of {
        # Generate valid semantic versions
        major = range(0, 100)
        minor = range(0, 100)
        patch = range(0, 100)
        "#{major}.#{minor}.#{patch}"
      }.check do |version|
        processor = Equilibrium::TagProcessor.new
        expect(processor.send(:semantic_version?, version)).to be true
      end
    end

    it "semantic_version? rejects invalid formats" do
      property_of {
        choose(
          "v#{range(0, 10)}.#{range(0, 10)}.#{range(0, 10)}", # v-prefix
          "#{range(0, 10)}.#{range(0, 10)}.#{range(0, 10)}-alpha", # suffix
          "#{range(0, 10)}.#{range(0, 10)}", # missing patch
          range(0, 10).to_s, # major only
          "#{range(1, 10)}.#{range(0, 10)}.0#{range(0, 9)}", # leading zero in patch
          "0#{range(1, 9)}.#{range(0, 10)}.#{range(0, 10)}", # leading zero in major
          "",
          "latest",
          "main",
          "develop"
        )
      }.check do |invalid_version|
        processor = Equilibrium::TagProcessor.new
        expect(processor.send(:semantic_version?, invalid_version)).to be false
      end
    end

    it "mutable_tag? correctly validates mutable tags" do
      property_of {
        choose(
          "latest",
          range(0, 100).to_s, # major version
          "#{range(0, 50)}.#{range(0, 100)}" # minor version
        )
      }.check do |tag|
        processor = Equilibrium::TagProcessor.new
        expect(processor.send(:mutable_tag?, tag)).to be true
      end
    end

    it "mutable_tag? rejects invalid mutable formats" do
      property_of {
        choose(
          "v#{range(0, 10)}", # v-prefix
          "#{range(0, 10)}.#{range(0, 10)}.#{range(0, 10)}", # semantic version
          "0#{range(1, 9)}", # leading zero
          "#{range(0, 10)}.0#{range(1, 9)}", # leading zero in minor
          "main",
          "develop",
          "feature-branch",
          ""
        )
      }.check do |invalid_tag|
        processor = Equilibrium::TagProcessor.new
        expect(processor.send(:mutable_tag?, invalid_tag)).to be false
      end
    end

    it "semantic and mutable tags are mutually exclusive" do
      property_of {
        # Generate any tag string
        choose(
          "#{range(0, 10)}.#{range(0, 10)}.#{range(0, 10)}", # semantic
          "latest", # mutable
          range(0, 20).to_s, # mutable major
          "#{range(0, 10)}.#{range(0, 10)}", # mutable minor
          "v#{range(0, 10)}.#{range(0, 10)}.#{range(0, 10)}", # invalid
          "random-#{range(0, 100)}" # invalid
        )
      }.check do |tag|
        processor = Equilibrium::TagProcessor.new
        semantic = processor.send(:semantic_version?, tag)
        mutable = processor.send(:mutable_tag?, tag)
        expect(semantic && mutable).to be false
      end
    end
  end

  describe "property-based tests for filtering" do
    it "filter_semantic_tags only returns semantic versions" do
      property_of {
        tagged_digests = {}

        # Add semantic versions
        range(1, 5).times do
          major = range(0, 10)
          minor = range(0, 10)
          patch = range(0, 10)
          tag = "#{major}.#{minor}.#{patch}"
          tagged_digests[tag] = "sha256:#{range(100000, 999999)}"
        end

        # Add mutable tags
        range(1, 3).times do
          major = range(0, 10)
          tagged_digests[major.to_s] = "sha256:#{range(100000, 999999)}"
        end

        # Add invalid tags
        range(0, 2).times do
          invalid_tag = choose(
            "v#{range(0, 5)}.#{range(0, 5)}.#{range(0, 5)}",
            "branch-#{range(0, 100)}",
            "#{range(0, 5)}.#{range(0, 5)}.#{range(0, 5)}-alpha"
          )
          tagged_digests[invalid_tag] = "sha256:#{range(100000, 999999)}"
        end

        tagged_digests
      }.check do |tagged_digests|
        processor = Equilibrium::TagProcessor.new
        filtered = processor.filter_semantic_tags(tagged_digests)

        filtered.keys.each do |tag|
          expect(processor.send(:semantic_version?, tag)).to be true
        end
      end
    end

    it "filter_mutable_tags only returns mutable tags" do
      property_of {
        tagged_digests = {}

        # Add semantic versions
        range(1, 3).times do
          major = range(0, 10)
          minor = range(0, 10)
          patch = range(0, 10)
          tag = "#{major}.#{minor}.#{patch}"
          tagged_digests[tag] = "sha256:#{range(100000, 999999)}"
        end

        # Add mutable tags
        range(1, 5).times do
          major = range(0, 10)
          tagged_digests[major.to_s] = "sha256:#{range(100000, 999999)}"
        end

        range(1, 3).times do
          major = range(0, 5)
          minor = range(0, 10)
          tagged_digests["#{major}.#{minor}"] = "sha256:#{range(100000, 999999)}"
        end

        # Maybe add latest
        if boolean
          tagged_digests["latest"] = "sha256:#{range(100000, 999999)}"
        end

        tagged_digests
      }.check do |tagged_digests|
        processor = Equilibrium::TagProcessor.new
        filtered = processor.filter_mutable_tags(tagged_digests)

        filtered.keys.each do |tag|
          expect(processor.send(:mutable_tag?, tag)).to be true
        end
      end
    end

    it "filtered tags preserve original digests" do
      property_of {
        tagged_digests = {}

        # Add some semantic versions
        range(1, 3).times do
          major = range(0, 5)
          minor = range(0, 5)
          patch = range(0, 5)
          tag = "#{major}.#{minor}.#{patch}"
          tagged_digests[tag] = "sha256:#{range(100000, 999999)}"
        end

        # Add some mutable tags
        range(1, 3).times do
          major = range(0, 5)
          tagged_digests[major.to_s] = "sha256:#{range(100000, 999999)}"
        end

        tagged_digests
      }.check do |tagged_digests|
        processor = Equilibrium::TagProcessor.new
        semantic_filtered = processor.filter_semantic_tags(tagged_digests)
        mutable_filtered = processor.filter_mutable_tags(tagged_digests)

        # All filtered entries should preserve original digest values
        semantic_filtered.each do |tag, digest|
          expect(tagged_digests[tag]).to eq(digest)
        end

        mutable_filtered.each do |tag, digest|
          expect(tagged_digests[tag]).to eq(digest)
        end
      end
    end
  end
end
