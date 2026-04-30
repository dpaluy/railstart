# frozen_string_literal: true

require "test_helper"

module Railstart
  class ExamplesTest < Minitest::Test
    ROOT = File.expand_path("..", __dir__)
    USER_CONFIG_EXAMPLE = File.join(ROOT, "examples/config.yml")
    EXAMPLE_YAML_FILES = Dir[File.join(ROOT, "examples/**/*.yml")].freeze
    PRESET_EXAMPLES = Dir[File.join(ROOT, "examples/presets/*.yml")].freeze

    def test_user_config_example_loads_as_user_config
      config = Config.load(user_path: USER_CONFIG_EXAMPLE)
      skip_features = config["questions"].find { |entry| entry["id"] == "skip_features" }

      assert_equal "postgresql", default_value_for(config, "database")
      assert_includes skip_features["default"], "action_mailbox"
    end

    def test_preset_examples_load_and_build_default_commands
      refute_empty PRESET_EXAMPLES

      PRESET_EXAMPLES.each do |path|
        config = Config.load(user_path: nil, preset_path: path)
        command = CommandBuilder.build("example_app", config, default_answers(config))

        assert_match(/\Arails new example_app/, command, "Expected #{path} to build a rails command")
        refute_match(/%\{value\}|%<value>/, command, "Expected #{path} to interpolate all flags")
      end
    end

    def test_examples_do_not_select_a_test_framework
      refute_empty EXAMPLE_YAML_FILES

      EXAMPLE_YAML_FILES.each do |path|
        text = File.read(path)

        refute_match(/\brspec\b/i, text, "Expected #{path} to avoid RSpec-specific examples")
        refute_match(/\btest_framework\b/, text, "Expected #{path} to leave the test framework default alone")
      end
    end

    private

    def default_value_for(config, question_id)
      question = config["questions"].find { |entry| entry["id"] == question_id }
      choice = question["choices"].find { |entry| entry["default"] } || question["choices"].first
      choice["value"]
    end

    def default_answers(config)
      config["questions"].each_with_object({}) do |question, answers|
        answers[question["id"]] =
          case question["type"]
          when "select"
            default_value_for(config, question["id"])
          when "multi_select"
            question.fetch("default", [])
          when "yes_no"
            question.fetch("default", false)
          when "input"
            question["default"]
          end
      end
    end
  end
end
