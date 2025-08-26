# frozen_string_literal: true

require_relative "lib/equilibrium/version"

Gem::Specification.new do |spec|
  spec.name = "equilibrium"
  spec.version = Equilibrium::VERSION
  spec.authors = ["Tony Hsu"]
  spec.email = ["tonyc.t.hsu@gmail.com"]

  spec.summary = "Container image tag validation tool"
  spec.description = "Validates equilibrium between mutable tags and semantic version tags in container registries"
  spec.homepage = "https://github.com/TonyCTHsu/equilibrium"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["github_repo"] = "ssh://github.com/TonyCTHsu/equilibrium"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github Gemfile docker/ tmp/ pkg/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "json_schemer", "~> 2.0"
end
