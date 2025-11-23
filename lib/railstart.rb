# frozen_string_literal: true

require_relative "railstart/version"
require_relative "railstart/errors"
require_relative "railstart/config"
require_relative "railstart/command_builder"
require_relative "railstart/generator"
require_relative "railstart/template_runner"
require_relative "railstart/cli"

# Main namespace for the Railstart gem.
#
# Provides an interactive CLI wizard for generating Rails 8 applications
# with customizable configuration and post-generation hooks.
#
# @example Generate a new Rails app
#   $ railstart new my_app
#
# @see CLI
# @see Generator
# @see Config
module Railstart
end
