# Railstart

[![Gem Version](https://img.shields.io/gem/v/railstart)](https://rubygems.org/gems/railstart)
[![Documentation](https://img.shields.io/badge/docs-rubydoc.info-blue.svg)](https://rubydoc.info/gems/railstart)
[![CI](https://github.com/dpaluy/railstart/actions/workflows/ci.yml/badge.svg)](https://github.com/dpaluy/railstart/actions/workflows/ci.yml)

Interactive CLI wizard for generating Rails 8 applications with customizable configuration and smart defaults.

Think of it as `rails new` with an opinion and a friendly interactive experience.

## Installation

```bash
gem install railstart
```

## Usage

### Quick Start

```bash
# Generate config files (optional, for customization)
railstart init

# Generate a new Rails app
railstart new my_app

# Or run without arguments for help
railstart
```

This launches an interactive wizard that guides you through Rails app setup:

```
Which database?
1) SQLite (default)
2) PostgreSQL
3) MySQL
> 2

Which CSS framework?
1) Tailwind (default)
2) Bootstrap
3) Bulma
4) PostCSS
5) None
> 1

Which JavaScript bundler?
1) Importmap (default)
2) esbuild
3) Webpack
4) Rollup
> 1

Skip any features?
(space to select, enter when done)
‣ ⓞ Action Mailer
  ⓞ Action Mailbox
  ⓞ Action Text
  ...

Generate API-only app?
> No

... (more questions) ...

Summary
════════════════════════════════════════
App name: my_app
Database: postgresql
CSS: tailwind
JavaScript: importmap
Skipped: (none)
API: No
════════════════════════════════════════

Proceed with app generation? Yes

Running: rails new my_app --database=postgresql --css=tailwind ...

Creating Rails app...
✨ Rails app created successfully at ./my_app
```

### Use Presets

Presets are configuration overlays that let you define different defaults and even different questions/post-actions for specific use cases.

**Important:** When you use `--default` without `--preset`, Railstart automatically applies the `default` preset (from `~/.config/railstart/presets/default.yaml` or the gem's built-in version). This means defaults may differ from the base `rails8_defaults.yaml` config.

**Modes:**
- **Interactive** (default): prompts for each question from the config schema
- **With --default**: skips questions, loads "default" preset, shows summary and confirms
- **With --preset**: loads specified preset as config overlay (can be interactive or with --default)

```bash
# Interactive mode (builtin defaults)
railstart new my_app

# Non-interactive with "default" preset (asks no questions, shows summary + confirms)
# Note: --default automatically loads the "default" preset (user or gem)
railstart new my_app --default

# Interactive with custom preset
railstart new my_app --preset api-only

# Non-interactive with custom preset
railstart new my_app --preset api-only --default
```

**Create custom presets** at `~/.config/railstart/presets/my-preset.yaml`:

Presets use the same YAML schema as config files - they can override question defaults, change choices, add new questions, or modify post-actions:

```yaml
# ~/.config/railstart/presets/api-only.yaml
# Presets merge on top of user config (and built-in config)
questions:
  - id: database
    choices:
      - name: PostgreSQL
        value: postgresql
        default: true  # Different default for this preset

  - id: api_only
    default: true  # Override default to true for API preset

post_actions:
  - id: init_git
    enabled: false  # Disable git init for this preset
```

Then use it:

```bash
# Interactive with api-only config
railstart new my_app --preset api-only

# Non-interactive with api-only config
railstart new my_app --preset api-only --default
```

## Creating Custom Presets

Presets are powerful tools for defining opinionated Rails configurations for specific stacks or team standards. For comprehensive guidance on creating presets, see **[Creating Presets Guide](docs/railstart-preset-builder/SKILL.md)**.

### Quick Preset Creation

Create a new preset file in `config/presets/{name}.yaml`:

```yaml
---
# My Team Preset - PostgreSQL + RSpec + Vite

questions:
  - id: database
    choices:
      - name: PostgreSQL
        value: postgresql
        default: true

  - id: javascript
    choices:
      - name: Vite (via vite_rails gem)
        value: vite
        default: true

  - id: test_framework
    choices:
      - name: RSpec
        value: rspec
        default: true

post_actions:
  - id: setup_vite
    enabled: true

  - id: setup_rspec
    enabled: true
```

Then use it:

```bash
# Interactive mode - prompts for each question
railstart new myapp --preset my-team

# Non-interactive mode - uses all preset defaults
railstart new myapp --preset my-team --default
```

### Built-in Presets

Railstart includes several ready-to-use presets:

- **`default`** - PostgreSQL + Tailwind + Importmap (sensible defaults)
- **`api-only`** - Minimal Rails for JSON APIs (no views, no frontend)
- **`vite-bun`** - Modern SPA with Vite + Bundlebun

### Learn More

For detailed documentation including:
- Available questions and post-actions
- ID-based merging system
- Step-by-step workflow
- Real-world examples
- Best practices and troubleshooting

See the comprehensive **[Creating Presets Guide](docs/railstart-preset-builder/SKILL.md)**.

## Configuration

### Initialize Configuration Files

The easiest way to get started with custom configuration is to generate template files:

```bash
railstart init
```

This creates:
- `~/.config/railstart/config.yaml` - Complete configuration template (copy of rails8_defaults.yaml with all available options)
- `~/.config/railstart/presets/` - Directory for your presets
- `~/.config/railstart/presets/example.yaml` - Example preset to get started

The generated `config.yaml` shows all available questions, choices, flags, and post-actions. You can delete or comment out sections you don't want to customize, and modify the defaults for sections you do want to change.

### Built-in Defaults

Railstart ships with sensible Rails 8 defaults defined in `config/rails8_defaults.yaml`. These drive the interactive questions and their defaults.

### Customize for Your Team

You can create `~/.config/railstart/config.yaml` manually or use `railstart init` to generate a complete template file. The template includes all available options, so you can simply modify the defaults you want to change:

```yaml
# After running `railstart init`, your config.yaml will contain all options.
# Simply modify the defaults you want to change:

questions:
  - id: database
    choices:
      - name: PostgreSQL (recommended)
        value: postgresql
        default: true  # Changed from SQLite to PostgreSQL

  # ... other questions with their full configuration ...

post_actions:
  - id: bundle_install
    enabled: false  # Disabled - your team manages gems differently

  - id: setup_auth
    name: "Setup authentication"
    enabled: true
    command: "bundle exec rails generate devise:install"  # New custom action
```

**Merge behavior:**

- User config (at `~/.config/railstart/config.yaml`) overrides built-in config
- By `id`: questions and post-actions are merged by their unique `id`
- If you override a question's `choices`, the entire choice list is replaced
- New questions/actions are appended in order

### Configuration Schema

#### Questions

```yaml
questions:
  - id: database                    # unique identifier
    type: select|multi_select|yes_no|input
    prompt: "User-facing question"
    help: "Optional inline help text"
    default: value_or_true_or_false
    
    # For select/multi_select
    choices:
      - name: "Display name"
        value: "internal_value"
        default: true              # at most one per select
        rails_flag: "--flag=%{value}"
    
    # For yes_no/input
    rails_flag: "--flag"            # or --flag=%{value}
    
    # Optional: only ask if condition is met
    depends_on:
      question: other_question_id
      value: expected_value
```

**Question types:**

- `select` - Single choice; returns scalar value
- `multi_select` - Multiple choices; returns array
- `yes_no` - Boolean; returns true/false
- `input` - Free text; returns string

#### Post-actions

```yaml
post_actions:
  - id: my_action                   # unique identifier
    name: "Human readable name"
    enabled: true                   # can be disabled
    command: "shell command to run"
    
    # Optional: prompt user before running
    prompt: "Run this action?"
    default: true
    
    # Optional: only run if condition is met
    if:
      question: question_id
      equals: value                 # or includes: [array, values]
```

#### Template Post-Actions

Post-actions can now execute full Rails application templates (including [RailsBytes scripts](https://railsbytes.com)) instead of plain shell commands.

```yaml
post_actions:
  - id: apply_tailwind_dash
    name: "Apply Tailwind dashboard template"
    type: template
    enabled: false             # keep disabled unless you trust the source
    prompt: "Run the sample template?"
    source: "https://railsbytes.com/script/zAasQK"
    variables:
      app_label: "internal-tools"  # optional instance variables available inside template
```

Key differences from `command` actions:

- Set `type: template` and provide a `source` (local path or URL). Railstart streams that template into Rails' own `apply` helper, so all standard DSL commands (`gem`, `route`, `after_bundle`, etc.) are available.
- `variables` is optional; when present, its keys become instance variables accessible from the template (e.g., `@app_label`). Railstart always exposes `@app_name` and `@answers` for convenience.
- Template actions still honor `prompt`, `default`, and `if` just like command actions. Keep remote templates disabled by default unless you explicitly trust them.

## Development

### Setup

```bash
# Install dependencies
bundle install

# Or use the setup script
bin/setup
```

### Testing the CLI

```bash
# Test the executable during development
bundle exec exe/railstart new my_app
bundle exec exe/railstart new my_app --default

# Interactive console for experimenting
bin/console
# Then in IRB:
# Railstart::CLI.start(["new", "my_app"])

# Install locally to test as a real gem
gem build railstart.gemspec
gem install railstart-[version].gem
railstart new my_app
```

### Running Tests

```bash
# Run tests
bundle exec rake test

# Lint code
bundle exec rubocop

# Lint and auto-fix
bundle exec rubocop -a

# Full check
bundle exec rake test && bundle exec rubocop
```

## Architecture

### Three-Layer Configuration System

Railstart merges configuration from three sources (in order):

1. **Built-in config**: `config/rails8_defaults.yaml` (shipped with gem)
2. **User config**: `~/.config/railstart/config.yaml` (optional global overrides)
3. **Preset** (optional): `~/.config/railstart/presets/NAME.yaml` (per-run overlay)

Each layer can:
- Override question defaults
- Replace choice lists entirely (by question ID)
- Add new questions
- Add/modify post-actions
- Enable/disable post-actions

Merging is by `id` for both `questions` and `post_actions`, allowing surgical overrides without duplicating entire configs.

### Core Components

- **Generator** (`lib/railstart/generator.rb`) - Orchestrates interactive flow
- **Command Builder** (`lib/railstart/command_builder.rb`) - Translates answers to `rails new` flags
- **CLI** (`lib/railstart/cli.rb`) - Thor command interface with `--preset` option

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dpaluy/railstart.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
