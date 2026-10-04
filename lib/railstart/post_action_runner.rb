# frozen_string_literal: true

require_relative "file_writer"
require_relative "template_runner"

module Railstart
  # Executes post-generation actions (commands, Rails templates, file writes)
  # inside a generated application directory.
  #
  # @example Run enabled actions for a generated app
  #   Railstart::PostActionRunner.new(
  #     actions: config["post_actions"], answers: answers,
  #     app_name: "blog", prompt: prompt, assume_yes: false
  #   ).run
  class PostActionRunner
    #
    # @param actions [Array<Hash>] post_action entries from the merged config
    # @param answers [Hash] question answers used by action conditions
    # @param app_name [String] application name for file interpolation and template variables
    # @param confirmer [#call] decides whether a prompted action runs, given the action
    # @param command_runner [#call, nil] executes shell commands; injectable for testing
    def initialize(actions:, answers:, app_name:, confirmer:, command_runner: nil)
      @actions = Array(actions)
      @answers = answers
      @app_name = app_name
      @confirmer = confirmer
      @command_runner = command_runner || ->(command) { system(command) }
    end

    #
    # Run every enabled action whose condition passes. The current working
    # directory must be the generated app root.
    #
    # @return [void]
    def run
      template_runner = nil

      @actions.each do |action|
        template_runner ||= TemplateRunner.new(app_path: Dir.pwd) if template_action?(action)
        process(action, template_runner)
      end
    end

    private

    def process(action, template_runner)
      return unless should_run?(action)
      return unless confirm?(action)

      if template_action?(action)
        run_template(action, template_runner)
      elsif file_action?(action)
        run_file(action)
      else
        run_command(action)
      end
    end

    def confirm?(action)
      return true unless action["prompt"]

      @confirmer.call(action)
    end

    def run_command(action)
      UI.info(action["name"].to_s)
      success = @command_runner.call(action["command"])
      UI.warning("Post-action '#{action["name"]}' failed. Continuing anyway.") unless success
    end

    def run_template(action, template_runner)
      return unless template_runner

      UI.info(action["name"].to_s)
      template_runner.apply(action["source"], variables: template_variables(action))
    rescue TemplateError => e
      UI.warning("Post-action '#{action["name"]}' failed. #{e.message}")
    end

    def run_file(action)
      UI.info(action["name"].to_s)
      writer = FileWriter.new(app_path: Dir.pwd, app_name: @app_name)
      result = writer.write(
        path: action["path"],
        content: action["content"],
        source: action["source"],
        overwrite: action.fetch("overwrite", false)
      )
      if result == :skipped
        UI.warning("Skipped '#{action["path"]}' (already exists)")
      else
        UI.success("Created #{action["path"]}")
      end
    rescue Error, SystemCallError => e
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

    def file_action?(action)
      action["type"].to_s == "file"
    end

    def should_run?(action)
      return false unless action.fetch("enabled", true)

      if_condition = action["if"]
      return true unless if_condition

      answer = @answers[if_condition["question"]]

      if if_condition.key?("equals")
        answer == if_condition["equals"]
      elsif if_condition.key?("includes")
        expected = Array(if_condition["includes"])
        expected.intersect?(Array(answer))
      else
        true
      end
    end
  end
end
