# frozen_string_literal: true

require "tty-prompt"
require_relative "ui"
require_relative "template_runner"

module Railstart
  # Orchestrates the interactive Rails app generation flow.
  #
  # Handles configuration loading, prompting, summary display, command execution,
  # and optional post-generation actions while remaining easy to test.
  #
  # @example Run generator with provided config
  #   config = Railstart::Config.load
  #   Railstart::Generator.new("blog", config: config).run
  # @example Run generator non-interactively
  #   Railstart::Generator.new("blog", use_defaults: true).run
  class Generator
    #
    # @param app_name [String, nil] preset app name, prompted if nil
    # @param config [Hash, nil] injected config for testing, defaults to Config.load
    # @param use_defaults [Boolean] skip interactive questions, use config defaults
    # @param prompt [TTY::Prompt] injectable prompt for testing
    def initialize(app_name = nil, config: nil, use_defaults: false, prompt: nil)
      @app_name = app_name
      @config = config || Config.load
      @use_defaults = use_defaults
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

      ask_app_name unless @app_name

      if @use_defaults
        collect_defaults
      else
        ask_interactive_questions
      end

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

    def ask_app_name
      @app_name = @prompt.ask("App name?", default: "my_app") do |q|
        q.validate(/\A[a-z0-9_-]+\z/, "Must be lowercase letters, numbers, underscores, or hyphens")
      end
    end

    def collect_defaults
      Array(@config["questions"]).each do |question|
        next if should_skip_question?(question)

        question_id = question["id"]
        default_value = find_default(question)
        @answers[question_id] = default_value unless default_value.nil?
      end
    end

    def ask_interactive_questions
      Array(@config["questions"]).each do |question|
        handle_question(question)
      end
    end

    def handle_question(question)
      return if should_skip_question?(question)

      @answers[question["id"]] = ask_question(question)
    end

    def should_skip_question?(question)
      depends = question["depends_on"]
      return false unless depends

      dep_question_id = depends["question"]
      dep_value = depends["value"]

      actual_value = @answers[dep_question_id]
      actual_value != dep_value
    end

    def ask_question(question)
      case question["type"]
      when "select"
        ask_select(question)
      when "multi_select"
        ask_multi_select(question)
      when "yes_no"
        ask_yes_no?(question)
      when "input"
        ask_input(question)
      end
    end

    def ask_select(question)
      # Convert to hash format: { 'Display Name' => 'value' }
      choices = question["choices"].each_with_object({}) do |choice, hash|
        hash[choice["name"]] = choice["value"]
      end
      default_val = find_default(question)

      # TTY::Prompt expects 1-based index for default
      default_index = (question["choices"].index { |c| c["value"] == default_val }&.+(1) if default_val)

      @prompt.select(question["prompt"], choices, default: default_index)
    end

    def ask_multi_select(question)
      # Convert to hash format: { 'Display Name' => 'value' }
      choices = question["choices"].each_with_object({}) do |choice, hash|
        hash[choice["name"]] = choice["value"]
      end
      defaults = question["default"] || []

      @prompt.multi_select(question["prompt"], choices, default: defaults)
    end

    def ask_yes_no?(question)
      @prompt.yes?(question["prompt"], default: question.fetch("default", false))
    end

    def ask_input(question)
      @prompt.ask(question["prompt"], default: question["default"])
    end

    def find_default(question)
      # Support both default at question level and default: true on choice
      return question["default"] if question.key?("default")

      Array(question["choices"]).find { |c| c["default"] }&.[]("value")
    end

    def show_summary
      puts
      UI.section("Configuration Summary")
      puts

      summary_lines = ["App name: #{UI.pastel.bright_cyan(@app_name)}"]

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

        summary_lines << "#{label}: #{UI.pastel.bright_white(value_str)}"
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
      @prompt.yes?("Proceed with app generation?")
    end

    def generate_app
      command = CommandBuilder.build(@app_name, @config, @answers)

      UI.info("Running: #{command}")
      puts

      # Run rails command outside of bundler context to use system Rails
      success = if defined?(Bundler)
                  Bundler.with_unbundled_env { system(command) }
                else
                  system(command)
                end

      return if success

      UI.error("Failed to generate Rails app. Check the output above for details.")
      raise Error, "Failed to generate Rails app. Check the output above for details."
    end

    def run_post_actions
      Dir.chdir(@app_name) do
        template_runner = nil

        Array(@config["post_actions"]).each do |action|
          template_runner ||= TemplateRunner.new(app_path: Dir.pwd) if template_action?(action)
          process_post_action(action, template_runner)
        end

        puts
        UI.success("Rails app created successfully at ./#{@app_name}")
      end
    rescue Errno::ENOENT
      UI.warning("Could not change to app directory. Post-actions skipped.")
    end

    def process_post_action(action, template_runner)
      return unless should_run_action?(action)
      return unless confirm_action?(action)

      if template_action?(action)
        run_template_action(action, template_runner)
      else
        run_command_action(action)
      end
    end

    def confirm_action?(action)
      return true unless action["prompt"]

      @prompt.yes?(action["prompt"], default: action.fetch("default", true))
    end

    def run_command_action(action)
      UI.info(action["name"].to_s)
      success = system(action["command"])
      UI.warning("Post-action '#{action["name"]}' failed. Continuing anyway.") unless success
    end

    def run_template_action(action, template_runner)
      return unless template_runner

      UI.info(action["name"].to_s)
      source = action["source"]
      variables = template_variables(action)
      template_runner.apply(source, variables: variables)
    rescue TemplateError => e
      UI.warning("Post-action '#{action["name"]}' failed. #{e.message}")
    end

    def template_variables(action)
      base = { app_name: @app_name, answers: @answers }
      extras = action["variables"].is_a?(Hash) ? action["variables"].transform_keys(&:to_sym) : {}
      base.merge(extras)
    end

    def template_action?(action)
      action["type"].to_s == "template"
    end

    def should_run_action?(action)
      return false unless action.fetch("enabled", true)

      if_condition = action["if"]
      return true unless if_condition

      question_id = if_condition["question"]
      answer = @answers[question_id]

      if if_condition.key?("equals")
        answer == if_condition["equals"]
      elsif if_condition.key?("includes")
        expected = Array(if_condition["includes"])
        actual = Array(answer)
        expected.intersect?(actual)
      else
        true
      end
    end
  end
end
