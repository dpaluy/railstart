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
      # Load, merge, and validate configuration from built-in and user sources.
      #
      # @param builtin_path [String] path to default config YAML shipped with the gem
      # @param user_path [String] optional user override YAML path
      # @return [Hash] deep-copied, merged, validated configuration hash
      # @raise [Railstart::ConfigLoadError] when YAML files are missing or unreadable
      # @raise [Railstart::ConfigValidationError] when validation fails
      # @example
      #   config = Railstart::Config.load
      def load(builtin_path: BUILTIN_CONFIG_PATH, user_path: USER_CONFIG_PATH)
        builtin = read_yaml(builtin_path, required: true)
        user = read_yaml(user_path, required: false)
        merged = merge_config(builtin, user)
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
      rescue KeyError => e
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
        issues = []
        MERGEABLE_COLLECTIONS.each do |collection|
          entries = Array(config[collection])
          issues.concat(validate_collection(collection, entries))
        end
        raise ConfigValidationError.new("Invalid configuration", issues: issues) unless issues.empty?
      end

      def validate_collection(name, entries)
        issues = []
        id_counts = Hash.new(0)

        entries.each_with_index do |entry, index|
          unless entry.is_a?(Hash)
            issues << "#{name} entry at index #{index} must be a Hash"
            next
          end

          id = fetch_id(entry)
          if id.nil? || id.to_s.strip.empty?
            issues << "#{name} entry at index #{index} is missing an id"
          else
            id_counts[id] += 1
          end

          next unless name == "questions"

          type = entry["type"] || entry[:type]
          unless QUESTION_TYPES.include?(type)
            issues << "Question #{id || index} has invalid type #{type.inspect}"
            next
          end

          next unless CHOICE_REQUIRED_TYPES.include?(type)

          choices = entry["choices"] || entry[:choices]
          if !choices.is_a?(Array) || choices.empty?
            issues << "Question #{id || index} (#{type}) must define at least one choice"
          end
        end

        id_counts.each do |id, count|
          issues << "#{name} entry id #{id} is defined #{count} times" if count > 1
        end

        issues
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
