# frozen_string_literal: true

require "open3"
require "bundler"
require "test_helper"

module Railstart
  class RailsCLIContractTest < Minitest::Test
    PRESET_PATHS = Dir[File.expand_path("../config/presets/*.yaml", __dir__)].freeze

    def test_shipped_default_commands_are_accepted_by_rails
      skip "Set RAILS_CONTRACT=1 to test against the installed Rails CLI" unless ENV["RAILS_CONTRACT"] == "1"

      configurations.each do |name, config|
        arguments = CommandBuilder.arguments("railstart_contract", config, default_answers(config))
        output, error, status = Bundler.with_unbundled_env do
          Open3.capture3(*arguments, "--pretend")
        end

        assert status.success?, "#{name} config was rejected by Rails:\n#{output}\n#{error}"
      end
    end

    private

    def configurations
      { "built-in" => Config.load(user_path: nil) }.merge(
        PRESET_PATHS.to_h do |path|
          [File.basename(path, ".yaml"), Config.load(user_path: nil, preset_path: path)]
        end
      )
    end

    def default_answers(config)
      config.fetch("questions").to_h do |question|
        default = if question.key?("default")
                    question["default"]
                  else
                    question.fetch("choices", []).find { |choice| choice["default"] }&.fetch("value")
                  end
        [question.fetch("id"), default]
      end
    end
  end
end
