# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Railstart
  class FileWriterTest < Minitest::Test
    def test_writes_inline_content_with_app_name_interpolation
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        # rubocop:disable-next Style/FormatStringToken -- `%{token}` is the documented interpolation style
        result = writer.write(path: "AGENTS.md", content: "# %{app_name} guide")

        assert_equal :written, result
        assert_equal "# blog guide", File.read(File.join(dir, "AGENTS.md"))
      end
    end

    def test_creates_parent_directories
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        writer.write(path: "docs/guides/intro.md", content: "hi")

        assert_equal "hi", File.read(File.join(dir, "docs/guides/intro.md"))
      end
    end

    def test_skips_existing_file_unless_overwrite
      Dir.mktmpdir do |dir|
        target = File.join(dir, "AGENTS.md")
        File.write(target, "original")
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        result = writer.write(path: "AGENTS.md", content: "new", overwrite: false)

        assert_equal :skipped, result
        assert_equal "original", File.read(target)
      end
    end

    def test_overwrites_existing_file_when_enabled
      Dir.mktmpdir do |dir|
        target = File.join(dir, "AGENTS.md")
        File.write(target, "original")
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        result = writer.write(path: "AGENTS.md", content: "new", overwrite: true)

        assert_equal :written, result
        assert_equal "new", File.read(target)
      end
    end

    def test_resolves_relative_source_against_templates_dir
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        result = writer.write(path: "AGENTS.md", source: "AGENTS.md")

        assert_equal :written, result
        written = File.read(File.join(dir, "AGENTS.md"))
        assert_equal "# blog: Agent Guide", written.lines.first.chomp
        # rubocop:disable-next Style/FormatStringToken -- `%{token}` is the documented interpolation style
        refute_includes written, "%{app_name}"
      end
    end

    def test_resolves_absolute_source_as_is
      Dir.mktmpdir do |dir|
        source = File.join(dir, "custom.md")
        File.write(source, "custom content")
        app_dir = Dir.mktmpdir
        writer = FileWriter.new(app_path: app_dir, app_name: "blog")

        writer.write(path: "AGENTS.md", source: source)

        assert_equal "custom content", File.read(File.join(app_dir, "AGENTS.md"))
      end
    end

    def test_raises_when_source_is_missing
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        error = assert_raises(Railstart::Error) do
          writer.write(path: "AGENTS.md", source: "does-not-exist.md")
        end
        assert_includes error.message, "Cannot read file post-action source"
      end
    end

    def test_preserves_source_executable_bit
      Dir.mktmpdir do |dir|
        source = File.join(dir, "ci")
        File.write(source, "#!/usr/bin/env bash\n")
        FileUtils.chmod(0o755, source)
        app_dir = Dir.mktmpdir
        writer = FileWriter.new(app_path: app_dir, app_name: "blog")

        writer.write(path: "bin/ci", source: source)

        assert File.executable?(File.join(app_dir, "bin/ci"))
      end
    end

    def test_rejects_target_path_escaping_app_directory
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        error = assert_raises(Railstart::Error) do
          writer.write(path: "../outside.txt", content: "x")
        end
        assert_includes error.message, "Unsafe file post-action path"
      end
    end

    def test_rejects_relative_source_escaping_templates_dir
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        error = assert_raises(Railstart::Error) do
          writer.write(path: "out.txt", source: "../../railstart.gemspec")
        end
        assert_includes error.message, "Unsafe file post-action source"
      end
    end

    def test_passes_literal_percent_signs_through_unchanged
      Dir.mktmpdir do |dir|
        writer = FileWriter.new(app_path: dir, app_name: "blog")

        # rubocop:disable-next Style/FormatStringToken -- `%{token}` is the documented interpolation style
        writer.write(path: "notes.txt", content: 'printf "%s" covers 100% of %{app_name}')

        assert_equal 'printf "%s" covers 100% of blog', File.read(File.join(dir, "notes.txt"))
      end
    end
  end
end
