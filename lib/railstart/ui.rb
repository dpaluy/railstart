# frozen_string_literal: true

require "tty-box"

module Railstart
  # Provides UI enhancement utilities for the Railstart CLI.
  #
  # Handles ASCII art headers, styled boxes, and visual polish
  # to create a Laravel-like installer experience.
  module UI
    # ASCII art logo for Railstart
    LOGO = <<~LOGO
      ╔═╗┌─┐┬┬  ┌─┐┌┬┐┌─┐┬─┐┌┬┐
      ╠╦╝├─┤││  └─┐ │ ├─┤├┬┘ │
      ╩╚═┴ ┴┴┴─┘└─┘ ┴ ┴ ┴┴└─ ┴
    LOGO

    module_function

    #
    # Display the Railstart ASCII art logo with version and optional color.
    #
    # @param color [Symbol] color name (e.g., :cyan, :green, :magenta)
    # @return [void]
    def show_logo(color: :cyan)
      require_relative "version"
      puts pastel.send(color, LOGO)
      puts pastel.dim("      v#{Railstart::VERSION}")
      puts
    end

    #
    # Display a styled welcome message in a box.
    #
    # @param message [String] the welcome text to display (defaults to Rails version message)
    # @return [void]
    def show_welcome(message = nil)
      message ||= "Interactive Rails #{rails_version} Application Generator"

      box = TTY::Box.frame(
        width: 60,
        height: 3,
        align: :center,
        padding: [0, 1],
        border: :thick,
        style: {
          fg: :cyan,
          border: { fg: :cyan }
        }
      ) { message }

      puts box
      puts # blank line
    end

    #
    # Detect the installed Rails version.
    #
    # @return [String] Rails version or "Unknown" if not found
    def rails_version
      require "bundler"
      Bundler.with_unbundled_env do
        version_output = `rails --version 2>/dev/null`.strip
        version_output[/Rails (\d+\.\d+\.\d+)/, 1] || "Unknown"
      end
    rescue StandardError
      "Unknown"
    end

    #
    # Display a section header with optional separator line.
    #
    # @param title [String] section title
    # @param separator [Boolean] whether to show a line underneath
    # @return [void]
    def section(title, separator: true)
      puts pastel.cyan.bold(title.to_s)
      puts pastel.dim("─" * 60) if separator
    end

    #
    # Display a success message with checkmark.
    #
    # @param message [String] the success message
    # @return [void]
    def success(message)
      puts pastel.green("✓ #{message}")
    end

    #
    # Display a warning message with icon.
    #
    # @param message [String] the warning message
    # @return [void]
    def warning(message)
      puts pastel.yellow("⚠ #{message}")
    end

    #
    # Display an error message with icon.
    #
    # @param message [String] the error message
    # @return [void]
    def error(message)
      puts pastel.red("✗ #{message}")
    end

    #
    # Display an info message with icon.
    #
    # @param message [String] the info message
    # @return [void]
    def info(message)
      puts pastel.blue("ℹ #{message}")
    end

    #
    # Lazy-load Pastel for color formatting.
    #
    # @return [Pastel] pastel instance
    def pastel
      @pastel ||= begin
        require "pastel"
        Pastel.new
      rescue LoadError
        # Fallback to no-op if pastel is not available
        # (tty-prompt depends on pastel, so this should never happen)
        NullPastel.new
      end
    end

    # Null object pattern for when Pastel is unavailable
    class NullPastel
      def method_missing(_method, *args)
        args.first.to_s
      end

      def respond_to_missing?(*)
        true
      end
    end
  end
end
