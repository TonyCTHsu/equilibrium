# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/equilibrium/schema_validator"

RSpec.describe Equilibrium::SchemaValidator do
  let(:simple_schema) do
    {
      "type" => "object",
      "required" => ["name"],
      "properties" => {
        "name" => {"type" => "string"},
        "age" => {"type" => "integer"}
      },
      "additionalProperties" => false
    }
  end

  describe ".validate!" do
    it "passes validation for valid data" do
      valid_data = {"name" => "test"}

      expect {
        described_class.validate!(valid_data, simple_schema)
      }.not_to raise_error
    end

    it "raises ValidationError for invalid data" do
      invalid_data = {"age" => 25} # missing required "name"

      expect {
        described_class.validate!(invalid_data, simple_schema)
      }.to raise_error(Equilibrium::SchemaValidator::ValidationError, /Schema validation failed/)
    end

    it "includes custom error prefix" do
      invalid_data = {"age" => 25}

      expect {
        described_class.validate!(invalid_data, simple_schema, error_prefix: "Custom validation failed")
      }.to raise_error(Equilibrium::SchemaValidator::ValidationError, /Custom validation failed/)
    end

    it "includes detailed error information" do
      invalid_data = {"name" => 123} # wrong type

      expect {
        described_class.validate!(invalid_data, simple_schema)
      }.to raise_error(Equilibrium::SchemaValidator::ValidationError, /not a string/)
    end
  end
end
