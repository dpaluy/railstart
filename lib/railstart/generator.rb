# frozen_string_literal: true

require "tty-prompt"
require_relative "ui"
require_relative "question_asker"
require_relative "post_action_runner"

module Railstart
  # Orchestrates the Rails app generation flow: welcome screen, app name,
  # questions, summary, `rails new`, and post-actions.
  #
  # Question answering lives in QuestionAsker, post-action execution in
  # PostActionRunner; this class only sequences the steps.
  #
  # @example Run generator with provided config
  #   config = Railstart::Config.load
  #   Railstart::Generator.new("blog", config: config).run
  # @example Run generator non-interactively
  #   Railstart::Generator.new("blog", use_defaults: true).run
  class Generator
    APP_NAME_PATTERN = /\A[a-z0-9_-]+\z/
    APP_NAME_ERROR = "Must be lowercase letters, numbers, underscores, or hyphens"

    #
    # @param app_name [String, nil] preset app name, prompted if nil
    # @param config [Hash, nil] injected config for testing, defaults to Config.load
    # @param use_defaults [Boolean] skip interactive questions, use config defaults
    # @param assume_yes [Boolean] fully headless mode, implies defaults and bypasses confirmations
    # @param prompt [TTY::Prompt] injectable prompt for testing
    def initialize(app_name = nil, config: nil, use_defaults: false, assume_yes: false, prompt: nil)
      @app_name = app_name
      @config = config || Config.load
      @assume_yes = assume_yes
      @use_defaults = use_defaults || @assume_yes
      @prompt = prompt || TTY::Prompt.new
      @answers = {}
    end

    #
    # Run the complete generation flow, prompting the user and invoking Rails.
    #
    # Mode selection:
    #   - use_defaults: false (default) → interactive wizard
    #   - use_defaults: true → collect config defaults, show summary, confirm, run
    #
    # @return [void]
    # @raise [Railstart::ConfigError, Railstart::ConfigValidationError] when configuration is invalid
    # @example Run interactively
    #   Railstart::Generator.new("blog").run
    # @example Run with defaults (noninteractive questions)
    #   Railstart::Generator.new("blog", use_defaults: true).run
    def run
      show_welcome_screen unless @use_defaults

      resolve_app_name
      @answers = collect_answers

      show_summary
      return unless confirm_proceed?

      generate_app
      run_post_actions
    end

    private

    def show_welcome_screen
      UI.show_logo
      UI.show_welcome
    end

    def resolve_app_name
      if @app_name.nil?
        raise Error, "APP_NAME is required when running in --yes mode" if @assume_yes

        ask_app_name
      end
      validate_app_name!
    end

    def ask_app_name
      @app_name = @prompt.ask("App name?", default: "my_app") do |q|
        q.validate(APP_NAME_PATTERN, APP_NAME_ERROR)
      end
    end

    def validate_app_name!
      return if @app_name.to_s.match?(APP_NAME_PATTERN)

      raise Error, "Invalid app name '#{@app_name}': #{APP_NAME_ERROR}"
    end

    def collect_answers
      asker = QuestionAsker.new(questions: @config["questions"], prompt: @prompt)
      @use_defaults ? asker.collect_defaults : asker.ask_all
    end

    def show_summary
      puts
      UI.section("Configuration Summary")
      puts

      summary_lines = ["App name: #{UI.pastel.cyan(@app_name)}"]

      Array(@config["questions"]).each do |question|
        question_id = question["id"]
        next unless @answers.key?(question_id)

        answer = @answers[question_id]
        label = question["prompt"].delete_suffix("?").delete_suffix(":").strip

        value_str = case answer
                    when Array
                      answer.empty? ? "none" : answer.join(", ")
                    when false
                      "No"
                    when true
                      "Yes"
                    else
                      answer.to_s
                    end

        summary_lines << "#{label}: #{UI.pastel.green(value_str)}"
      end

      box = TTY::Box.frame(
        width: 60,
        padding: [0, 2],
        border: :light,
        style: {
          border: { fg: :bright_black }
        }
      ) { summary_lines.join("\n") }

      puts box
      puts
    end

    def confirm_proceed?
      return true if @assume_yes

      @prompt.yes?("Proceed with app generation?")
    end

    def confirm_action?(action)
      return action.fetch("default", true) if @assume_yes

      @prompt.yes?(action["prompt"], default: action.fetch("default", true))
    end

    def generate_app
      arguments = CommandBuilder.arguments(@app_name, @config, @answers)
      command = CommandBuilder.build(@app_name, @config, @answers)

      UI.info("Running: #{command}")
      puts

      # Run rails command outside of bundler context to use system Rails
      success = if defined?(Bundler)
                  Bundler.with_unbundled_env { system(*arguments) }
                else
                  system(*arguments)
                end

      return if success

      UI.error("Failed to generate Rails app. Check the output above for details.")
      raise Error, "Failed to generate Rails app. Check the output above for details."
    end

    def run_post_actions
      Dir.chdir(@app_name) do
        PostActionRunner.new(
          actions: @config["post_actions"],
          answers: @answers,
          app_name: @app_name,
          confirmer: ->(action) { confirm_action?(action) },
          command_runner: ->(command) { system(command) }
        ).run

        puts
        UI.success("Rails app created successfully at ./#{@app_name}")
      end
    rescue Errno::ENOENT
      UI.warning("Could not change to app directory. Post-actions skipped.")
    end
  end
end
