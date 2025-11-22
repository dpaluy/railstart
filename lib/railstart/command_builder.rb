# frozen_string_literal: true

module Railstart
  # Translates configuration and user answers into a `rails new` command string.
  #
  # This class provides deterministic, side-effect-free command construction.
  #
  # @example Build a command from answers
  #   config = { "questions" => [{ "id" => "database", "type" => "select", "rails_flag" => "--database=%{value}" }] }
  #   answers = { "database" => "postgresql" }
  #   Railstart::CommandBuilder.build("blog", config, answers)
  #   # => "rails new blog --database=postgresql"
  class CommandBuilder
    class << self
      #
      # Build a `rails new` command string using config metadata and answers.
      #
      # @param app_name [String] target Rails app name
      # @param config [Hash] merged configuration from {Railstart::Config.load}
      # @param answers [Hash] user answers keyed by question id
      # @return [String] fully assembled CLI command
      # @raise [Railstart::ConfigError] when flag interpolation fails
      # @example
      #   Railstart::CommandBuilder.build("todo", config, answers)
      def build(app_name, config, answers)
        flags = collect_flags(config["questions"], answers)
        "rails new #{app_name} #{flags.join(" ")}".strip
      end

      private

      def collect_flags(questions, answers)
        flags = []
        Array(questions).each do |question|
          answer = answers[question["id"]]
          next unless answer

          process_question_flags(flags, question, answer)
        end
        flags
      end

      def process_question_flags(flags, question, answer)
        case question["type"]
        when "select"
          process_select(flags, question, answer)
        when "yes_no", "input"
          add_flags(flags, question, answer)
        when "multi_select"
          process_multi_select(flags, question, answer)
        end
      end

      def process_select(flags, question, answer)
        # Check if the selected choice has a choice-level rails_flag
        selected_choice = Array(question["choices"]).find { |choice| choice["value"] == answer }

        if selected_choice && (selected_choice["rails_flag"] || selected_choice["rails_flags"])
          # Use choice-level flag
          add_flags(flags, selected_choice, answer)
        elsif question["rails_flag"] || question["rails_flags"]
          # Fall back to question-level flag
          add_flags(flags, question, answer)
        end
        # If neither exists, no flag is added (e.g., for choices that don't need flags)
      end

      def process_multi_select(flags, question, answer)
        Array(question["choices"]).each do |choice|
          next unless Array(answer).include?(choice["value"])

          add_flags(flags, choice, choice["value"])
        end
      end

      def add_flags(flags, source, value)
        flag_list = source["rails_flags"] || [source["rails_flag"]].compact

        flag_list.each do |flag|
          interpolated = Config.interpolate_flag(flag, value)
          flags << interpolated
        end
      end
    end
  end
end
