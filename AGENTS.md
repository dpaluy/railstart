# Railstart Gem - Agent Guidance

## Project Snapshot

**Type:** Single Ruby gem (interactive Rails application starter)

**Tech Stack:** Ruby 3.2+, Rails 8+, Thor (CLI), TTY::Prompt (interactive prompts), Minitest (testing)

**Purpose:** Provides an opinionated, interactive CLI wizard (`railstart new`) that guides developers through Rails 8 project setup with customizable defaults and post-generation hooks.

---

## Root Setup Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Lint code
bundle exec rubocop

# Full check (lint + test)
bundle exec rake test && bundle exec rubocop
```

---

## Universal Conventions

- **Code Style:** Ruby conventions, frozen_string_literal in all files
- **Linting:** RuboCop (see `.rubocop.yml`)
- **Testing Framework:** Minitest (prefer assertions over mocks; integration > unit)
- **Commits:** Conventional Commits (feat:, fix:, test:, docs:, refactor:)
- **Ruby Version:** 3.2.0 minimum (see `railstart.gemspec`)

---

## Gem Structure & Key Files

### Main Entry Points
- **CLI Executable:** `exe/railstart` - Script that launches the CLI
- **Main Module:** `lib/railstart.rb` - Defines `Railstart` namespace
- **Version:** `lib/railstart/version.rb` - `Railstart::VERSION` constant

### Implementation Files (to create/modify)
- **CLI Interface:** `lib/railstart/cli.rb` - Thor commands (`railstart new`)
- **Config System:** `lib/railstart/config.rb` - Load/merge/validate YAML configs
- **Generator:** `lib/railstart/generator.rb` - Orchestrate interactive flow
- **Command Builder:** `lib/railstart/command_builder.rb` - Translate answers → `rails new` flags

### Configuration
- **Built-in Defaults:** `config/rails8_defaults.yaml` - Ships with gem; defines all questions
- **User Overrides:** `~/.railstart/config.yaml` - Optional user customization

### Tests
- **Config Tests:** `test/config_test.rb` - Config loading, merging, validation
- **Command Builder Tests:** `test/command_builder_test.rb` - Flag translation
- **Generator Tests:** `test/generator_test.rb` - Flow orchestration (stubs system calls)
- **Integration:** `test/railstart_test.rb` - Current test file (expand as needed)

---

## Core Patterns & Conventions

### 1. **Config System (YAML-driven, ID-based merge)**

**Rules:**
- ✅ DO: Merge configs by unique `id` (questions, post-actions); never naive array merge
- ✅ DO: User config can override/add questions; built-in choices are replaced entirely if user specifies
- ❌ DON'T: Naive `deep_merge` on question/action arrays (creates unmergeable state)

**Example implementation:** See `lib/railstart/config.rb` - `merge_questions`, `merge_post_actions` methods

**Structure:**
```yaml
questions:
  - id: database                # unique identifier
    type: select|multi_select|yes_no|input
    prompt: "User-facing question"
    choices:
      - name: "Display name"
        value: "internal_value"
        default: true           # at most one per select
        rails_flag: "--flag=%{value}"
    rails_flag: "--database=%{value}"  # interpolated with %{value}

post_actions:
  - id: init_git                # unique identifier
    name: "Human readable name"
    enabled: true               # can be disabled by user config
    command: "git init && ..."
    if:                         # optional condition
      question: question_id
      equals: value
```

### 2. **TTY::Prompt Integration (thin adapter)**

**Rules:**
- ✅ DO: Each question type maps to one TTY::Prompt call (`select`, `multi_select`, `yes?`, `ask`)
- ✅ DO: Extract defaults from config before calling TTY
- ❌ DON'T: Add logic inside prompt calls; pre-compute everything

**Pattern:**
```ruby
def ask_question(question, answers)
  case question['type']
  when 'select'
    choices = question['choices'].map { |c| [c['name'], c['value']] }
    @prompt.select(question['prompt'], choices, default: find_default(question))
  when 'multi_select'
    choices = question['choices'].map { |c| [c['name'], c['value']] }
    @prompt.multi_select(question['prompt'], choices, default: question['default'] || [])
  when 'yes_no'
    @prompt.yes?(question['prompt'], default: question.fetch('default', false))
  when 'input'
    @prompt.ask(question['prompt'], default: question['default'])
  end
