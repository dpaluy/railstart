# Railstart Examples

These files are copyable examples for common Railstart configuration shapes.
They are not built-in preset names unless you copy them into your user config.

## Global Config

Use `config.yml` when you want the same defaults on every Railstart run:

```bash
mkdir -p ~/.config/railstart
cp examples/config.yml ~/.config/railstart/config.yaml
```

## Presets

Use a preset example directly by passing its path:

```bash
railstart new my_app --preset ./examples/presets/standard-postgresql.yml --default
```

Or copy it into your user presets directory:

```bash
mkdir -p ~/.config/railstart/presets
cp examples/presets/standard-postgresql.yml ~/.config/railstart/presets/standard-postgresql.yml
railstart new my_app --preset standard-postgresql --default
```

Preset examples:

- `api-postgresql.yml` - PostgreSQL-backed JSON API service
- `standard-postgresql.yml` - conventional full-stack Rails app with PostgreSQL
- `minimal-sqlite.yml` - lightweight local prototype app using SQLite
- `vite-bun.yml` - Vite frontend with Bun installed through Bundlebun
- `template-action.yml` - disabled template post-action showing template variables

When a preset overrides a question's `choices`, include every choice you still
want to offer. Railstart replaces the full `choices` array for that question.
