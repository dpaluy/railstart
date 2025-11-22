# Railstart

Interactive CLI wizard for generating Rails 8 applications with customizable configuration and smart defaults.

Think of it as `rails new` with an opinion and a friendly interactive experience.

## Installation

```bash
gem install railstart
```

Or in your Gemfile:

```ruby
gem "railstart"
```

## Usage

### Generate a new Rails app

```bash
railstart new my_app
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

### Skip interactive mode (use defaults)

Use the `--default` flag to skip all questions and apply built-in defaults:

```bash
railstart new my_app --default
```

This creates a PostgreSQL + Tailwind + Importmap Rails app instantly.

## Configuration

### Built-in Defaults

Railstart ships with sensible Rails 8 defaults defined in `config/rails8_defaults.yaml`. These drive the interactive questions and their defaults.

### Customize for Your Team

Create a `~/.config/railstart/config.yaml` file to override defaults:

```yaml
questions:
  - id: database
    choices:
      - name: PostgreSQL (recommended)
        value: postgresql
        default: true  # Your team's preference

post_actions:
  - id: bundle_install
    enabled: false  # Your team manages gems differently
  
  - id: setup_auth
    name: "Setup authentication"
    enabled: true
    command: "bundle exec rails generate devise:install"
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

## Development

```bash
# Install dependencies
bundle install

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

- **Config System** (`lib/railstart/config.rb`) - Loads and merges YAML configurations
- **Generator** (`lib/railstart/generator.rb`) - Orchestrates interactive flow
- **Command Builder** (`lib/railstart/command_builder.rb`) - Translates answers to `rails new` flags
- **CLI** (`lib/railstart/cli.rb`) - Thor command interface

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dpaluy/railstart.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
