# frozen_string_literal: true

require "test_helper"

class RailstartTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Railstart::VERSION
  end

  def test_gem_requires_successfully
    assert defined?(Railstart::CLI)
    assert defined?(Railstart::Generator)
    assert defined?(Railstart::CommandBuilder)
    assert defined?(Railstart::Config)
  end
end
