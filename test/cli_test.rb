# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Railstart
  class CLITest < Minitest::Test
    def test_preset_option_accepts_explicit_yaml_path
      Dir.mktmpdir do |dir|
        path = File.join(dir, "custom.yaml")
        File.write(path, "---")

        cli = Railstart::CLI.new
        cli.stub(:options, { preset: path }) do
          resolved = cli.send(:preset_file_for, path)
          assert_equal File.expand_path(path), resolved
        end
      end
    end

    def test_missing_explicit_yaml_path_raises_error
      cli = Railstart::CLI.new
      missing_path = "/tmp/does-not-exist-custom.yaml"

      cli.stub(:options, { preset: missing_path }) do
        error = assert_raises(Railstart::ConfigLoadError) do
          cli.send(:preset_file_for, missing_path)
        end
        assert_includes error.message, "Preset file"
      end
    end

    def test_init_generates_minimal_user_config_override
      cli = Railstart::CLI.new
      user_config = cli.send(:example_user_config)

      parsed = YAML.safe_load(user_config, permitted_classes: [Symbol])

      question_ids = parsed.fetch("questions").map { |question| question.fetch("id") }
      action_ids = parsed.fetch("post_actions").map { |action| action.fetch("id") }

      assert_equal %w[database skip_docker], question_ids
      assert_equal ["bundle_install"], action_ids
      refute_includes user_config, "choices:"
      assert_includes user_config, "config/rails8_defaults.yaml"

      Dir.mktmpdir do |dir|
        path = File.join(dir, "config.yaml")
        File.write(path, user_config)

        config = Config.load(user_path: path)
        assert_equal "postgresql", config.fetch("questions").first.fetch("default")
      end
    end
  end
end
