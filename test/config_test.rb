# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "yaml"

module Railstart
  class ConfigTest < Minitest::Test
    def test_loads_builtin_config_successfully
      config = Config.load
      refute_empty config["questions"], "Expected default config to define questions"
    end

    def test_missing_user_config_is_treated_as_empty
      Dir.mktmpdir do |dir|
        builtin_path = write_yaml(dir, "builtin.yaml", {})
        config = Config.load(builtin_path: builtin_path, user_path: File.join(dir, "missing.yaml"))
        assert_equal({}, config, "Expected merged config to equal builtin when user file missing")
      end
    end

    def test_merging_questions_by_id_with_overrides_and_additions
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which database?",
              "choices" => [{ "name" => "SQLite", "value" => "sqlite" }],
              "rails_flag" => "--database=%<value>s"
            }
          ]
        }
        user = {
          "questions" => [
            {
              "id" => "database",
              "prompt" => "DB?",
              "choices" => [{ "name" => "Postgres", "value" => "postgres" }]
            },
            {
              "id" => "css",
              "type" => "select",
              "prompt" => "CSS?",
              "choices" => [{ "name" => "Tailwind", "value" => "tailwind" }],
              "rails_flag" => "--css=%<value>s"
            }
          ]
        }
        config = merged_config(dir, builtin: builtin, user: user)
        database_question = config["questions"].find { |q| q["id"] == "database" }
        assert_equal "DB?", database_question["prompt"]
        assert_equal(["Postgres"], database_question["choices"].map { |c| c["name"] })
        css_question = config["questions"].find { |q| q["id"] == "css" }
        refute_nil css_question, "Expected new questions to be appended"
      end
    end

    def test_merging_post_actions_by_id_with_overrides_and_additions
      Dir.mktmpdir do |dir|
        builtin = {
          "post_actions" => [
            {
              "id" => "bundle_install",
              "enabled" => true,
              "command" => "bundle install"
            }
          ]
        }
        user = {
          "post_actions" => [
            {
              "id" => "bundle_install",
              "enabled" => false,
              "command" => "bundle exec bundle install"
            },
            {
              "id" => "custom_action",
              "enabled" => true,
              "command" => "echo done"
            }
          ]
        }
        config = merged_config(dir, builtin: builtin, user: user)
        bundle = config["post_actions"].find { |a| a["id"] == "bundle_install" }
        refute bundle["enabled"], "Expected overrides to apply by id"
        assert_equal "bundle exec bundle install", bundle["command"]
        custom = config["post_actions"].find { |a| a["id"] == "custom_action" }
        refute_nil custom, "Expected user-defined actions to be appended"
      end
    end

    def test_validation_error_for_duplicate_question_ids
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "First?",
              "choices" => [{ "name" => "SQLite", "value" => "sqlite" }],
              "rails_flag" => "--database=%<value>s"
            },
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Second?",
              "choices" => [{ "name" => "Postgres", "value" => "postgres" }],
              "rails_flag" => "--database=%<value>s"
            }
          ]
        }
        assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
      end
    end

    def test_validation_error_for_duplicate_question_ids_in_user_overlay
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [valid_question("database")]
        }
        user = {
          "questions" => [
            { "id" => "database", "prompt" => "First override?" },
            { "id" => "database", "prompt" => "Second override?" }
          ]
        }

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin, user: user) }
        assert_includes error.message, "questions entry id database is defined 2 times"
      end
    end

    def test_validation_error_for_duplicate_post_action_ids_in_preset
      Dir.mktmpdir do |dir|
        builtin = { "questions" => [valid_question("database")] }
        preset = {
          "post_actions" => [
            { "id" => "setup", "enabled" => false },
            { "id" => "setup", "enabled" => false }
          ]
        }
        builtin_path = write_yaml(dir, "builtin.yaml", builtin)
        preset_path = write_yaml(dir, "preset.yaml", preset)

        error = assert_raises(ConfigValidationError) do
          Config.load(builtin_path: builtin_path, user_path: nil, preset_path: preset_path)
        end
        assert_includes error.message, "post_actions entry id setup is defined 2 times"
      end
    end

    def test_validation_error_for_invalid_question_type
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "weird",
              "type" => "slider",
              "prompt" => "??",
              "choices" => []
            }
          ]
        }
        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "invalid type", "Expected invalid type error"
      end
    end

    def test_validation_error_for_missing_choices_on_select
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which?",
              "choices" => []
            }
          ]
        }
        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "must define at least one choice"
      end
    end

    def test_validation_error_for_missing_question_prompt
      Dir.mktmpdir do |dir|
        question = valid_question("database").tap { |entry| entry.delete("prompt") }

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => [question] }) }
        assert_includes error.message, "Question database is missing a prompt"
      end
    end

    def test_validation_error_for_duplicate_choice_names_and_values
      Dir.mktmpdir do |dir|
        question = valid_question("database")
        question["choices"] << { "name" => "SQLite", "value" => "sqlite3" }

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => [question] }) }
        assert_includes error.message, "duplicate choice name"
        assert_includes error.message, "duplicate choice value"
      end
    end

    def test_validation_error_for_multiple_select_choice_defaults
      Dir.mktmpdir do |dir|
        question = valid_question("database")
        question["choices"] << { "name" => "PostgreSQL", "value" => "postgresql", "default" => true }

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => [question] }) }
        assert_includes error.message, "at most one default choice"
      end
    end

    def test_validation_error_when_select_default_is_not_a_choice
      Dir.mktmpdir do |dir|
        question = valid_question("database").merge("default" => "postgresql")

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => [question] }) }
        assert_includes error.message, "default \"postgresql\" is not a defined choice"
      end
    end

    def test_validation_error_when_multi_select_default_has_wrong_type_or_unknown_values
      Dir.mktmpdir do |dir|
        question = valid_multi_select_question.merge("default" => "mailer")
        wrong_type = assert_raises(ConfigValidationError) do
          merged_config(dir, builtin: { "questions" => [question] })
        end
        assert_includes wrong_type.message, "default must be an Array"

        question["default"] = %w[mailer unknown]
        unknown = assert_raises(ConfigValidationError) do
          merged_config(dir, builtin: { "questions" => [question] })
        end
        assert_includes unknown.message, "unknown default choice"
      end
    end

    def test_validation_error_when_yes_no_default_is_not_boolean
      Dir.mktmpdir do |dir|
        question = {
          "id" => "skip_git", "type" => "yes_no", "prompt" => "Skip Git?", "default" => "false"
        }

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => [question] }) }
        assert_includes error.message, "default must be true or false"
      end
    end

    def test_validation_error_for_invalid_rails_flag_shapes_and_interpolation
      Dir.mktmpdir do |dir|
        questions = [
          valid_question("scalar_flag").merge("rails_flag" => ["--database=sqlite3"]),
          valid_question("flag_list").merge("rails_flags" => "--database=sqlite3"),
          valid_question("flag_member").merge("rails_flags" => ["--database=sqlite3", 123]),
          valid_question("unknown_token").merge("rails_flag" => "--database=%<unknown>s"),
          valid_question("wrong_format").merge("rails_flag" => "--database=%<value>d")
        ]

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => questions }) }
        assert_includes error.message, "rails_flag must be a String"
        assert_includes error.message, "rails_flags must be an Array of Strings"
        assert_includes error.message, "invalid rails_flag interpolation"
      end
    end

    def test_validation_error_for_invalid_choice_level_flag
      Dir.mktmpdir do |dir|
        question = valid_question("database")
        question["choices"][0]["rails_flags"] = [false]

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: { "questions" => [question] }) }
        assert_includes error.message, "choice at index 0 rails_flags must be an Array of Strings"
      end
    end

    def test_interpolation_wraps_invalid_format_types
      error = assert_raises(ConfigError) { Config.interpolate_flag("--db=%<value>d", "postgres") }
      assert_includes error.message, "Invalid interpolation token"
    end

    def test_validation_error_for_invalid_depends_on_structure_reference_and_order
      Dir.mktmpdir do |dir|
        invalid_structure = valid_question("css").merge("depends_on" => "database")
        error = assert_raises(ConfigValidationError) do
          merged_config(dir, builtin: { "questions" => [invalid_structure] })
        end
        assert_includes error.message, "depends_on must be a Hash"

        forward_reference = valid_question("css").merge(
          "depends_on" => { "question" => "database", "value" => "sqlite3" }
        )
        error = assert_raises(ConfigValidationError) do
          merged_config(dir, builtin: { "questions" => [forward_reference, valid_question("database")] })
        end
        assert_includes error.message, "must reference an earlier question"

        unknown_reference = valid_question("css").merge(
          "depends_on" => { "question" => "missing", "value" => "sqlite3" }
        )
        error = assert_raises(ConfigValidationError) do
          merged_config(dir, builtin: { "questions" => [valid_question("database"), unknown_reference] })
        end
        assert_includes error.message, "references unknown question 'missing'"
      end
    end

    def test_valid_depends_on_reference_passes
      Dir.mktmpdir do |dir|
        dependent = valid_question("css").merge(
          "depends_on" => { "question" => "database", "value" => "sqlite3" }
        )

        assert merged_config(dir, builtin: { "questions" => [valid_question("database"), dependent] })
      end
    end

    def test_validation_error_for_invalid_post_action_condition
      Dir.mktmpdir do |dir|
        conditions = [
          "database",
          { "question" => "missing", "equals" => "sqlite3" },
          { "question" => "database" },
          { "question" => "database", "equals" => "sqlite3", "includes" => ["sqlite3"] },
          { "question" => "database", "includes" => "sqlite3" }
        ]

        conditions.each do |condition|
          action = { "id" => "setup", "enabled" => false, "if" => condition }
          assert_raises(ConfigValidationError) do
            merged_config(
              dir,
              builtin: { "questions" => [valid_question("database")], "post_actions" => [action] }
            )
          end
        end
      end
    end

    def test_validation_error_for_invalid_template_variable_key
      Dir.mktmpdir do |dir|
        action = {
          "id" => "template",
          "type" => "template",
          "enabled" => true,
          "source" => "template.rb",
          "variables" => { "invalid-name" => "value" }
        }

        error = assert_raises(ConfigValidationError) do
          merged_config(dir, builtin: { "post_actions" => [action] })
        end
        assert_includes error.message, "invalid template variable name"
      end
    end

    def test_validation_error_for_missing_id
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "type" => "yes_no",
              "prompt" => "Skip?",
              "default" => false,
              "rails_flag" => "--skip"
            }
          ]
        }
        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "missing an id"
      end
    end

    def test_template_post_action_validation_passes
      Dir.mktmpdir do |dir|
        builtin = {
          "post_actions" => [
            {
              "id" => "apply_template",
              "type" => "template",
              "source" => "https://example.com/template.rb",
              "enabled" => true
            }
          ]
        }

        assert merged_config(dir, builtin: builtin)
      end
    end

    def test_template_post_action_missing_source_raises
      Dir.mktmpdir do |dir|
        builtin = {
          "post_actions" => [
            {
              "id" => "apply_template",
              "type" => "template",
              "enabled" => true
            }
          ]
        }

        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "missing a source"
      end
    end

    def test_flag_interpolation_and_error_handling
      flag = "--db=%<value>s"
      assert_equal "--db=postgres", Config.interpolate_flag(flag, "postgres")
      invalid_flag = "--db=%<unknown>s"
      assert_raises(ConfigError) { Config.interpolate_flag(invalid_flag, "postgres") }
    end

    def test_validation_error_for_choice_missing_name
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which?",
              "choices" => [
                { "value" => "postgres" } # Missing 'name'
              ]
            }
          ]
        }
        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "missing 'name'"
      end
    end

    def test_validation_error_for_choice_missing_value
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which?",
              "choices" => [
                { "name" => "PostgreSQL" } # Missing 'value'
              ]
            }
          ]
        }
        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "missing 'value'"
      end
    end

    def test_validation_error_for_choice_not_a_hash
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which?",
              "choices" => [
                "postgres" # Should be a Hash
              ]
            }
          ]
        }
        error = assert_raises(ConfigValidationError) { merged_config(dir, builtin: builtin) }
        assert_includes error.message, "must be a Hash"
      end
    end

    def test_deep_copy_behavior
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which database?",
              "choices" => [{ "name" => "SQLite", "value" => "sqlite" }],
              "rails_flag" => "--database=%<value>s"
            }
          ]
        }
        config = merged_config(dir, builtin: builtin)
        config["questions"][0]["prompt"] = "changed"
        fresh = merged_config(dir, builtin: builtin)
        assert_equal "Which database?", fresh["questions"][0]["prompt"], "Mutation should not leak into new loads"
      end
    end

    def test_preset_overlay_merges_on_top_of_user_config
      Dir.mktmpdir do |dir|
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which database?",
              "choices" => [{ "name" => "SQLite", "value" => "sqlite", "default" => true }],
              "rails_flag" => "--database=%<value>s"
            }
          ]
        }
        user = {
          "questions" => [
            {
              "id" => "database",
              "choices" => [{ "name" => "PostgreSQL", "value" => "postgresql", "default" => true }]
            }
          ]
        }
        preset = {
          "questions" => [
            {
              "id" => "database",
              "choices" => [{ "name" => "MySQL", "value" => "mysql", "default" => true }]
            }
          ]
        }

        builtin_path = write_yaml(dir, "builtin.yaml", builtin)
        user_path = write_yaml(dir, "user.yaml", user)
        preset_path = write_yaml(dir, "preset.yaml", preset)

        config = Config.load(builtin_path: builtin_path, user_path: user_path, preset_path: preset_path)

        database_question = config["questions"].find { |q| q["id"] == "database" }
        # Preset should override user config
        assert_equal(["MySQL"], database_question["choices"].map { |c| c["name"] })
      end
    end

    def test_preset_changes_generator_default_behavior
      Dir.mktmpdir do |dir|
        # Builtin config defines database with SQLite default
        builtin = {
          "questions" => [
            {
              "id" => "database",
              "type" => "select",
              "prompt" => "Which database?",
              "choices" => [
                { "name" => "SQLite", "value" => "sqlite3", "default" => true },
                { "name" => "PostgreSQL", "value" => "postgresql" }
              ],
              "rails_flag" => "--database=%<value>s"
            },
            {
              "id" => "api_only",
              "type" => "yes_no",
              "prompt" => "API only?",
              "default" => false,
              "rails_flag" => "--api"
            }
          ],
          "post_actions" => []
        }

        # Preset overrides database to PostgreSQL and api_only to true
        preset = {
          "questions" => [
            {
              "id" => "database",
              "choices" => [
                { "name" => "PostgreSQL", "value" => "postgresql", "default" => true }
              ]
            },
            {
              "id" => "api_only",
              "default" => true
            }
          ]
        }

        builtin_path = write_yaml(dir, "builtin.yaml", builtin)
        preset_path = write_yaml(dir, "preset.yaml", preset)

        # Load config with preset overlay
        config = Config.load(builtin_path: builtin_path, user_path: nil, preset_path: preset_path)

        # Create generator in default mode (use_defaults: true)
        fake_prompt = Object.new
        fake_prompt.define_singleton_method(:yes?) { |_question, **_kwargs| true } # Confirm generation

        generator = Generator.new("testapp", config: config, use_defaults: true, prompt: fake_prompt)

        # Stub system calls
        generator.stub :system, true do
          Dir.stub :chdir, nil do
            generator.run
          end
        end

        # Verify preset changed the collected defaults
        answers = generator.instance_variable_get(:@answers)
        assert_equal "postgresql", answers["database"], "Preset should override database default to PostgreSQL"
        assert_equal true, answers["api_only"], "Preset should override api_only default to true"
      end
    end

    private

    def merged_config(dir, builtin:, user: nil)
      builtin_path = write_yaml(dir, "builtin.yaml", builtin)
      user_path = write_yaml(dir, "user.yaml", user) if user
      Config.load(builtin_path: builtin_path, user_path: user_path)
    end

    def write_yaml(dir, filename, data)
      path = File.join(dir, filename)
      File.write(path, YAML.dump(data))
      path
    end

    def valid_question(id)
      {
        "id" => id,
        "type" => "select",
        "prompt" => "Choose #{id}",
        "choices" => [{ "name" => "SQLite", "value" => "sqlite3", "default" => true }],
        "rails_flag" => "--#{id}=%<value>s"
      }
    end

    def valid_multi_select_question
      {
        "id" => "features",
        "type" => "multi_select",
        "prompt" => "Choose features",
        "choices" => [
          { "name" => "Mailer", "value" => "mailer", "rails_flag" => "--mailer" },
          { "name" => "Storage", "value" => "storage", "rails_flag" => "--storage" }
        ]
      }
    end
  end
end
