# frozen_string_literal: true

require "test_helper"

module Railstart
  class TemplateRunnerTest < Minitest::Test
    FakeGenerator = Struct.new(:destination_root_accessor, :applied_source, keyword_init: true) do
      def destination_root=(value)
        self.destination_root_accessor = value
      end

      def apply(source)
        self.applied_source = source
      end
    end

    def test_apply_sets_destination_root_variables_and_invokes_generator
      generator = FakeGenerator.new
      factory = ->(_app_path) { generator }

      runner = TemplateRunner.new(app_path: "/tmp/app", generator_factory: factory)
      runner.apply("template.rb", variables: { foo: "bar" })

      assert_equal "/tmp/app", generator.destination_root_accessor
      assert_equal "template.rb", generator.applied_source
      assert_equal "bar", generator.instance_variable_get(:@foo)
    end

    def test_apply_raises_when_source_missing
      runner = TemplateRunner.new(app_path: "/tmp/app", generator_factory: ->(_app_path) { Object.new })
      error = assert_raises(TemplateError) { runner.apply(nil) }
      assert_match(/source must be provided/i, error.message)
    end

    def test_apply_wraps_generator_errors
      generator = Object.new
      def generator.apply(_source)
        raise "boom"
      end

      def generator.destination_root=(_value); end

      runner = TemplateRunner.new(app_path: "/tmp/app", generator_factory: ->(_app_path) { generator })
      error = assert_raises(TemplateError) { runner.apply("template.rb") }
      assert_match(/Failed to apply template/i, error.message)
    end
  end
end
