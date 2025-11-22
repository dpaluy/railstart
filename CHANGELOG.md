# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


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
- CLI error handling improved (Thor::UndefinedCommandError)

### Removed
- Plain text summary formatting replaced with styled box display

## [0.1.0] - 2025-11-21

### Added
- Initial release
