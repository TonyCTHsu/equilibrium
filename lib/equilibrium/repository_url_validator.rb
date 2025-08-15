# frozen_string_literal: true

require "thor"

module Equilibrium
  module RepositoryUrlValidator
    def self.validate(repository_url)
      unless repository_url.include?("/")
        raise Thor::Error, "Repository URL must be full format (e.g., 'gcr.io/project-id/image-name'), not '#{repository_url}'"
      end
      repository_url
    end
  end
end
