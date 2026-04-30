---
name: railstart-coder
description: Use the railstart gem to scaffold Rails applications, initialize or customize `~/.config/railstart`, run `railstart new`, create and test presets, debug YAML config or post-action behavior, and contribute changes to the gem. Trigger when a task involves Railstart CLI usage, Rails 8 starter app generation, preset authoring, YAML question/post-action configuration, Rails template post-actions, or the gem's CLI/config/generator implementation.
---

# Railstart Coder

## Start

- Classify the task first: app generation, config setup, preset authoring, troubleshooting, or gem development.
- In an installed-user context, use `railstart ...`.
- In this repo checkout, use `bundle exec exe/railstart ...` for local CLI verification.
- Do not run `railstart new` unless the user actually wants an app generated. It creates directories and can run post-actions.
- Read [references/cli-and-config.md](references/cli-and-config.md) for command behavior, config layering, and current built-in defaults.
- Read [references/presets-and-post-actions.md](references/presets-and-post-actions.md) before adding or changing presets, custom choices, command actions, or template actions.
- Read [references/gem-development.md](references/gem-development.md) before changing gem code or tests.

## Choose the Right Layer

- Run `railstart init` when the user needs a starting `~/.config/railstart/` tree.
- Edit `~/.config/railstart/config.yaml` for personal defaults that should apply across runs.
- Create a preset file for reusable named stacks or team conventions.
- Change `config/rails8_defaults.yaml` only when the gem's shipped behavior should change for everyone.

## Common Workflows

### Generate an App

1. Decide whether the run should be interactive, `--default`, or `--preset NAME`.
2. Use `railstart new APP_NAME ...` for installed usage, or `bundle exec exe/railstart new APP_NAME ...` from this repo.
3. Remember `--default` skips question prompts but still shows the summary and final confirmation.
4. Verify the selected preset and post-actions are appropriate before confirming generation.

### Initialize or Customize Local Config

1. Use `railstart init` to create `~/.config/railstart/config.yaml` and `~/.config/railstart/presets/example.yaml`.
2. Use `railstart init --force` only when overwriting existing generated files is intended.
3. Keep user config overrides minimal; remove copied sections that are not being customized when writing a clean config by hand.

### Create or Update a Preset

1. Start from the smallest YAML override that changes only the intended defaults.
2. Reuse built-in question ids whenever possible.
3. Add new choices or post-actions only when the built-in model cannot represent the stack.
4. Test both `--preset NAME` and `--preset NAME --default` when the preset is meant for repeatable non-interactive runs.

### Troubleshoot a Railstart Run

1. Check which config layers are active: built-in defaults, user config, and optional preset.
2. Validate that question and post-action ids are unique after merging.
3. Check `depends_on` and post-action `if` conditions against stored answer values, not display names.
4. For unexpected Rails flags, inspect `CommandBuilder` and the selected question/choice `rails_flag` or `rails_flags`.
5. For post-action failures, distinguish app generation failure from post-action warnings; post-action failures continue by design.

### Extend the Gem

1. Inspect `lib/railstart/config.rb`, `lib/railstart/generator.rb`, `lib/railstart/command_builder.rb`, and `lib/railstart/template_runner.rb` before adding logic.
2. Keep behavior declarative in config when possible instead of hardcoding one-off branches in the generator.
3. Add or update tests with the change.
4. Run the relevant test and lint commands from [references/gem-development.md](references/gem-development.md).

## Rules

- Treat `--default` as "load the `default` preset and skip interactive questions", not "use raw built-in config as-is".
- Merge `questions` and `post_actions` by `id`; do not copy entire arrays unless full replacement is intentional.
- Use stable choice `value`s in stored answers and `multi_select` defaults.
- Remember presets can add new choices or post-actions that do not exist in the built-in config.
- Prefer `type: template` post-actions when the work belongs in the Rails template DSL; keep simple shell steps as command actions.
- When code and documentation disagree, trust the current implementation in `lib/` and `config/`.
