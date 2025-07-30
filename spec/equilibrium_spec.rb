require "spec_helper"
require "json"

RSpec.describe "Equilibrium validation" do
  # Find all fixture directories
  fixture_dirs = Dir.glob("fixtures/*").select { |f| File.directory?(f) }

  if fixture_dirs.empty?
    puts "No fixture directories found. Run ./src/main.sh <registry> to generate fixtures first."
    exit 1
  end

  fixture_dirs.each do |fixture_dir|
    registry_name = File.basename(fixture_dir)

    # Try to read original registry name from fixture metadata
    metadata_path = "#{fixture_dir}/registry.txt"
    original_registry = if File.exist?(metadata_path)
      File.read(metadata_path).strip
    else
      registry_name
    end

    describe "Registry: #{original_registry}" do
      let(:actual_mutable_tags_path) { "#{fixture_dir}/actual_mutable_tags.json" }
      let(:expected_mutable_tags_path) { "#{fixture_dir}/expected_mutable_tags.json" }

      before do
        unless File.exist?(actual_mutable_tags_path) && File.exist?(expected_mutable_tags_path)
          skip "Missing fixture files for #{registry_name}. Expected:\n  #{actual_mutable_tags_path}\n  #{expected_mutable_tags_path}"
        end
      end

      let(:actual_data) { JSON.parse(File.read(actual_mutable_tags_path)) }
      let(:expected_data) { JSON.parse(File.read(expected_mutable_tags_path)) }

      it "should have identical keys" do
        expect(actual_data.keys.sort).to eq(expected_data.keys.sort)
      end

      it "should have identical key-value pairs" do
        expect(actual_data).to eq(expected_data)
      end

      it "should have matching values for each key" do
        actual_data.each do |key, value|
          expect(expected_data[key]).to eq(value),
            "Key '#{key}' has different values: actual_mutable_tags.json='#{value}' vs expected_mutable_tags.json='#{expected_data[key]}'"
        end
      end

      it "should contain the same number of entries" do
        expect(actual_data.size).to eq(expected_data.size)
      end

      it "should have all values as valid SHA256 digests" do
        all_values = (actual_data.values + expected_data.values).uniq

        all_values.each do |digest|
          expect(digest).to match(/^sha256:[a-f0-9]{64}$/),
            "Invalid digest format: #{digest}"
        end
      end

      it "should contain expected mutable tag keys" do
        expected_keys = ["latest"]

        expected_keys.each do |key|
          expect(actual_data).to have_key(key)
          expect(expected_data).to have_key(key)
        end
      end

      it "should have identical JSON structure when sorted" do
        sorted_actual = JSON.pretty_generate(actual_data.sort.to_h)
        sorted_expected = JSON.pretty_generate(expected_data.sort.to_h)

        expect(sorted_actual).to eq(sorted_expected)
      end
    end
  end
end
