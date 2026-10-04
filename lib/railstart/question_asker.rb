# frozen_string_literal: true

module Railstart
  # Answers configuration questions, either by collecting their defaults
  # (non-interactive) or by prompting the user via TTY::Prompt.
  #
  # @example Collect defaults without prompting
  #   Railstart::QuestionAsker.new(questions: config["questions"], prompt: prompt).collect_defaults
  # @example Ask every question interactively
  #   Railstart::QuestionAsker.new(questions: config["questions"], prompt: prompt).ask_all
  class QuestionAsker
    #
    # @param questions [Array<Hash>] question entries from the merged config
    # @param prompt [TTY::Prompt] prompt used for interactive questions
    def initialize(questions:, prompt:)
      @questions = Array(questions)
      @prompt = prompt
    end

    #
    # Build an answers hash from question defaults, skipping conditional
    # questions whose dependency is not met.
    #
    # @return [Hash] question id => default value
    def collect_defaults
      answers = {}
      @questions.each do |question|
        next if skip_question?(question, answers)

        default_value = find_default(question)
        answers[question["id"]] = default_value unless default_value.nil?
      end
      answers
    end

    #
    # Prompt for every question, respecting depends_on conditions.
    #
    # @return [Hash] question id => answer
    def ask_all
      answers = {}
      @questions.each do |question|
        next if skip_question?(question, answers)

        answers[question["id"]] = ask_question(question)
      end
      answers
    end

    private

    def skip_question?(question, answers)
      depends = question["depends_on"]
      return false unless depends

      answers[depends["question"]] != depends["value"]
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
      choices = question["choices"].to_h { |choice| [choice["name"], choice["value"]] }
      default_val = find_default(question)

      # TTY::Prompt expects 1-based index for default
      default_index = (question["choices"].index { |c| c["value"] == default_val }&.+(1) if default_val)

      @prompt.select(question["prompt"], choices, default: default_index)
    end

    def ask_multi_select(question)
      # Convert to hash format: { 'Display Name' => 'value' }
      choices = question["choices"].to_h { |choice| [choice["name"], choice["value"]] }

      # Transform value-based defaults to name-based defaults for TTY::Prompt
      # Config uses stable values (e.g., "action_mailer"), TTY::Prompt needs display names
      value_defaults = question["default"] || []
      name_defaults = value_defaults.map do |value|
        choice = question["choices"].find { |c| c["value"] == value }
        choice ? choice["name"] : nil
      end.compact

      @prompt.multi_select(question["prompt"], choices, default: name_defaults)
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
  end
end
