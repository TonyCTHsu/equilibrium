#!/usr/bin/env ruby

require "json"

def convert_tag_mapping(json_file)
  data = JSON.parse(File.read(json_file))

  latest_version = nil
  major_versions = {}
  minor_versions = {}

  # Single pass to find all maximums
  data.keys.each do |version_str|
    version = Gem::Version.new(version_str)

    # Track overall latest
    latest_version = version if !latest_version || version > latest_version

    # Track latest for each major
    major = version.segments[0]
    major_versions[major] = version if !major_versions[major] || version > major_versions[major]

    # Track latest for each minor
    major_minor = "#{version.segments[0]}.#{version.segments[1]}"
    minor_versions[major_minor] = version if !minor_versions[major_minor] || version > minor_versions[major_minor]
  end

  # Build result
  result = {}
  result["latest"] = data[latest_version.to_s]

  major_versions.each { |_, v| result[v.segments[0].to_s] = data[v.to_s] }
  minor_versions.each { |_, v| result["#{v.segments[0]}.#{v.segments[1]}"] = data[v.to_s] }

  result
end

# Usage
if __FILE__ == $0
  if ARGV.length < 1
    puts "Usage: #{$0} <semantic_versions.json> [output_file]"
    exit 1
  end

  json_file = ARGV[0]
  output_file = ARGV[1] || begin
    puts "Error: output_file required when not called from main workflow"
    puts "Usage: #{$0} <semantic_versions.json> <output_file>"
    exit 1
  end

  result = convert_tag_mapping(json_file)

  # Sort keys in descending order for better human readability
  sorted_result = result.sort_by { |k, v| k }.reverse.to_h
  File.write(output_file, JSON.pretty_generate(sorted_result))
  puts "Written mutable tag mapping to #{output_file}"
end
