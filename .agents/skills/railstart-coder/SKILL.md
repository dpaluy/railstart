---
name: railstart-coder
description: |
  Use the railstart gem to generate Rails 8 applications, create presets, customize configuration, and extend the gem.
  Covers CLI usage, preset creation, YAML config structure, post-actions, template actions, and development workflow.
  Use when: generating Rails apps, creating team presets, customizing railstart config, contributing to the gem.
---

# Railstart Coder

## CLI Commands

### Generate a Rails App

```bash
# Interactive wizard - prompts for each choice
railstart new my_app

# Non-interactive with default preset
railstart new my_app --default

# Interactive with named preset
railstart new my_app --preset api-only

# Non-interactive with named preset
railstart new my_app --preset api-only --default

# Direct preset file path
railstart new my_app --preset ./path/to/preset.yaml
```

### Initialize Config Files

```bash
# Create ~/.config/railstart/ with example config and presets
railstart init

# Overwrite existing files
railstart init --force
```

Creates:
- `~/.config/railstart/config.yaml` - User overrides (copy of rails8_defaults.yaml)
- `~/.config/railstart/presets/` - Preset directory
- `~/.config/railstart/presets/example.yaml` - Example preset

### Check Version

```bash
railstart version
```

## Configuration System

### Three-Layer Merge Order

1. **Built-in** (`config/rails8_defaults.yaml`) - All questions and post-actions
2. **User** (`~/.config/railstart/config.yaml`) - Personal overrides
3. **Preset** (`config/presets/*.yaml` or `~/.config/railstart/presets/*.yaml`) - Per-run overlay

Later layers win. Merging is by `id` for questions and post_actions arrays.

### Question Types

| Type | TTY::Prompt Method | Returns | Example |
|------|-------------------|---------|---------|
| `select` | `select()` | String value | `"postgresql"` |
| `multi_select` | `multi_select()` | Array of values | `["action_mailer", "hotwire"]` |
| `yes_no` | `yes?()` | Boolean | `true` / `false` |
| `input` | `ask()` | String | `"my_app"` |

### Available Questions

| ID | Type | Choices/Default | Rails Flag |
|----|------|----------------|------------|
| `database` | select | sqlite3, postgresql, mysql | `--database=%{value}` |
| `css` | select | tailwind, bootstrap, bulma, postcss, sass, none | `--css=%{value}` |
| `javascript` | select | importmap, bun, esbuild, rollup, webpack, none | Choice-level flags |
| `test_framework` | select | minitest, rspec | RSpec: `--skip-test` |
| `skip_features` | multi_select | action_mailer, action_mailbox, action_text, active_record, active_job, active_storage, action_cable, hotwire | `--skip-{feature}` |
| `api_only` | yes_no | default: false | `--api` |
| `skip_git` | yes_no | default: false | `--skip-git` |
| `skip_docker` | yes_no | default: false | `--skip-docker` |
| `skip_bundle` | yes_no | default: false | `--skip-bundle` |

### Available Post-Actions

| ID | Condition | Command |
|----|-----------|---------|
| `init_git` | `skip_git == false` | `git init && git add . && git commit -m 'Initial commit'` |
| `bundle_install` | `skip_bundle == true` | `bundle install` |
| `setup_rspec` | `test_framework == rspec` | `bundle add rspec-rails ... && rails generate rspec:install` |

## Creating Presets

### Preset File Location

- **Gem built-in:** `config/presets/{name}.yaml`
- **User custom:** `~/.config/railstart/presets/{name}.yaml`

User presets take priority over gem presets with the same name.

### Preset Structure

```yaml
---
# Preset Name - Brief description

questions:
  - id: database
    choices:
      - name: PostgreSQL
        value: postgresql
        default: true

  - id: css
    choices:
      - name: Tailwind
        value: tailwind
        default: true

  - id: skip_features
    default: []          # Use values, not display names

  - id: api_only
    default: false

post_actions:
  - id: init_git
    enabled: true

  - id: setup_rspec
    enabled: false
```

### Critical Rules

1. **Merge by `id`** - Questions and post-actions match on `id` field
2. **Choices replace entirely** - If you override a question's `choices`, the whole array is replaced
3. **multi_select defaults use values** - Use `action_mailer` not `"Action Mailer"`
4. **One `default: true` per select** - Multiple defaults: last wins
5. **Post-actions need `name` + `command`** when adding new ones

