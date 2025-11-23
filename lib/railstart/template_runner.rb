# frozen_string_literal: true

require "thor"
require_relative "errors"

module Railstart
  # Executes Rails application templates (including RailsBytes scripts)
  # inside a generated application directory.
  #
  # Wraps Rails' own AppGenerator so existing template DSL helpers such as
  # `gem`, `initializer`, `route`, etc. are available without reimplementing
  # them in Railstart.
  class TemplateRunner
    # @param app_path [String] absolute path to the Rails application
    # @param generator_factory [#call] optional factory for injecting a
    #   generator (mainly used in tests)
    # @param shell [Thor::Shell] Thor shell instance for output
    def initialize(app_path:, generator_factory: nil, shell: Thor::Base.shell.new)
      @app_path = app_path
      @shell = shell
      @generator_factory = generator_factory
    end

    # Apply a Rails template located at +source+.
    #
    # @param source [String] file path or URL
    # @param variables [Hash] instance variables injected into the template
    # @return [void]
    # @raise [Railstart::TemplateError] when Rails cannot be loaded or
    #   template execution fails
    def apply(source, variables: {})
      raise TemplateError, "Template source must be provided" if source.to_s.strip.empty?

      generator = build_generator
      assign_variables(generator, variables)
      generator.apply(source)
    rescue TemplateError
      raise
    rescue LoadError => e
      raise TemplateError, "Rails must be installed to run template post-actions: #{e.message}"
    rescue StandardError => e
      raise TemplateError, "Failed to apply template #{source}: #{e.message}"
    end

    private

    def assign_variables(generator, variables)
      Array(variables).each do |key, value|
        generator.instance_variable_set(:"@#{key}", value)
      end
    end

    def build_generator
      generator = generator_factory.call(@app_path)
      if generator.respond_to?(:destination_root=)
        generator.destination_root = @app_path
      elsif generator.respond_to?(:destination_root)
        generator.instance_variable_set(:@destination_root, @app_path)
      end
      generator
    end

    def generator_factory
      @generator_factory ||= default_generator_factory
    end

    def default_generator_factory
      require "rails/generators"
      require "rails/generators/rails/app/app_generator"

      shell = @shell
      lambda do |_app_path|
        Rails::Generators::AppGenerator.new([], {}, shell: shell)
      end
    end
  end
end
