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
  end
end
