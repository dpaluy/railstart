# frozen_string_literal: true

require_relative "lib/railstart/version"

Gem::Specification.new do |spec|
  spec.name = "railstart"
  spec.version = Railstart::VERSION
  spec.authors = ["dpaluy"]
  spec.email = ["dpaluy@users.noreply.github.com"]

  spec.summary = "Rails application starter and development utilities"
  spec.description = "Interactive CLI wizard for Rails app generation with customizable config"
  spec.homepage = "https://github.com/dpaluy/railstart"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/railstart"
  spec.metadata["source_code_uri"] = "https://github.com/dpaluy/railstart"
  spec.metadata["changelog_uri"] = "https://github.com/dpaluy/railstart/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/dpaluy/railstart/issues"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.add_dependency "thor"
  spec.add_dependency "tty-prompt"
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = Dir["README.md", "CHANGELOG.md", "LICENSE.txt"]
end
