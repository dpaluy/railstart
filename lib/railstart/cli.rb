# frozen_string_literal: true

require "thor"
require "fileutils"
require_relative "generator"

module Railstart
  # CLI commands for Railstart, exposing Thor tasks for interactive generation.
  #
  # @example Run the wizard with defaults
  #   Railstart::CLI.start(%w[new my_app --default])
  # @example Print version
  #   Railstart::CLI.start(%w[version])
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Show help by default when no command is given
    def self.start(given_args = ARGV, config = {})
      if given_args.empty?
        # Show command list instead of requiring a command argument
        puts "Railstart - Interactive Rails 8 application generator"
        puts ""
        puts "Usage:"
        puts "  railstart init                      # Generate config files"
        puts "  railstart new [APP_NAME] [OPTIONS]  # Generate a new Rails app"
        puts "  railstart version                   # Show version"
        puts "  railstart help [COMMAND]            # Show help for a command"
        puts ""
        puts "Quick Start:"
        puts "  railstart init                      # Create config files (optional)"
        puts "  railstart new my_app                # Interactive mode"
        puts "  railstart new my_app --default      # Use defaults"
        puts "  railstart new my_app --preset api-only  # Use preset"
        puts ""
        puts "Run 'railstart help init' or 'railstart help new' for details"
        return
      end
      super
    end

    # Custom banner to show available options
    class << self
      # rubocop:disable Style/OptionalBooleanParameter
      def banner(command, _namespace = nil, _subcommand = false)
        "#{basename} #{command.usage}"
      end

      # Override to show only positive form of boolean options
      def help(shell, subcommand = false)
        # rubocop:enable Style/OptionalBooleanParameter
        list = printable_commands(true, subcommand)
        Thor::Util.thor_classes_in(self).each do |klass|
          list += klass.printable_commands(false)
        end

        shell.say "Commands:"
        shell.print_table(list, indent: 2, truncate: true)
        shell.say
        class_options_help(shell)
      end
    end

    # Override to customize option display
    # rubocop:disable Style/OptionalBooleanParameter
    def help(command = nil, subcommand = false)
      # rubocop:enable Style/OptionalBooleanParameter
      if command
        if self.class.subcommands.include?(command)
          self.class.subcommand_classes[command].help(shell, subcommand)
        else
          cmd = self.class.all_commands[command]
          raise Thor::UndefinedCommandError, "Could not find command '#{command}'." unless cmd

          shell.say "Usage:"
          shell.say "  #{self.class.banner(cmd)}"
          shell.say
          if cmd.long_description
            shell.say "Description:"
            shell.print_wrapped(cmd.long_description, indent: 2)
          else
            shell.say cmd.description
          end

          print_custom_options(cmd)
        end
      else
        super
      end
    end

    no_commands do
      def print_custom_options(cmd)
        return unless cmd.options.any?

        shell.say
        shell.say "Options:"
        cmd.options.each do |name, option|
          print_option(name, option)
        end
      end

      def print_option(name, option)
        # For boolean options, only show the positive form
        if option.type == :boolean
          shell.say "  [--#{name}]#{" " * [20 - name.length, 0].max}# #{option.description}"
        else
          print_non_boolean_option(name, option)
        end
      end

      def print_non_boolean_option(name, option)
        banner_text = option.banner || name.to_s.upcase
        padding = [20 - (name.length + banner_text.length + 3), 0].max
        shell.say "  [--#{name}=#{banner_text}]#{" " * padding}# #{option.description}"
      end
    end
    desc "new [APP_NAME]", "Generate a new Rails 8 application"
    long_desc <<~DESC
      Generate a new Rails 8 application with an interactive wizard.

      Modes:
        - Interactive (default): prompts for each question
        - With preset: uses preset config (different questions/defaults), interactive or non-interactive

      Examples:
        railstart new my_app                          # Interactive mode
        railstart new my_app --default                # Non-interactive with default preset (if exists)
        railstart new my_app --preset api-only        # Interactive with api-only preset config
        railstart new my_app --preset api-only --default  # Non-interactive with api-only preset

      Presets are stored in: ~/.config/railstart/presets/*.yaml
    DESC
    option :default, type: :boolean, default: false, desc: "Use defaults non-interactively"
    option :preset, type: :string, desc: "Preset name from ~/.config/railstart/presets/", banner: "NAME"
    #
    # @param app_name [String, nil] desired Rails app name, prompted if omitted
    # @return [void]
    # @raise [Railstart::Error] when generation fails due to configuration or runtime errors
    # @example Start wizard with prompts
    #   Railstart::CLI.start(%w[new my_app])
    # @example Use preset
    #   Railstart::CLI.start(%w[new my_app --preset api-only])
    # @example Use default preset non-interactively
    #   Railstart::CLI.start(%w[new my_app --default])
    def new(app_name = nil)
      preset_name = determine_preset_name
      preset_path = preset_name ? preset_file_for(preset_name) : nil

      config = Config.load(preset_path: preset_path)

      generator = Generator.new(
        app_name,
        config: config,
        use_defaults: options[:default]
      )

      generator.run
    rescue Railstart::Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc "init", "Generate config directory and starter files"
    long_desc <<~DESC
      Creates ~/.config/railstart directory structure with example configuration files.

      This generates:
        - ~/.config/railstart/config.yaml (example user config)
        - ~/.config/railstart/presets/ directory
        - ~/.config/railstart/presets/example.yaml (example preset)

      You can then customize these files for your preferences.
    DESC
    option :force, type: :boolean, default: false, desc: "Overwrite existing files"
    #
    # @return [void]
    # @example Generate config files
    #   Railstart::CLI.start(%w[init])
    def init
      config_dir = File.expand_path("~/.config/railstart")
      presets_dir = File.join(config_dir, "presets")

      # Create directories
      FileUtils.mkdir_p(presets_dir)
      puts "✓ Created #{config_dir}"
      puts "✓ Created #{presets_dir}"

      # Generate example user config
      user_config_path = File.join(config_dir, "config.yaml")
      if File.exist?(user_config_path) && !options[:force]
        puts "⊗ Skipped #{user_config_path} (already exists, use --force to overwrite)"
      else
        File.write(user_config_path, example_user_config)
        puts "✓ Created #{user_config_path}"
      end

      # Generate example preset
      example_preset_path = File.join(presets_dir, "example.yaml")
      if File.exist?(example_preset_path) && !options[:force]
        puts "⊗ Skipped #{example_preset_path} (already exists, use --force to overwrite)"
      else
        File.write(example_preset_path, example_preset_config)
        puts "✓ Created #{example_preset_path}"
      end

      puts "\n✨ Configuration files initialized!"
      puts "\nNext steps:"
      puts "  1. Edit ~/.config/railstart/config.yaml to customize defaults"
      puts "  2. Create custom presets in ~/.config/railstart/presets/"
      puts "  3. Use with: railstart new my_app --preset example"
    end

    desc "version", "Print Railstart version"
    #
    # @return [void]
    # @example Display version string
    #   Railstart::CLI.start(%w[version])
    def version
      puts "Railstart v#{Railstart::VERSION}"
    end

    PRESET_DIR = File.expand_path("~/.config/railstart/presets")
    GEM_PRESET_DIR = File.expand_path("../../config/presets", __dir__)

    private

    def determine_preset_name
      # Explicit --preset flag takes priority
      return options[:preset] if options[:preset]

      # --default maps to "default" preset
      return "default" if options[:default]

      nil
    end

    def preset_file_for(name)
      # Check user presets first
      user_path = File.join(PRESET_DIR, "#{name}.yaml")
      return user_path if File.exist?(user_path)

      # Fall back to built-in gem presets
      gem_path = File.join(GEM_PRESET_DIR, "#{name}.yaml")
      return gem_path if File.exist?(gem_path)

      # If explicit --preset was used, raise error
      raise Railstart::ConfigLoadError, "Preset '#{name}' not found in #{PRESET_DIR} or gem presets" if options[:preset]

      # For --default with missing preset, return nil (fall back to builtin config)
      nil
    end

    def example_user_config
      <<~YAML
        ---
        # Railstart User Configuration
        # This file overrides built-in defaults for all your Rails projects.
        #
        # Merge behavior: questions and post_actions are merged by 'id'.
        # Override individual fields or add new entries.

        questions:
          # Example: Change database default to PostgreSQL
          - id: database
            choices:
              - name: PostgreSQL
                value: postgresql
                default: true

          # Example: Change CSS default to Tailwind
          - id: css
            choices:
              - name: Tailwind
                value: tailwind
                default: true

        post_actions:
          # Example: Disable bundle install (manage gems manually)
          # - id: bundle_install
          #   enabled: false

          # Example: Add custom post-action
          # - id: setup_linting
          #   name: "Setup RuboCop and StandardRB"
          #   enabled: true
          #   command: "bundle add rubocop rubocop-rails standard --group development"
      YAML
    end

    def example_preset_config
      <<~YAML
        ---
        # Example Preset - Customize this for your use case
        # Use with: railstart new my_app --preset example

        questions:
          - id: database
            choices:
              - name: PostgreSQL
                value: postgresql
                default: true

          - id: css
            choices:
              - name: Tailwind
                value: tailwind
                default: true

          - id: api_only
            default: false

        post_actions:
          - id: init_git
            enabled: true

          - id: bundle_install
            enabled: true
      YAML
    end
  end
end
