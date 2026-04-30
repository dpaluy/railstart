# CLI and Config Reference

## Contents

- CLI commands
- Config layers
- Built-in questions
- Built-in post-actions
- Non-obvious behavior

## CLI Commands

Use `railstart ...` when operating an installed gem. From this repository checkout, prefer `bundle exec exe/railstart ...` so verification exercises the local source.

Common installed commands:

```bash
railstart init
railstart init --force

railstart new my_app
railstart new my_app --default
railstart new my_app --preset api-only
railstart new my_app --preset api-only --default
railstart new my_app --preset ./path/to/preset.yaml

railstart version
```

Important CLI behavior:

- `--preset NAME` resolves user presets first from `~/.config/railstart/presets/NAME.yaml`, then gem presets from `config/presets/NAME.yaml`.
- `--preset` also accepts an explicit `.yaml` or `.yml` path.
- `--default` maps to the `default` preset name. If no `default` preset exists, Railstart falls back to the built-in config.
- `railstart init` copies the full `config/rails8_defaults.yaml` into `~/.config/railstart/config.yaml` and creates `~/.config/railstart/presets/example.yaml`.
- There is no dry-run mode. Use `CommandBuilder` tests or injected generator tests when you need to verify flags without creating a Rails app.

Current built-in preset files:

- `config/presets/default.yaml`
- `config/presets/api-only.yaml`
- `config/presets/vite-bun.yaml`

## Config Layers

Railstart loads and validates configuration in this order:

1. Built-in config: `config/rails8_defaults.yaml`
2. User config: `~/.config/railstart/config.yaml`
3. Optional preset: user preset or gem preset

Merge rules:

- `questions` and `post_actions` merge by `id`.
- Hashes deep-merge.
- Scalars overwrite earlier values.
- Arrays other than `questions` and `post_actions` replace the earlier value.
- Validation runs after merge.
- For matched question entries, `choices` is a normal nested array and is replaced when the overlay supplies it.

## Built-in Questions

These are the current questions defined in `config/rails8_defaults.yaml`.

| ID | Type | Built-in choices/default | Rails flag behavior |
| --- | --- | --- | --- |
| `database` | `select` | `sqlite3` default, `postgresql`, `mysql` | Question-level `--database=%<value>s` |
| `css` | `select` | `tailwind` default, `bootstrap`, `bulma`, `postcss`, `sass`, `none` | Question-level `--css=%{value}` except custom choice-level overrides you may add in presets |
| `javascript` | `select` | `importmap` default, `bun`, `esbuild`, `rollup`, `webpack`, `none` | Choice-level flags for built-in choices |
| `skip_features` | `multi_select` | empty default | Selected choices emit their own skip flags |
| `api_only` | `yes_no` | `false` | `--api` when true |
| `skip_git` | `yes_no` | `false` | `--skip-git` when true |
| `skip_docker` | `yes_no` | `false` | `--skip-docker` when true |
| `skip_bundle` | `yes_no` | `false` | `--skip-bundle` when true |
| `test_framework` | `select` | `minitest` default, `rspec` | RSpec choice emits `--skip-test` |

Built-in `skip_features` values:

- `action_mailer`
- `action_mailbox`
- `action_text`
- `active_record`
- `active_job`
- `active_storage`
- `action_cable`
- `hotwire`

Do not assume the built-in list is the full universe of valid values. A preset can replace `choices` for a question and introduce values such as `vite`.

Flag interpolation supports Ruby `format` placeholders such as `%{value}` and `%<value>s`. Prefer `%{value}` in new config unless a string formatting width/type is needed.

## Built-in Post-Actions

These are the current post-actions defined in `config/rails8_defaults.yaml`.

| ID | Enabled by default | Condition | Behavior |
| --- | --- | --- | --- |
| `init_git` | yes | `skip_git == false` | Optionally prompts, then runs `git init`, stages files, and commits |
| `bundle_install` | no | `skip_bundle == true` | Optionally prompts, then runs `bundle install` |
| `setup_rspec` | yes | `test_framework == rspec` | Runs RSpec install commands |

## Non-Obvious Behavior

- Stored answers use stable choice `value`s, not display names.
- `multi_select` defaults in config and presets must use values such as `action_mailer`, not labels such as `Action Mailer`.
- `CommandBuilder` skips falsey answers. A `yes_no` question with `false` does not emit a flag.
- A `select` choice can define its own `rails_flag` or `rails_flags`; if it does, that takes precedence over a question-level flag.
- A `select` choice can also intentionally emit no flag at all.
- App generation failure aborts the run. Post-action failures only warn and continue.
- `--default` skips interactive questions, but Railstart still shows the summary and asks for final confirmation before running `rails new`.
