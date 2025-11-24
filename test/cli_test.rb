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

    def test_init_copies_rails8_defaults_yaml_content
      cli = Railstart::CLI.new
      user_config = cli.send(:example_user_config)

      # Verify it contains the full rails8_defaults.yaml structure
      assert_includes user_config, "questions:"
      assert_includes user_config, "post_actions:"
      assert_includes user_config, "id: database"
      assert_includes user_config, "id: css"
      assert_includes user_config, "id: javascript"
      assert_includes user_config, "id: test_framework"
      assert_includes user_config, "id: init_git"
      assert_includes user_config, "id: setup_rspec"

      # Verify it's valid YAML
      parsed = YAML.safe_load(user_config, permitted_classes: [Symbol])
      assert parsed["questions"].is_a?(Array)
      assert parsed["post_actions"].is_a?(Array)
    end
  end
end
