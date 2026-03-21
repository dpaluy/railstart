---
name: railstart-coder
description: Use the railstart gem to scaffold Rails applications, run `railstart init` or `railstart new`, create or refine railstart presets, customize `~/.config/railstart/config.yaml`, debug config or post-action behavior, or contribute changes to the gem itself. Trigger when a task involves Railstart CLI usage, preset authoring, YAML question or post-action configuration, template post-actions, or the gem's CLI/config/generator implementation.
---

# Railstart Coder

## Start

- Identify whether the task is app generation, config or preset authoring, or gem development.
- Read [references/cli-and-config.md](references/cli-and-config.md) for command behavior, config layering, and current built-in defaults.
- Read [references/presets-and-post-actions.md](references/presets-and-post-actions.md) before adding or changing presets, custom choices, command actions, or template actions.
- Read [references/gem-development.md](references/gem-development.md) before changing gem code or tests.

## Use the Right Layer

- Run `railstart init` when the user needs a starting `~/.config/railstart/` tree.
- Edit `~/.config/railstart/config.yaml` for personal defaults that should apply across runs.
- Create a preset file for reusable named stacks or team conventions.
- Change `config/rails8_defaults.yaml` only when the gem's shipped behavior should change for everyone.

## Follow These Rules

- Treat `--default` as "load the `default` preset and skip interactive questions", not "use raw built-in config as-is".
- Merge `questions` and `post_actions` by `id`; do not copy entire arrays unless full replacement is intentional.
- Use stable choice `value`s in stored answers and `multi_select` defaults.
- Remember presets can add new choices or post-actions that do not exist in the built-in config.
- Prefer `type: template` post-actions when the work belongs in the Rails template DSL; keep simple shell steps as command actions.
- When code and documentation disagree, trust the current implementation in `lib/` and `config/`.

## Run Common Workflows

### Generate an App

1. Decide whether the run should be interactive, `--default`, or `--preset NAME`.
2. Use `railstart new APP_NAME ...`.
3. Review the summary before confirming generation.
4. Verify post-actions ran inside the generated app directory.

### Create or Update a Preset

1. Start from the smallest YAML override that changes only the intended defaults.
2. Reuse built-in question ids whenever possible.
3. Add new choices or post-actions only when the built-in model cannot represent the stack.
4. Test both `--preset NAME` and `--preset NAME --default` when the preset is meant for repeatable non-interactive runs.

### Extend the Gem

1. Inspect `lib/railstart/config.rb`, `lib/railstart/generator.rb`, `lib/railstart/command_builder.rb`, and `lib/railstart/template_runner.rb` before adding logic.
2. Keep behavior declarative in config when possible instead of hardcoding one-off branches in the generator.
3. Add or update tests with the change.
4. Run the relevant test and lint commands from [references/gem-development.md](references/gem-development.md).
