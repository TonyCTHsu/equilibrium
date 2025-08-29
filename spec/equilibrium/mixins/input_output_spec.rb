# frozen_string_literal: true

require "spec_helper"

RSpec.describe Equilibrium::Mixins::InputOutput do
  let(:test_class) do
    Class.new do
      include Equilibrium::Mixins::InputOutput
    end
  end

  let(:instance) { test_class.new }
  let(:sample_data) { {"test" => "data", "number" => 42} }

  describe "#format_output" do
    it "outputs JSON for json format" do
      expect { instance.format_output(sample_data, "json") }.to output(/{\n.*"test".*"data"/).to_stdout
    end

    it "outputs summary for summary format with analysis summary_type" do
      analysis_data = {
        repository_url: "gcr.io/test/repo",
        status: "perfect",
        expected_count: 3,
        actual_count: 3,
        missing_tags: {},
        mismatched_tags: {},
        unexpected_tags: {}
      }
      expect { instance.format_output(analysis_data, "summary", "analysis") }.not_to raise_error
    end

    it "falls back to JSON for summary format without summary_type" do
      expect { instance.format_output(sample_data, "summary") }.to output(/{\n.*"test".*"data"/).to_stdout
    end

    it "falls back to JSON for unknown format" do
      expect { instance.format_output(sample_data, "unknown") }.to output(/{\n.*"test".*"data"/).to_stdout
    end
  end

  describe "#read_input_data" do
    it "reads from file when file_path provided" do
      temp_file = Tempfile.new("test")
      temp_file.write("test content")
      temp_file.close

      result = instance.read_input_data(temp_file.path)
      expect(result).to eq("test content")

      temp_file.unlink
    end

    it "reads from stdin when no file_path provided" do
      allow($stdin).to receive(:read).and_return("stdin content")

      result = instance.read_input_data
      expect(result).to eq("stdin content")
    end

    it "raises error for empty input" do
      allow($stdin).to receive(:read).and_return("  \n  ")

      expect { instance.read_input_data }.to raise_error("No input provided")
    end

    it "uses custom usage message for empty input" do
      allow($stdin).to receive(:read).and_return("")

      expect { instance.read_input_data(nil, "Custom message") }.to raise_error("Custom message")
    end
  end
end
