# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Railstart
  class CLITest < Minitest::Test
    def test_new_passes_yes_option_to_generator
      config = { "questions" => [], "post_actions" => [] }
      captured = nil
      fake_generator = Minitest::Mock.new
      fake_generator.expect :run, nil

      generator_new = lambda do |app_name, **kwargs|
        captured = { app_name: app_name, kwargs: kwargs }
        fake_generator
      end

      Config.stub :load, config do
        Generator.stub :new, generator_new do
          Railstart::CLI.start(%w[new my_app --yes])
        end
      end

      assert_equal "my_app", captured[:app_name]
      assert_equal config, captured[:kwargs][:config]
      assert_equal true, captured[:kwargs][:use_defaults]
      assert_equal true, captured[:kwargs][:assume_yes]
      fake_generator.verify
    end

    def test_new_parses_short_yes_alias
      config = { "questions" => [], "post_actions" => [] }
      captured_assume_yes = nil
      fake_generator = Minitest::Mock.new
      fake_generator.expect :run, nil

      generator_new = lambda do |_app_name, **kwargs|
        captured_assume_yes = kwargs[:assume_yes]
        fake_generator
      end

      Config.stub :load, config do
        Generator.stub :new, generator_new do
          Railstart::CLI.start(%w[new my_app -y])
        end
      end

      assert_equal true, captured_assume_yes
      fake_generator.verify
    end

    def test_new_yes_without_app_name_exits_with_error
      config = { "questions" => [], "post_actions" => [] }
      out = nil

      Config.stub :load, config do
        out, = capture_io do
          assert_raises(SystemExit) { Railstart::CLI.start(%w[new --yes]) }
        end
      end

      assert_includes out, "APP_NAME is required when running in --yes mode"
    end

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
