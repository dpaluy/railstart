# Presets and Post-Actions Reference

## Contents

- Preset structure
- Merge rules
- Post-action types
- Template variables
- Safe authoring patterns

## Preset Structure

Start from the smallest override that expresses the stack:

```yaml
---
questions:
  - id: database
    choices:
      - name: PostgreSQL
        value: postgresql
        default: true

  - id: skip_features
    default:
      - action_mailer
      - hotwire

  - id: api_only
    default: true

post_actions:
  - id: init_git
    enabled: false
```

Use presets for reusable named stacks. Use `~/.config/railstart/config.yaml` for personal defaults that should apply to every run.

## Merge Rules

- Match `questions` by `id`.
- Match `post_actions` by `id`.
- Replace a question's `choices` array entirely when the preset supplies `choices`.
- Use `default: true` on exactly one choice when selecting a default for a `select` question.
- Use stable `value`s in `multi_select` defaults.
- Add a new question or post-action by using a new `id`.

Presets can extend the built-in model. For example, `config/presets/vite-bun.yaml` replaces the `javascript` choices with a `vite` value and adds post-actions that do not exist in the built-in config.

## Post-Action Types

### Command Action

Use the default command action for simple shell work:

```yaml
post_actions:
  - id: setup_rspec
    name: "Setup RSpec"
    enabled: true
    if:
      question: test_framework
      equals: rspec
    command: "bundle add rspec-rails --group development,test && bundle exec rails generate rspec:install"
```

Rules:

- `command` is required when the action is enabled.
- `prompt` is optional. When present, Railstart confirms before running the action.
- `default` controls the prompt default and falls back to `true`.

### Template Action

Use `type: template` when the work belongs in Rails template DSL:

```yaml
post_actions:
  - id: apply_template
    name: "Apply custom Rails template"
    type: template
    enabled: true
    source: "https://railsbytes.com/script/zAasQK"
    variables:
      app_label: "my-project"
```

Rules:

- `source` is required.
- `variables`, when present, must be a hash.
- Template failures warn and continue instead of aborting the full run.

## Template Variables

Template actions always receive these instance variables:

- `@app_name`
- `@answers`

Custom `variables` entries are merged on top and exposed as instance variables such as `@app_label`.

## Conditions

Post-actions support two condition forms:

```yaml
if:
  question: test_framework
  equals: rspec
```

```yaml
if:
  question: skip_features
  includes:
    - hotwire
```

Behavior:

- `equals` checks exact equality against the stored answer.
- `includes` checks array intersection against stored array answers.
- If the `if` block is missing or uses neither key, the action runs when enabled.

## Safe Authoring Patterns

- Prefer reusing existing question ids over creating parallel variants of the same concept.
- Keep presets narrow. A preset should express one opinionated stack, not every possible toggle.
- Prefer question-level flags for broad cases and choice-level flags only when a specific choice needs special behavior or no flag.
- Test non-interactive presets with `railstart new APP_NAME --preset NAME --default`.
- When a preset adds a brand-new choice value, verify `CommandBuilder` behavior still makes sense for that value.