### Template Post-Actions

Post-actions can run Rails application templates instead of shell commands:

```yaml
post_actions:
  - id: apply_template
    name: "Apply custom template"
    type: template
    enabled: true
    source: "https://railsbytes.com/script/zAasQK"  # or local path
    variables:
      app_label: "my-project"  # Available as @app_label in template
```

Template actions always expose `@app_name` and `@answers` automatically.

### Conditional Post-Actions

```yaml
post_actions:
  - id: setup_rspec
    name: "Setup RSpec"
    enabled: true
    if:
      question: test_framework
      equals: rspec
    command: "bundle add rspec-rails ..."

  - id: skip_hotwire_cleanup
    name: "Remove Hotwire references"
    enabled: true
    if:
      question: skip_features
      includes:
        - hotwire
    command: "rm -f app/javascript/controllers/index.js"
```

Conditions support `equals` (exact match) and `includes` (array intersection).

### Prompted Post-Actions

```yaml
post_actions:
  - id: init_git
    name: "Initialize git repository"
    enabled: true
    prompt: "Initialize git and create first commit?"
    default: true
    command: "git init && git add . && git commit -m 'Initial commit'"
```

## Gem Architecture

### Key Classes

| Class | File | Purpose |
|-------|------|---------|
| `Railstart::CLI` | `lib/railstart/cli.rb` | Thor commands (`new`, `init`, `version`) |
| `Railstart::Config` | `lib/railstart/config.rb` | Load, merge, validate YAML configs |
| `Railstart::Generator` | `lib/railstart/generator.rb` | Orchestrate interactive flow |
| `Railstart::CommandBuilder` | `lib/railstart/command_builder.rb` | Translate answers to `rails new` flags |
| `Railstart::TemplateRunner` | `lib/railstart/template_runner.rb` | Execute Rails app templates |
| `Railstart::UI` | `lib/railstart/ui.rb` | ASCII art, colored output, boxes |

### Generator Flow

```
1. show_welcome_screen (unless --default)
2. ask_app_name (if not provided)
3. collect_defaults OR ask_interactive_questions
4. show_summary
5. confirm_proceed?
6. generate_app (builds command via CommandBuilder, runs `rails new`)
7. run_post_actions (chdir into app, execute enabled actions)
```

### Config Merging

- `Config.load` reads builtin + user + preset YAML files
- Arrays (`questions`, `post_actions`) merge by `id` field
- Hash keys deep-merge; scalars overwrite
- Validation runs after merge: checks types, required fields, duplicate IDs

### CommandBuilder

Pure function: `CommandBuilder.build(app_name, config, answers)` returns a command string.

- `select` questions: checks choice-level `rails_flag` first, falls back to question-level
- `multi_select`: iterates selected choices, applies each choice's flag
- `yes_no`/`input`: applies question-level flag with `%{value}` interpolation
- Falsy answers (`false`, `nil`) produce no flags

## Development Workflow

### Run Tests

```bash
bundle exec rake test
```

### Lint

```bash
bundle exec rubocop
bundle exec rubocop -a  # auto-fix
```

### Test CLI Locally

```bash
bundle exec exe/railstart new my_app
bundle exec exe/railstart new my_app --default
bundle exec exe/railstart new my_app --preset api-only
```

### Build Gem

```bash
gem build railstart.gemspec
gem install railstart-*.gem
```

### Testing Conventions

- **Minitest** with assertions (not mocks where possible)
- **Stub `system()`** - Never actually run `rails new` in tests
- **Stub `Dir.chdir()`** - Prevent filesystem side effects
- **Inject TTY::Prompt** - Pass mock prompt to Generator for deterministic answers
- Config tests verify merge correctness and validation errors
- CommandBuilder tests verify flag generation with various inputs

### Adding a New Question

1. Add entry to `config/rails8_defaults.yaml` with unique `id`
2. CommandBuilder handles it automatically via `rails_flag`/`rails_flags`
3. Generator handles it automatically via question `type`
4. Add tests for the new question's flag generation
5. Update presets that should override the new question's default

### Adding a New Post-Action

1. Add entry to `config/rails8_defaults.yaml` under `post_actions`
2. Include `id`, `name`, `enabled`, `command`
3. Add `if` condition if it depends on a question answer
4. Add `prompt` if it should ask the user before running
5. Add `type: template` + `source` for Rails template actions
