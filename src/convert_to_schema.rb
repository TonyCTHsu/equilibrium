#!/usr/bin/env ruby

require "json"
require "json_schemer"

if ARGV.length < 3
  puts "Usage: #{$0} <input_file> <output_file> <registry>"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]
registry = ARGV[2]

unless File.exist?(input_file)
  puts "Error: Input file '#{input_file}' does not exist"
  exit 1
end

data = JSON.parse(File.read(input_file))

# Extract image name without registry (e.g., "gcr.io/datadoghq/apm-inject" -> "apm-inject")
name_only = registry.split("/").last

images = data.map do |tag, digest|
  {
    "name" => name_only,
    "tag" => tag,
    "digest" => digest
  }
end

output = {"images" => images}

# Validate against schema before writing
schema_file = File.join(File.dirname(__FILE__), "schema.json")
schemer = JSONSchemer.schema(File.read(schema_file))

errors = schemer.validate(output).to_a
if errors.empty?
  puts "✓ Schema validation passed"
else
  puts "✗ Schema validation failed:"
  errors.each { |error| puts "  #{error["error"]}" }
  exit 1
end

File.write(output_file, JSON.pretty_generate(output))
