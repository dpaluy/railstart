# frozen_string_literal: true

require "test_helper"

module Railstart
  class CommandBuilderTest < Minitest::Test
    def setup
      @config = { "questions" => [] }
    end

    def test_single_select_question_flag
      add_question(
        "database",
        "select",
        "rails_flag" => "--database=%<value>s"
      )
      command = CommandBuilder.build("my_app", @config, "database" => "postgres")
      assert_includes command, "--database=postgres"
    end

    def test_yes_no_true_includes_flag
      add_question(
        "api",
        "yes_no",
        "rails_flag" => "--api"
      )
      command = CommandBuilder.build("api_app", @config, "api" => true)
      assert_includes command, "--api"
    end

    def test_yes_no_false_excludes_flag
      add_question(
        "api",
        "yes_no",
        "rails_flag" => "--api"
      )
      command = CommandBuilder.build("api_app", @config, "api" => false)
      refute_includes command, "--api"
    end

    def test_input_question_with_value
      add_question(
        "app_port",
        "input",
        "rails_flag" => "--port=%<value>s"
      )
      command = CommandBuilder.build("app", @config, "app_port" => "4000")
      assert_includes command, "--port=4000"
    end

    def test_multi_select_multiple_flags
      add_question(
        "skips",
        "multi_select",
        "choices" => [
          { "name" => "Mailer", "value" => "mailer", "rails_flag" => "--skip-action-mailer" },
          { "name" => "Job", "value" => "job", "rails_flag" => "--skip-active-job" }
        ]
      )
      command = CommandBuilder.build("app", @config, "skips" => %w[mailer job])
      assert_includes command, "--skip-action-mailer"
      assert_includes command, "--skip-active-job"
    end

    def test_multi_select_no_selection_adds_no_flags
      add_question(
        "skips",
        "multi_select",
        "choices" => [
          { "name" => "Mailer", "value" => "mailer", "rails_flag" => "--skip-action-mailer" }
        ]
      )
      command = CommandBuilder.build("app", @config, "skips" => [])
      refute_includes command, "--skip-action-mailer"
    end

    def test_missing_answer_skips_flag
      add_question(
        "database",
        "select",
        "rails_flag" => "--database=%<value>s"
      )
      command = CommandBuilder.build("app", @config, {})
      refute_includes command, "--database"
    end

    def test_combined_question_types_preserve_order
      add_question("database", "select", "rails_flag" => "--database=%<value>s")
      add_question("api", "yes_no", "rails_flag" => "--api")
      add_question(
        "skips",
        "multi_select",
        "choices" => [
          { "name" => "Mailer", "value" => "mailer", "rails_flag" => "--skip-action-mailer" }
        ]
      )
      answers = { "database" => "postgres", "api" => true, "skips" => ["mailer"] }
      command = CommandBuilder.build("app", @config, answers)
      assert_match(/rails new app --database=postgres --api --skip-action-mailer/, command)
    end

    def test_flag_interpolation_occurs_in_output
      add_question("database", "select", "rails_flag" => "--database=%<value>s")
      command = CommandBuilder.build("app", @config, "database" => "mysql")
      assert_includes command, "--database=mysql"
    end

    private

    def add_question(id, type, extra = {})
      @config["questions"] << { "id" => id, "type" => type }.merge(extra)
    end
  end
end
