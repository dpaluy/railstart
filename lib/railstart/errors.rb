# frozen_string_literal: true

module Railstart
  # Base error class for all Railstart-specific failures.
  class Error < StandardError; end

  # Raised for configuration-related issues within Railstart.
  class ConfigError < Error; end

  # Raised when configuration files cannot be read or parsed.
  class ConfigLoadError < ConfigError; end

  # Raised when configuration validation fails with one or more issues.
  #
  # @attr_reader issues [Array<String>] collection of validation error descriptions
  class ConfigValidationError < ConfigError
    attr_reader :issues

    #
    # @param message [String] base message explaining the failure
    # @param issues [Array<String>] detailed validation error messages
    def initialize(message = "Invalid configuration", issues: [])
      @issues = Array(issues)
      detail = @issues.empty? ? message : "#{message}:\n- #{@issues.join("\n- ")}"
      super(detail)
    end
  end

  # Raised when applying Rails templates fails.
  class TemplateError < Error; end
end
