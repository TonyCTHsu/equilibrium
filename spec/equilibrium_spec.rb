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

    describe "Registry: #{registry_name}" do
      let(:mutable_tag_mapping_path) { "#{fixture_dir}/mutable_tag_mapping.json" }
      let(:computed_mutable_tags_path) { "#{fixture_dir}/computed_mutable_tags.json" }

      before do
        unless File.exist?(mutable_tag_mapping_path) && File.exist?(computed_mutable_tags_path)
          skip "Missing fixture files for #{registry_name}. Expected:\n  #{mutable_tag_mapping_path}\n  #{computed_mutable_tags_path}"
        end
      end

      let(:mutable_data) { JSON.parse(File.read(mutable_tag_mapping_path)) }
      let(:computed_data) { JSON.parse(File.read(computed_mutable_tags_path)) }

      it "should have identical keys" do
        expect(mutable_data.keys.sort).to eq(computed_data.keys.sort)
      end

      it "should have identical key-value pairs" do
        expect(mutable_data).to eq(computed_data)
      end

      it "should have matching values for each key" do
        mutable_data.each do |key, value|
          expect(computed_data[key]).to eq(value),
            "Key '#{key}' has different values: mutable_tag_mapping.json='#{value}' vs computed_mutable_tags.json='#{computed_data[key]}'"
        end
      end

      it "should contain the same number of entries" do
        expect(mutable_data.size).to eq(computed_data.size)
      end

      it "should have all values as valid SHA256 digests" do
        all_values = (mutable_data.values + computed_data.values).uniq

        all_values.each do |digest|
          expect(digest).to match(/^sha256:[a-f0-9]{64}$/),
            "Invalid digest format: #{digest}"
        end
      end

      it "should contain expected mutable tag keys" do
        expected_keys = ["latest"]

        expected_keys.each do |key|
          expect(mutable_data).to have_key(key)
          expect(computed_data).to have_key(key)
        end
      end

      it "should have identical JSON structure when sorted" do
        sorted_mutable = JSON.pretty_generate(mutable_data.sort.to_h)
        sorted_computed = JSON.pretty_generate(computed_data.sort.to_h)

        expect(sorted_mutable).to eq(sorted_computed)
      end
    end
  end
end
