# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1] - 2025-11-23

### Changed
- **Init command**: `railstart init` now copies the complete `config/rails8_defaults.yaml` as `~/.config/railstart/config.yaml` instead of generating a minimal example with only 2 questions. Users now see all available configuration options immediately.

### Fixed
- Improved discoverability of configuration options - users no longer need to guess what can be configured

## [0.4.0] - 2025-11-22

### Added
- CLI `--preset` flag now accepts explicit `.yaml`/`.yml` file paths in addition to preset names.
- **Template post-actions**: New `type: template` post-action type for executing full Rails application templates
- **TemplateRunner**: New `Railstart::TemplateRunner` class wraps Rails' AppGenerator to run templates with proper context
- **Template variables**: Template actions support `variables` hash for injecting custom instance variables into templates
- **Built-in variables**: Templates automatically receive `@app_name` and `@answers` instance variables
- **Template DSL support**: Full access to Rails template DSL (`gem`, `route`, `initializer`, `after_bundle`, etc.)
- **Error handling**: New `Railstart::TemplateError` for template execution failures with proper error wrapping
- **Config validation**: Validation for template post-actions (requires `source`, validates `variables` as Hash)
- **Documentation**: README section explaining template post-actions vs command actions with security guidance

### Changed
- **Post-action processing**: Refactored to support both command and template execution types
- **Directory context**: `run_post_actions` now uses block form of `Dir.chdir` for proper scoping
- **Config validation**: Enhanced `validate_post_action_entry` to handle multiple action types

### Technical
- New file: `lib/railstart/template_runner.rb` (77 lines, full YARD docs)
- New test file: `test/template_runner_test.rb` (comprehensive coverage with mocks)
- Enhanced `lib/railstart/generator.rb` with template execution flow
- Enhanced `lib/railstart/config.rb` with template action validation
- Version bump: 0.3.0 → 0.4.0
- All tests pass (39 runs, 111 assertions, 0 failures)
- RuboCop clean (20 files inspected, no offenses)

## [0.3.0] - 2025-11-22

### Added
- **CSS framework**: Added Sass option to CSS framework choices
- **CSS framework**: Added "None (skip CSS setup)" option for skipping CSS configuration
- **JavaScript bundler**: Added Bun as a JavaScript bundler option (Rails 8 native support)
- **JavaScript bundler**: Added Vite (via vite_rails gem) with automatic post-installation setup
- **JavaScript bundler**: Added "None (skip JavaScript)" option using `--skip-javascript` flag
- **Test framework**: New test framework selection question (Minitest default, RSpec option)
- **Post-action**: RSpec automatic setup (`bundle add rspec-rails` + `rails generate rspec:install`) when selected
- **Post-action**: Vite Rails automatic setup (`bundle add vite_rails` + `bundle exec vite install`) when selected
- **Post-action**: Bundlebun optional setup (`bundle add bundlebun` + `rake bun:install`) for Bun packaged as a gem
- **Preset**: New `vite-bun.yaml` preset for modern frontend with Vite + Bundlebun (use with `--preset vite-bun`)
- **Command builder**: Choice-level `rails_flag` support for SELECT questions
- **Command builder**: Different choices can now have different flags or no flag at all
- **Tests**: Comprehensive test coverage for choice-level rails_flag feature

### Changed
- **JavaScript question**: Renamed prompt from "Which JavaScript bundler?" to "Which JavaScript approach?"
- **Command builder**: SELECT questions now check for choice-level flags before falling back to question-level flags
- **Command builder**: Vite choice doesn't add any rails flag (handled via post-action instead)
- **Config**: JavaScript choices now use choice-level `rails_flag` instead of question-level for flexibility

### Technical
- Enhanced `CommandBuilder.process_select` to support per-choice flag configuration
- Backward compatible with existing configs using question-level flags
- All tests pass (33 runs, 97 assertions, 0 failures)
- Rubocop clean (no offenses)

## [0.2.1] - 2025-11-22

### Fixed
- Thor::UndefinedCommandError raised with incorrect number of arguments (now passes command, nil, and all_commands.keys)

## [0.2.0] - 2025-11-22

### Added
- Three-layer preset system (builtin → user → preset config merging)
- CLI flags: `--preset NAME` and `--default` for preset selection
- Preset resolution: user presets (`~/.config/railstart/presets/`) override built-in gem presets
- Built-in presets: `default.yaml` (PostgreSQL + Tailwind + Importmap) and `api-only.yaml`
- Config overlay schema with id-based merging for questions and post_actions
- New `Railstart::UI` module for enhanced CLI presentation
- ASCII art logo displayed at startup
- Styled welcome box with dynamic Rails version detection
- Boxed configuration summary with syntax highlighting
- Icon-based status messages (success ✓, info ℹ, warning ⚠, error ✗)
- Section headers with visual separators
- `tty-box` dependency for frame rendering

### Changed
- `Config.load` now accepts optional `preset_path` parameter
- Generator modes respect preset overlays for both interactive and non-interactive flows
- Generator always confirms before generation, even in `--default` mode
- Improved TTY::Prompt integration to use hash format for select/multi_select choices
- Welcome message now displays detected Rails version instead of hardcoded "Rails 8"
- Summary display redesigned with bordered box and colored output
- Status messages now use consistent icons and colors throughout
- Generator runs Rails commands outside bundler context using `Bundler.with_unbundled_env`
- Bundle install post-action now disabled by default

### Fixed
- Proper deep merging with id-based array merging for questions and post_actions
- TTY::Prompt select/multi_select displaying duplicate options (switched from array pairs to hash format)
- Default value selection not working correctly (now uses 1-based index as expected by TTY::Prompt)
- Bundle install post-action incorrectly prompting when user explicitly skips bundle install

### Removed
- Plain text summary formatting replaced with styled box display

## [0.1.0] - 2025-11-21

### Added
- Initial release