end
```

### 3. **Generator Flow (orchestration)**

**Rules:**
- ✅ DO: Separate concerns: load config → select mode → ask questions → build command → execute → post-actions
- ✅ DO: Validate config early (before prompting)
- ✅ DO: Stub `system()` calls in tests (don't actually run `rails new`)

**Flow:**
```
1. Load & validate config
2. Prompt for app name (if not provided)
3. Ask mode: Default or Customize?
4. If Default: use all config defaults, skip questions
5. If Customize: ask each question (respecting depends_on conditions)
6. Show summary, confirm
7. Build `rails new` command from answers
8. Execute (abort on failure)
9. chdir into app, run enabled post-actions
```

### 4. **Command Building (pure function)**

**Rules:**
- ✅ DO: Keep this pure (no side effects); test with simple input/output
- ✅ DO: Support `%{value}` interpolation in rails_flag strings
- ✅ DO: Handle multi_select by iterating selected choices and applying their individual flags

**Pattern:**
```ruby
def build_rails_command(app_name, answers)
  flags = []
  config['questions'].each do |q|
    answer = answers[q['id']]
    next unless answer

    case q['type']
    when 'multi_select'
      q['choices'].each do |choice|
        if answer.include?(choice['value'])
          add_flags(flags, choice, choice['value'])
        end
      end
    else
      add_flags(flags, q, answer)
    end
  end

  "rails new #{app_name} #{flags.join(' ')}"
end

private

def add_flags(flags, source, value)
  flag_list = source['rails_flags'] || [source['rails_flag']].compact
  flag_list.each do |flag|
    interpolated = flag.gsub('%{value}', value.to_s)
    flags << interpolated
  end
end
```

---

## Touch Points & Key Files to Know

### Configuration & Setup
- **Gem entry:** `lib/railstart.rb` - Defines `Railstart` module, version
- **Config class:** `lib/railstart/config.rb` - `Railstart::Config.load` returns merged config
- **Built-in config:** `config/rails8_defaults.yaml` - Reference for all available question types

### Interactive Flow
- **CLI wrapper:** `lib/railstart/cli.rb` - Thor commands
- **Generator:** `lib/railstart/generator.rb` - Main orchestration logic
- **Command builder:** `lib/railstart/command_builder.rb` - Pure translation layer

### Testing Patterns
- **Config test:** Tests for merge correctness, validation, override behavior
- **Builder test:** Tests for flag generation with various input combinations
- **Generator test (stubs):** Mock `system()`, `Dir.chdir()`, TTY::Prompt

---

## Common Gotchas

1. **Config merging is critical** - Naive `deep_merge` on arrays will create unmergeable state. Always merge by `id`.
2. **TTY::Prompt returns unwrapped values** - `select` returns the `value` (not choice object); handle accordingly.
3. **Flag interpolation** - Use `%{value}` (not `#{value}`); interpolate at build time.
4. **Validation must run early** - Check config validity before any prompting to fail fast.
5. **System calls in tests** - Always stub `system()` and `Dir.chdir()`; never actually run `rails new` in tests.

---

## JIT Index - Quick Find Commands

```bash
# Find config loading logic
rg -n "def load" lib/railstart/config.rb

# Find question type handling
rg -n "when.*select|multi_select|yes_no|input" lib/railstart/

# Find flag building
rg -n "rails_flag" lib/railstart/command_builder.rb

# Find all tests
find test -name "*.rb" -type f

# Search for TODOs
rg -n "TODO|FIXME" lib/ test/
```

---

## Pre-PR Checklist

Before creating a pull request:

```bash
# Run full test suite
bundle exec rake test

# Run linter and auto-fix
bundle exec rubocop -a

# Verify no broken requires
ruby -c exe/railstart

# Check for unused variables/code
bundle exec rubocop --lint lib/ test/
```

---

## Definition of Done

- [ ] Code changes pass linting (`bundle exec rubocop`)
- [ ] All tests pass (`bundle exec rake test`)
- [ ] New feature has corresponding tests
- [ ] Config changes validated (no merge ambiguities)
- [ ] README/CHANGELOG updated if user-facing changes
- [ ] Gem still installs cleanly (`gem build`)
