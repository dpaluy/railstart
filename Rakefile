# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

begin
  require "yard"
  YARD::Rake::YardocTask.new(:yard) do |t|
    t.files = ["lib/**/*.rb"]
    t.options = ["--output-dir", "doc", "--markup", "markdown"]
  end
rescue LoadError
  # YARD not available
end

task default: :test
