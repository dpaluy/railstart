# Gem Development Reference

## Contents

- Core files
- Runtime flow
- Change strategy
- Validation commands

## Core Files

Read these files before changing behavior:

- `lib/railstart/cli.rb`
- `lib/railstart/config.rb`
- `lib/railstart/generator.rb`
- `lib/railstart/command_builder.rb`
- `lib/railstart/template_runner.rb`
- `config/rails8_defaults.yaml`

Useful responsibility map:

- `CLI`: Thor commands, preset resolution, `init`, and `version`
- `Config`: YAML loading, merge rules, interpolation, and validation
- `Generator`: prompting, summary, app generation, and post-action execution
- `CommandBuilder`: pure flag assembly from config plus answers
- `TemplateRunner`: Rails template execution for `type: template` post-actions

## Runtime Flow

Current flow for `railstart new`:

1. Resolve preset name or preset path in `CLI`
2. Load merged config with `Config.load`
3. Build `Generator`
4. Prompt for app name if needed
5. Collect defaults or ask interactive questions
6. Show summary and confirm
7. Build the `rails new` command via `CommandBuilder`
8. Run `rails new`
9. `Dir.chdir` into the app and process post-actions

Important details:

- `--default` skips interactive questions but still shows the summary and asks for final confirmation.
- `generate_app` runs outside bundler with `Bundler.with_unbundled_env` when Bundler is present.
- Command post-actions run with `system`.
- Template post-actions run through `TemplateRunner` and receive `@app_name` plus `@answers`.
- Post-action failures warn and continue; generation failure raises.

## Change Strategy

- Prefer declarative config changes over new branches in `Generator`.
- Keep `CommandBuilder` side-effect free.
- Validate consuming code when changing config schema or answer storage.
- Treat tests as the contract for merge behavior, prompting behavior, and flag generation.
- When changing template behavior, inspect both `Generator#template_variables` and `TemplateRunner`.

## Validation Commands

Use the repo commands that already exist:

```bash
bundle exec rake test
bundle exec rubocop
bundle exec rubocop -a
gem build railstart.gemspec
bundle exec exe/railstart version
bundle exec exe/railstart new my_app --default
```

Run `bundle exec exe/railstart new ...` only when app generation is part of the requested verification. For config and flag behavior, prefer focused Minitest coverage around `Config`, `CommandBuilder`, and `Generator`.

Testing conventions in this repo:

- Use Minitest.
- Prefer assertions over mocks unless isolation matters.
- Stub `system()` in generator tests.
- Stub `Dir.chdir()` when testing post-action flow.
- Inject a prompt double into `Generator` for deterministic question handling.
