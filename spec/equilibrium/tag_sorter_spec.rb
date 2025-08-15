# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Equilibrium::TagSorter do
  let(:sorter) { described_class.new }

  describe "#sort_descending" do
    context "with empty or nil input" do
      it "returns empty hash for nil input" do
        expect(described_class.sort_descending(nil)).to eq({})
      end

      it "returns empty hash for empty hash input" do
        expect(described_class.sort_descending({})).to eq({})
      end
    end

    context "with latest tag only" do
      it "preserves latest tag alone" do
        input = {"latest" => "sha256:abc123"}
        expected = {"latest" => "sha256:abc123"}
        expect(described_class.sort_descending(input)).to eq(expected)
      end
    end

    context "with major version tags" do
      it "sorts major versions in descending order" do
        input = {
          "1" => "sha256:v1",
          "3" => "sha256:v3",
          "2" => "sha256:v2"
        }
        expected = {
          "3" => "sha256:v3",
          "2" => "sha256:v2",
          "1" => "sha256:v1"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end

      it "handles single digit and multi-digit major versions" do
        input = {
          "9" => "sha256:v9",
          "10" => "sha256:v10",
          "2" => "sha256:v2"
        }
        expected = {
          "10" => "sha256:v10",
          "9" => "sha256:v9",
          "2" => "sha256:v2"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end
    end

    context "with minor version tags" do
      it "sorts minor versions in descending order" do
        input = {
          "0.1" => "sha256:v01",
          "0.3" => "sha256:v03",
          "0.2" => "sha256:v02"
        }
        expected = {
          "0.3" => "sha256:v03",
          "0.2" => "sha256:v02",
          "0.1" => "sha256:v01"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end

      it "sorts minor versions across different major versions" do
        input = {
          "1.1" => "sha256:v11",
          "0.3" => "sha256:v03",
          "1.2" => "sha256:v12",
          "0.1" => "sha256:v01"
        }
        expected = {
          "1.2" => "sha256:v12",
          "1.1" => "sha256:v11",
          "0.3" => "sha256:v03",
          "0.1" => "sha256:v01"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end
    end

    context "with mixed tag types" do
      it "places latest first, then major versions, then minor versions in descending order" do
        input = {
          "0.1" => "sha256:v01",
          "latest" => "sha256:latest",
          "2" => "sha256:v2",
          "1.5" => "sha256:v15",
          "1" => "sha256:v1",
          "0.3" => "sha256:v03"
        }
        expected = {
          "latest" => "sha256:latest",
          "2" => "sha256:v2",
          "1" => "sha256:v1",
          "1.5" => "sha256:v15",
          "0.3" => "sha256:v03",
          "0.1" => "sha256:v01"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end
    end

    context "with real-world example" do
      it "sorts container tags as expected" do
        input = {
          "0.17" => "sha256:v017",
          "latest" => "sha256:latest",
          "0" => "sha256:v0",
          "0.43" => "sha256:v043",
          "0.42" => "sha256:v042",
          "0.18" => "sha256:v018"
        }
        expected = {
          "latest" => "sha256:latest",
          "0" => "sha256:v0",
          "0.43" => "sha256:v043",
          "0.42" => "sha256:v042",
          "0.18" => "sha256:v018",
          "0.17" => "sha256:v017"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end
    end

    context "with unexpected tag formats" do
      it "sorts unexpected formats alphabetically at the end" do
        input = {
          "latest" => "sha256:latest",
          "1" => "sha256:v1",
          "beta" => "sha256:beta",
          "alpha" => "sha256:alpha",
          "0.1" => "sha256:v01"
        }
        expected = {
          "latest" => "sha256:latest",
          "1" => "sha256:v1",
          "0.1" => "sha256:v01",
          "alpha" => "sha256:alpha",
          "beta" => "sha256:beta"
        }
        expect(described_class.sort_descending(input)).to eq(expected)
      end
    end
  end

  describe ".sort_descending" do
    it "provides class method interface" do
      input = {
        "latest" => "sha256:latest",
        "1" => "sha256:v1",
        "0.1" => "sha256:v01"
      }
      expected = {
        "latest" => "sha256:latest",
        "1" => "sha256:v1",
        "0.1" => "sha256:v01"
      }
      expect(described_class.sort_descending(input)).to eq(expected)
    end
  end

  describe "private methods" do
    describe "#major_version?" do
      it "identifies major version patterns" do
        expect(described_class.send(:major_version?, "0")).to be true
        expect(described_class.send(:major_version?, "1")).to be true
        expect(described_class.send(:major_version?, "42")).to be true
        expect(described_class.send(:major_version?, "latest")).to be false
        expect(described_class.send(:major_version?, "1.0")).to be false
        expect(described_class.send(:major_version?, "v1")).to be false
      end
    end

    describe "#minor_version?" do
      it "identifies minor version patterns" do
        expect(described_class.send(:minor_version?, "0.1")).to be true
        expect(described_class.send(:minor_version?, "1.0")).to be true
        expect(described_class.send(:minor_version?, "42.13")).to be true
        expect(described_class.send(:minor_version?, "latest")).to be false
        expect(described_class.send(:minor_version?, "1")).to be false
        expect(described_class.send(:minor_version?, "1.0.1")).to be false
      end
    end
  end
end
