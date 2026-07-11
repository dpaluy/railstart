# frozen_string_literal: true

require "test_helper"

module Railstart
  class ShippedConfigTest < Minitest::Test
    API_ONLY_PRESET_PATH = File.expand_path("../config/presets/api-only.yaml", __dir__)

    def test_builtin_none_css_choice_emits_skip_css
      config = Config.load(user_path: nil)
      command = CommandBuilder.build("blog", config, { "css" => "none" })

      assert_includes command, "--skip-css"
      refute_includes command, "--css=none"
    end

    def test_api_only_preset_default_command_emits_skip_css
      config = Config.load(user_path: nil, preset_path: API_ONLY_PRESET_PATH)
      command = CommandBuilder.build("api", config, default_answers(config))

      assert_includes command, "--skip-css"
      refute_includes command, "--css=none"
    end

    private

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
