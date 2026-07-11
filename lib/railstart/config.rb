# frozen_string_literal: true

require "yaml"
require_relative "errors"

module Railstart
  # Provides loading, merging, and validation of Railstart configuration data.
  #
  # Combines built-in defaults with optional user overrides and exposes helpers
  # for downstream components.
  class Config
    BUILTIN_CONFIG_PATH = File.expand_path("../../config/rails8_defaults.yaml", __dir__)
    USER_CONFIG_PATH = File.expand_path("~/.config/railstart/config.yaml")
    QUESTION_TYPES = %w[select multi_select yes_no input].freeze
    CHOICE_REQUIRED_TYPES = %w[select multi_select].freeze
    MERGEABLE_COLLECTIONS = %w[questions post_actions].freeze

    class << self
      #
      # Load, merge, and validate configuration from built-in, user, and preset sources.
      #
      # @param builtin_path [String] path to default config YAML shipped with the gem
      # @param user_path [String] optional user override YAML path
      # @param preset_path [String] optional preset YAML path (third overlay)
      # @return [Hash] deep-copied, merged, validated configuration hash
      # @raise [Railstart::ConfigLoadError] when YAML files are missing or unreadable
      # @raise [Railstart::ConfigValidationError] when validation fails
      # @example
      #   config = Railstart::Config.load
      # @example With preset
      #   config = Railstart::Config.load(preset_path: "~/.config/railstart/presets/api-only.yaml")
      def load(builtin_path: BUILTIN_CONFIG_PATH, user_path: USER_CONFIG_PATH, preset_path: nil)
        builtin = read_yaml(builtin_path, required: true)
        user = read_yaml(user_path, required: false)
        preset = preset_path ? read_yaml(preset_path, required: false) : {}

        validate_layer_ids!(builtin, user, preset)

        merged = merge_config(builtin, user)
        merged = merge_config(merged, preset) unless preset.empty?
        validate!(merged)
        merged
      end

      #
      # Interpolate `%{value}` placeholders within Rails flags.
      #
      # @param template [String] flag template
      # @param value [Object] value to substitute into the template
      # @return [String] interpolated flag string
      # @raise [Railstart::ConfigError] when placeholder tokens are invalid
      # @example
      #   Railstart::Config.interpolate_flag("--database=%{value}", "postgresql")
      #   # => "--database=postgresql"
      def interpolate_flag(template, value)
        return template if template.nil? || (!template.include?("%{") && !template.include?("%<"))

        format(template, value: value)
      rescue KeyError, ArgumentError => e
        raise ConfigError, "Invalid interpolation token in rails_flag \"#{template}\": #{e.message}"
      end

      private

      def read_yaml(path, required:)
        return {} if path.nil? || path.to_s.empty?

        unless File.exist?(path)
          raise ConfigLoadError, "Missing required config file: #{path}" if required

          return {}
        end

        data = YAML.safe_load_file(path, aliases: true) || {}
        raise ConfigLoadError, "Config file #{path} must define a Hash at the top level" unless data.is_a?(Hash)

        deep_dup(data)
      rescue Errno::EACCES => e
        raise ConfigLoadError, "Cannot read #{path}: #{e.message}"
      rescue Psych::Exception => e
        raise ConfigLoadError, "Failed to parse #{path}: #{e.message}"
      end

      def merge_config(base, override)
        normalized_base = base || {}
        return deep_dup(normalized_base) if override.nil? || override.empty?

        deep_merge_hash(normalized_base, override)
      end

      def deep_merge_hash(base, override)
        return deep_dup(base || {}) if override.nil? || override.empty?

        result = deep_dup(base || {})
        override.each do |key, override_value|
          result[key] = deep_merge_value(key, result[key], override_value)
        end
        result
      end

      def deep_merge_value(key, left, right)
        return deep_dup(left) if right.nil?
        return deep_dup(right) if left.nil?

        if special_array_key?(key)
          merge_id_array(left, right)
        elsif left.is_a?(Hash) && right.is_a?(Hash)
          deep_merge_hash(left, right)
        else
          deep_dup(right)
        end
      end

      def merge_id_array(base, override)
        base_entries = Array(base)
        override_entries = Array(override)

        map = {}
        order = []
        base_without_id = []

        base_entries.each do |entry|
          copy = deep_dup(entry)
          id = fetch_id(copy)
          if id
            order << id unless order.include?(id)
            map[id] = copy
          else
            base_without_id << copy
          end
        end

        override_without_id = []
        override_entries.each do |entry|
          copy = deep_dup(entry)
          id = fetch_id(copy)
          if id
            order << id unless order.include?(id)
            map[id] = merge_entries(map[id], copy)
          else
            override_without_id << copy
          end
        end

        order.map { |id| map[id] } + base_without_id + override_without_id
      end

      def merge_entries(left, right)
        return deep_dup(right) if left.nil?
        return deep_dup(left) if right.nil?

        if left.is_a?(Hash) && right.is_a?(Hash)
          deep_merge_hash(left, right)
        else
          deep_dup(right)
        end
      end

      def fetch_id(entry)
        return unless entry.respond_to?(:[])

        entry["id"] || entry[:id]
      end

      def validate!(config)
        questions = Array(config["questions"])
        post_actions = Array(config["post_actions"])
        issues = validate_questions(questions)
        issues.concat(validate_post_actions(post_actions, questions))
        raise ConfigValidationError.new("Invalid configuration", issues: issues) unless issues.empty?
      end

      def validate_layer_ids!(*layers)
        issues = layers.flat_map do |layer|
          MERGEABLE_COLLECTIONS.flat_map do |collection|
            duplicate_id_issues(collection, Array(layer[collection]))
          end
        end
        raise ConfigValidationError.new("Invalid configuration", issues: issues) unless issues.empty?
      end

      def duplicate_id_issues(collection, entries)
        counts = entries.filter_map { |entry| fetch_id(entry) }.tally
        counts.filter_map do |id, count|
          "#{collection} entry id #{id} is defined #{count} times" if count > 1
        end
      end

      def validate_questions(entries)
        issues = []
        id_counts = Hash.new(0)
        question_positions = entries.each_with_index.filter_map do |entry, index|
          id = fetch_id(entry)
          [id, index] if id
        end.to_h

        entries.each_with_index do |entry, index|
          unless entry.is_a?(Hash)
            issues << "questions entry at index #{index} must be a Hash"
            next
          end

          id = fetch_id(entry)
          if id.nil? || id.to_s.strip.empty?
            issues << "questions entry at index #{index} is missing an id"
          else
            id_counts[id] += 1
          end

          identifier = id || index
          type = value_for(entry, "type")
          unless QUESTION_TYPES.include?(type)
            issues << "Question #{identifier} has invalid type #{type.inspect}"
            next
          end

          prompt = value_for(entry, "prompt")
          issues << "Question #{identifier} is missing a prompt" if prompt.nil? || prompt.to_s.strip.empty?
          issues.concat(validate_question_choices(entry, identifier)) if CHOICE_REQUIRED_TYPES.include?(type)
          issues.concat(validate_question_default(entry, identifier, type))
          issues.concat(validate_flag_source(entry, "Question #{identifier}"))
          issues.concat(validate_depends_on(entry, identifier, index, question_positions))
        end

        id_counts.each do |id, count|
          issues << "questions entry id #{id} is defined #{count} times" if count > 1
        end

        issues
      end

      def validate_post_actions(entries, questions)
        issues = []
        id_counts = Hash.new(0)
        question_ids = questions.filter_map { |entry| fetch_id(entry) }

        entries.each_with_index do |entry, index|
          unless entry.is_a?(Hash)
            issues << "post_actions entry at index #{index} must be a Hash"
            next
          end

          id = fetch_id(entry)
          if id.nil? || id.to_s.strip.empty?
            issues << "post_actions entry at index #{index} is missing an id"
          else
            id_counts[id] += 1
          end

          identifier = id || index
          issues.concat(validate_post_action_entry(entry, identifier))
          issues.concat(validate_post_action_condition(entry, identifier, question_ids))
        end

        id_counts.each do |id, count|
          issues << "post_actions entry id #{id} is defined #{count} times" if count > 1
        end
        issues
      end

      def validate_question_choices(entry, question_id)
        issues = []
        choices = value_for(entry, "choices")

        if !choices.is_a?(Array) || choices.empty?
          issues << "Question #{question_id} (#{entry["type"]}) must define at least one choice"
          return issues
        end

        choices.each_with_index do |choice, cidx|
          unless choice.is_a?(Hash)
            issues << "Question #{question_id} choice at index #{cidx} must be a Hash"
            next
          end
          unless key_present?(choice, "name") && !value_for(choice, "name").to_s.strip.empty?
            issues << "Question #{question_id} choice at index #{cidx} missing 'name'"
          end
          unless key_present?(choice, "value") && !value_for(choice, "value").nil?
            issues << "Question #{question_id} choice at index #{cidx} missing 'value'"
          end
          if key_present?(choice, "default") && ![true, false].include?(value_for(choice, "default"))
            issues << "Question #{question_id} choice at index #{cidx} default must be true or false"
          end
          issues.concat(validate_flag_source(choice, "Question #{question_id} choice at index #{cidx}"))
        end

        issues.concat(duplicate_choice_issues(choices, question_id, "name"))
        issues.concat(duplicate_choice_issues(choices, question_id, "value"))
        default_count = choices.count do |choice|
          choice.is_a?(Hash) && value_for(choice, "default") == true
        end
        if value_for(entry, "type") == "select" && default_count > 1
          issues << "Question #{question_id} must define at most one default choice"
        end
        issues
      end

      def duplicate_choice_issues(choices, question_id, field)
        values = choices.filter_map do |choice|
          value_for(choice, field) if choice.is_a?(Hash) && key_present?(choice, field)
        end
        values.tally.filter_map do |value, count|
          "Question #{question_id} has duplicate choice #{field} #{value.inspect}" if count > 1
        end
      end

      def validate_question_default(entry, identifier, type)
        return [] unless key_present?(entry, "default")

        default = value_for(entry, "default")
        choices = Array(value_for(entry, "choices"))
        choice_values = choices.filter_map do |choice|
          value_for(choice, "value") if choice.is_a?(Hash) && key_present?(choice, "value")
        end

        case type
        when "select"
          return [] if choice_values.include?(default)

          ["Question #{identifier} default #{default.inspect} is not a defined choice"]
        when "multi_select"
          return ["Question #{identifier} default must be an Array"] unless default.is_a?(Array)

          unknown = default - choice_values
          unknown.empty? ? [] : ["Question #{identifier} has unknown default choice #{unknown.first.inspect}"]
        when "yes_no"
          [true, false].include?(default) ? [] : ["Question #{identifier} default must be true or false"]
        else
          []
        end
      end

      def validate_flag_source(source, label)
        issues = []
        if key_present?(source, "rails_flag")
          flag = value_for(source, "rails_flag")
          if flag.is_a?(String)
            issues.concat(interpolation_issues(flag, label, "rails_flag"))
          else
            issues << "#{label} rails_flag must be a String"
          end
        end

        if key_present?(source, "rails_flags")
          flags = value_for(source, "rails_flags")
          if !flags.is_a?(Array) || flags.any? { |flag| !flag.is_a?(String) }
            issues << "#{label} rails_flags must be an Array of Strings"
          else
            flags.each { |flag| issues.concat(interpolation_issues(flag, label, "rails_flags")) }
          end
        end
        issues
      end

      def interpolation_issues(flag, label, field)
        interpolate_flag(flag, "value")
        []
      rescue ConfigError => e
        ["#{label} has invalid #{field} interpolation: #{e.message}"]
      end

      def validate_depends_on(entry, identifier, index, question_positions)
        return [] unless key_present?(entry, "depends_on")

        condition = value_for(entry, "depends_on")
        return ["Question #{identifier} depends_on must be a Hash"] unless condition.is_a?(Hash)

        issues = unsupported_key_issues(condition, %w[question value], "Question #{identifier} depends_on")
        reference = value_for(condition, "question")
        issues << "Question #{identifier} depends_on is missing question" if reference.to_s.strip.empty?
        issues << "Question #{identifier} depends_on is missing value" unless key_present?(condition, "value")
        if !reference.to_s.empty? && !question_positions.key?(reference)
          issues << "Question #{identifier} references unknown question '#{reference}'"
        elsif question_positions[reference] && question_positions[reference] >= index
          issues << "Question #{identifier} depends_on must reference an earlier question"
        end
        issues
      end

      def validate_post_action_entry(entry, identifier)
        action_type = (value_for(entry, "type") || "command").to_s
        enabled = entry.fetch("enabled", entry.fetch(:enabled, true))

        case action_type
        when "command"
          command = value_for(entry, "command")
          if enabled && (command.nil? || command.to_s.strip.empty?)
            ["Post-action #{identifier} is enabled but missing a command"]
          else
            []
          end
        when "template"
          issues = []
          source = value_for(entry, "source")
          if enabled && (source.nil? || source.to_s.strip.empty?)
            issues << "Post-action #{identifier} is a template but missing a source"
          end

          variables = value_for(entry, "variables")
          issues << "Post-action #{identifier} template variables must be a Hash" if variables && !variables.is_a?(Hash)
          if variables.is_a?(Hash)
            variables.each_key do |key|
              unless /\A[a-zA-Z_]\w*\z/.match?(key.to_s)
                issues << "Post-action #{identifier} has invalid template variable name #{key.inspect}"
              end
            end
          end
          issues
        else
          ["Post-action #{identifier} has unsupported type '#{action_type}'"]
        end
      end

      def validate_post_action_condition(entry, identifier, question_ids)
        return [] unless key_present?(entry, "if")

        condition = value_for(entry, "if")
        return ["Post-action #{identifier} condition must be a Hash"] unless condition.is_a?(Hash)

        issues = unsupported_key_issues(condition, %w[question equals includes], "Post-action #{identifier} condition")
        reference = value_for(condition, "question")
        issues << "Post-action #{identifier} condition is missing question" if reference.to_s.strip.empty?
        if !reference.to_s.empty? && !question_ids.include?(reference)
          issues << "Post-action #{identifier} references unknown question '#{reference}'"
        end

        operators = %w[equals includes].select { |key| key_present?(condition, key) }
        unless operators.one?
          issues << "Post-action #{identifier} condition must define exactly one of equals or includes"
        end
        if key_present?(condition, "includes") && !value_for(condition, "includes").is_a?(Array)
          issues << "Post-action #{identifier} condition includes must be an Array"
        end
        issues
      end

      def unsupported_key_issues(hash, allowed, label)
        unsupported = hash.keys.map(&:to_s) - allowed
        unsupported.map { |key| "#{label} has unsupported key '#{key}'" }
      end

      def key_present?(hash, key)
        hash.key?(key) || hash.key?(key.to_sym)
      end

      def value_for(hash, key)
        return hash[key] if hash.key?(key)

        hash[key.to_sym]
      end

      def deep_dup(value)
        case value
        when Hash
          value.transform_values { |v| deep_dup(v) }
        when Array
          value.map { |v| deep_dup(v) }
        else
          value
        end
      end

      def special_array_key?(key)
        key && MERGEABLE_COLLECTIONS.include?(key.to_s)
      end
    end
  end
end
