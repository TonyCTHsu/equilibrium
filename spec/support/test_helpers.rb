# frozen_string_literal: true

module EquilibriumTestHelpers
  def sample_tags_response
    @sample_tags_response ||= JSON.parse(File.read(File.expand_path("../fixtures/sample_registry_response.json", __dir__)))
  end

  def stub_registry_api(repository_url, tags_response: sample_tags_response)
    parts = repository_url.split("/")
    host = parts[0]
    project = parts[1]
    image = parts[2..].join("/")

    tags_url = "https://#{host}/v2/#{project}/#{image}/tags/list"
    stub_request(:get, tags_url).to_return(
      status: 200,
      body: tags_response.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

  def create_temp_json_file(data)
    require "tempfile"
    file = Tempfile.new(["test", ".json"])
    file.write(JSON.pretty_generate(data))
    file.close
    file.path
  end
end
