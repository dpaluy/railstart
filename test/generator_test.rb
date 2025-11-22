# frozen_string_literal: true

require "test_helper"

module Railstart
  class GeneratorTest < Minitest::Test
    def setup
      @config = {
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
    end

    def test_default_mode_uses_defaults_without_prompting
      prompt = Minitest::Mock.new
      # Mock only the final confirmation
      prompt.expect :yes?, true, ["Proceed with app generation?"]

      generator = Generator.new(
        "testapp",
        config: @config,
        use_defaults: true,
        prompt: prompt
      )

      generator.stub :system, true do
        Dir.stub :chdir, nil do
          output = capture_io do
            generator.run
          end

          # Verify summary was shown
          assert_match(/Summary/, output[0])
          assert_match(/testapp/, output[0])
          assert_match(/sqlite3/, output[0]) # Default value shown
        end
      end

      # Verify only confirmation was called (no question prompts)
      prompt.verify
    end

    def test_interactive_mode_asks_questions_and_confirms
      # Track which prompts were called
      prompts_called = []

      # Create a fake prompt that tracks calls
      fake_prompt = Object.new
      fake_prompt.define_singleton_method(:select) do |prompt_text, choices, **kwargs|
        prompts_called << { method: :select, prompt: prompt_text, choices: choices, kwargs: kwargs }
        "postgresql" # Return user selection
      end

      fake_prompt.define_singleton_method(:yes?) do |prompt_text, **kwargs|
        prompts_called << { method: :yes?, prompt: prompt_text, kwargs: kwargs }
        prompt_text == "Proceed with app generation?" # Return true for confirmation
      end

      generator = Generator.new(
        "testapp",
        config: @config,
        prompt: fake_prompt
      )

      # Stub system call and Dir.chdir
      generator.stub :system, true do
        Dir.stub :chdir, nil do
          generator.run
        end
      end

      # Verify prompts were called
      assert_equal 3, prompts_called.size, "Expected 3 prompts (select, yes?, confirmation)"

      # Verify database select was called
      database_prompt = prompts_called[0]
      assert_equal :select, database_prompt[:method]
      assert_equal "Which database?", database_prompt[:prompt]

      # Verify api_only yes? was called
      api_prompt = prompts_called[1]
      assert_equal :yes?, api_prompt[:method]
      assert_equal "API only?", api_prompt[:prompt]

      # Verify confirmation was called
      confirm_prompt = prompts_called[2]
      assert_equal :yes?, confirm_prompt[:method]
      assert_equal "Proceed with app generation?", confirm_prompt[:prompt]
    end

    def test_skip_bundle_false_excludes_flag_and_skips_post_action
      config = {
        "questions" => [
          {
            "id" => "skip_bundle",
            "type" => "yes_no",
            "prompt" => "Skip bundle install?",
            "default" => false,
            "rails_flag" => "--skip-bundle"
          }
        ],
        "post_actions" => [
          {
            "id" => "bundle_install",
            "name" => "Install gems",
            "enabled" => true,
            "command" => "bundle install",
            "if" => {
              "question" => "skip_bundle",
              "equals" => true
            }
          }
        ]
      }

      # User answers "No" to skip_bundle (default behavior)
      answers = { "skip_bundle" => false }

      command = CommandBuilder.build("testapp", config, answers)

      # --skip-bundle should NOT be in command (Rails will bundle by default)
      refute_includes command, "--skip-bundle"

      # Post-action should NOT run (condition fails: skip_bundle != true)
      generator = Generator.new("testapp", config: config)
      generator.instance_variable_set(:@answers, answers)

      actions_run = []
      generator.stub :system, lambda { |cmd|
        actions_run << cmd
        true
      } do
        Dir.stub :chdir, nil do
          generator.send(:run_post_actions)
        end
      end

      # bundle install should NOT have run (Rails already did it)
      refute_includes actions_run.join(" "), "bundle install"
    end

    def test_skip_bundle_true_includes_flag_and_runs_post_action
      config = {
        "questions" => [
          {
            "id" => "skip_bundle",
            "type" => "yes_no",
            "prompt" => "Skip bundle install?",
            "default" => false,
            "rails_flag" => "--skip-bundle"
          }
        ],
        "post_actions" => [
          {
            "id" => "bundle_install",
            "name" => "Install gems",
            "enabled" => true,
            "prompt" => "Run bundle install?",
            "default" => true,
            "command" => "bundle install",
            "if" => {
              "question" => "skip_bundle",
              "equals" => true
            }
          }
        ]
      }

      # User answers "Yes" to skip_bundle
      answers = { "skip_bundle" => true }

      command = CommandBuilder.build("testapp", config, answers)

      # --skip-bundle SHOULD be in command
      assert_includes command, "--skip-bundle"

      # Post-action SHOULD run (condition passes: skip_bundle == true)
      # But we need to simulate the prompt confirmation
      fake_prompt = Object.new
      fake_prompt.define_singleton_method(:yes?) { |_prompt, **_kwargs| true }

      generator = Generator.new("testapp", config: config, prompt: fake_prompt)
      generator.instance_variable_set(:@answers, answers)

      actions_run = []
      generator.stub :system, lambda { |cmd|
        actions_run << cmd
        true
      } do
        Dir.stub :chdir, nil do
          generator.send(:run_post_actions)
        end
      end

      # bundle install SHOULD have run (Rails skipped it, we run it)
      assert_includes actions_run.join(" "), "bundle install"
    end
  end
end
