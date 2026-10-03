# frozen_string_literal: true

require "fileutils"
require "pathname"
require_relative "errors"

module Railstart
  # Writes lightweight files into a generated application directory.
  #
  # Backs `type: file` post-actions, providing a way to ship small files
  # (AGENTS.md, scripts, dotfiles) without loading Rails in-process like
  # template post-actions do.
  #
  # @example Write a file from inline content
  #   writer = Railstart::FileWriter.new(app_path: Dir.pwd, app_name: "blog")
  #   writer.write(path: "AGENTS.md", content: "# %{app_name}")
  class FileWriter
    # Directory inside the gem where relative `source` paths resolve.
    TEMPLATES_DIR = File.expand_path("../../config/templates", __dir__)

    #
    # @param app_path [String] absolute path to the generated application
    # @param app_name [String] application name used for `%{app_name}` interpolation
    def initialize(app_path:, app_name:)
      @app_path = app_path
      @app_name = app_name
    end

    #
    # Write a file into the application directory.
    #
    # @param path [String] target path relative to the application root
    # @param content [String, nil] inline file content (mutually exclusive with `source`)
    # @param source [String, nil] template file path; relative paths resolve
    #   against the gem's config/templates directory, absolute or ~/ paths are used as-is
    # @param overwrite [Boolean] replace an existing file when true
    # @return [Symbol] :written when the file was written, :skipped when it
    #   already existed and `overwrite` is false
    # @raise [Railstart::Error] when the target path escapes the app, the
    #   source escapes config/templates, or the source file cannot be read
    def write(path:, content: nil, source: nil, overwrite: false)
      target = safe_target(path)
      return :skipped if File.exist?(target) && !overwrite

      source_path = resolve_source(source) if source
      body = interpolate(source_path ? read_source(source_path) : content.to_s)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, body)
      FileUtils.chmod(File.stat(source_path).mode & 0o777, target) if source_path
      :written
    end

    private

    def safe_target(path)
      root = File.expand_path(@app_path)
      target = File.expand_path(path.to_s, root)
      return target if target.start_with?("#{root}#{File::SEPARATOR}")

      raise Error, "Unsafe file post-action path #{path.inspect}: must stay inside the app directory"
    end

    def resolve_source(source)
      raw = source.to_s
      expanded = raw.start_with?("~") ? File.expand_path(raw) : raw
      return expanded if Pathname.new(expanded).absolute?

      resolved = File.expand_path(expanded, TEMPLATES_DIR)
      return resolved if resolved.start_with?("#{TEMPLATES_DIR}#{File::SEPARATOR}")

      raise Error, "Unsafe file post-action source #{source.inspect}: must stay inside #{TEMPLATES_DIR}"
    end

    def read_source(source_path)
      File.read(source_path)
    rescue SystemCallError => e
      raise Error, "Cannot read file post-action source #{source_path}: #{e.message}"
    end

    # Replaces only the documented `%{app_name}` token so literal `%`
    # characters in file content (printf, percentages) pass through unchanged.
    def interpolate(body)
      # rubocop:disable-next Style/FormatStringToken -- `%{token}` is the documented interpolation style
      body.gsub("%{app_name}", @app_name.to_s)
    end
  end
end
