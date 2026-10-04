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

    def test_builtin_file_post_actions_reference_shipped_templates
      config = Config.load(user_path: nil)

      agents = config["post_actions"].find { |action| action["id"] == "write_agents_md" }
      assert_equal "file", agents["type"]
      assert_equal "AGENTS.md", agents["path"]
      assert_equal "AGENTS.md", agents["source"]
      assert agents["enabled"]
      refute agents["overwrite"]

      bin_ci = config["post_actions"].find { |action| action["id"] == "setup_bin_ci" }
      assert_equal "file", bin_ci["type"]
      assert_equal "bin/ci", bin_ci["path"]
      refute bin_ci["enabled"]

      assert File.exist?(File.join(FileWriter::TEMPLATES_DIR, "AGENTS.md"))
      assert File.executable?(File.join(FileWriter::TEMPLATES_DIR, "bin", "ci"))
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
