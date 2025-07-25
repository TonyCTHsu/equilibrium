#!/usr/bin/env ruby

require "json"

def convert_tag_mapping(json_file)
  data = JSON.parse(File.read(json_file))

  versions = data.keys.map { |v| Gem::Version.new(v) }.sort.reverse

  result = {}

  # Latest overall version
  latest_version = versions.first
  result["latest"] = data[latest_version.to_s]

  # Latest major versions (highest minor.patch for each major)
  major_versions = {}
  versions.each do |version|
    major = version.segments[0]
    if !major_versions[major] || version > major_versions[major]
      major_versions[major] = version
    end
  end

  major_versions.values.sort.reverse_each do |version|
    major_tag = version.segments[0].to_s
    result[major_tag] = data[version.to_s]
  end

  # Latest minor versions (highest patch for each major.minor)
  minor_versions = {}
  versions.each do |version|
    major_minor = "#{version.segments[0]}.#{version.segments[1]}"
    if !minor_versions[major_minor] || version > minor_versions[major_minor]
      minor_versions[major_minor] = version
    end
  end

  minor_versions.values.sort.reverse_each do |version|
    minor_tag = "#{version.segments[0]}.#{version.segments[1]}"
    result[minor_tag] = data[version.to_s]
  end

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
