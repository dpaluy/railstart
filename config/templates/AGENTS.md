# %{app_name}: Agent Guide

Guidance for AI coding agents working in this Rails 8 application.

## Setup

```bash
bin/setup
```

## Everyday Commands

- Run the test suite: `bin/rails test` (system tests: `bin/rails test:system`)
- Run a single test file: `bin/rails test test/models/user_test.rb`
- Lint: `bundle exec rubocop`
- Security scan: `bin/brakeman` (when the gem is installed)
- Console: `bin/rails console`

## Conventions

- Follow standard Ruby and Rails style; keep the existing code style consistent.
- Use `bin/rails generate` for new models, controllers, and migrations instead of hand-writing boilerplate.
- Keep controllers thin; put business logic in models or plain service objects.
- Write tests for new behavior; prefer fixtures and plain assertions over heavy mocking.

## Before Committing

1. `bin/rails test` passes.
2. `bundle exec rubocop` reports no offenses.
3. New or changed behavior is covered by tests.
