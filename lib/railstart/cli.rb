# frozen_string_literal: true

require "thor"
require_relative "generator"

module Railstart
  # CLI commands for Railstart, exposing Thor tasks for interactive generation.
  #
  # @example Run the wizard with defaults
  #   Railstart::CLI.start(%w[new my_app --default])
  # @example Print version
  #   Railstart::CLI.start(%w[version])
  class CLI < Thor
    default_command :new

    desc "new [APP_NAME]", "Start a new interactive Rails app setup"
    option :default, type: :boolean, default: false, desc: "Use default configuration without prompting"
    #
    # @param app_name [String, nil] desired Rails app name, prompted if omitted
    # @return [void]
    # @raise [Railstart::Error] when generation fails due to configuration or runtime errors
    # @example Start wizard with prompts
    #   Railstart::CLI.start(%w[new my_app])
    def new(app_name = nil)
      generator = Generator.new(app_name)
      generator.run
    rescue Railstart::Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc "version", "Print Railstart version"
    #
    # @return [void]
    # @example Display version string
    #   Railstart::CLI.start(%w[version])
    def version
      puts "Railstart v#{Railstart::VERSION}"
    end
  end
end
