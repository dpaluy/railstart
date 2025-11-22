# frozen_string_literal: true

require "tty-prompt"

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
      choices = question["choices"].map { |c| [c["name"], c["value"]] }
      default_val = find_default(question)

      # TTY::Prompt expects 1-based index for default, not the value
      default_index = if default_val
                        question["choices"].index { |c| c["value"] == default_val }&.+(1)
                      end

      @prompt.select(question["prompt"], choices, default: default_index)
    end

    def ask_multi_select(question)
      choices = question["choices"].map { |c| [c["name"], c["value"]] }
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
      puts "\n════════════════════════════════════════"
      puts "Summary"
      puts "════════════════════════════════════════"
      puts "App name: #{@app_name}"

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

        puts "#{label}: #{value_str}"
      end
      puts "════════════════════════════════════════\n"
    end

    def confirm_proceed?
      @prompt.yes?("Proceed with app generation?")
    end

    def generate_app
      command = CommandBuilder.build(@app_name, @config, @answers)

      puts "Running: #{command}\n\n"
      success = system(command)

      return if success

      raise Error, "Failed to generate Rails app. Check the output above for details."
    end

    def run_post_actions
      Dir.chdir(@app_name)

      Array(@config["post_actions"]).each { |action| process_post_action(action) }
      puts "\n✨ Rails app created successfully at ./#{@app_name}"
    rescue Errno::ENOENT
      warn "Could not change to app directory. Post-actions skipped."
    end

    def process_post_action(action)
      return unless should_run_action?(action)
      return unless confirm_action?(action)

      execute_action(action)
    end

    def confirm_action?(action)
      return true unless action["prompt"]

      @prompt.yes?(action["prompt"], default: action.fetch("default", true))
    end

    def execute_action(action)
      puts "→ #{action["name"]}"
      success = system(action["command"])
      warn "Warning: Post-action '#{action["name"]}' failed. Continuing anyway." unless success
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
