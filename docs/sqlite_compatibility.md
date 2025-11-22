# SQLite / Litestack Compatibility Guide

This project now supports running the development stack on SQLite/Litestack. Because the original schema was designed for PostgreSQL, follow the guidelines below to avoid compatibility issues.

## Workflow

1. **Normalize the schema after dumping**

   ```bash
   bin/rails db:schema:dump
   bin/rails db:schema:neutralize
   ```

   The neutralizer removes Postgres-specific features (extensions, enums, casts, generated columns and partial indexes) so the schema can be loaded by SQLite/Litestack.

2. **Lint migrations before opening a PR**

   ```bash
   bin/rails db:sqlite:lint_migrations
   ```

   The linter fails if a migration uses `t.uuid`, `:jsonb`, `array: true`, `enable_extension`, or other Postgres-only constructs.

3. **Verify setup pipeline**

   ```bash
   bin/rails db:sqlite:setup_check
   ```

   This task runs `db:drop`, `db:create`, and `db:schema:load` to ensure a clean SQLite database can be built end-to-end.

## Migration Guidelines

- Prefer `t.string` primary keys. If you need UUID semantics, generate them in the model (e.g. `SecureRandom.uuid`) rather than relying on `gen_random_uuid()`.
- Store structured data in `t.text` columns and use JSON serialization; avoid `:jsonb`.
- Replace array columns with join tables or serialized arrays backed by the new `Sqlite::SchemaHelpers`.
- Avoid triggers, partial indexes, functional indexes, or database-level enums. Implement the logic in Ruby or in plain constraints that SQLite understands.

## Troubleshooting

- **`undefined method 'uuid'`** – The shim in `config/initializers/sqlite_adapters.rb` must be loaded. Ensure the initializer was not removed and that `bin/setup` runs after a restart.
- **`unrecognized token ':'` / `near ')' syntax error`** – Run `bin/rails db:schema:neutralize` to strip casts and Postgres-only `WHERE` clauses from indices.
- **`NoMethodError: enable_extension`** – The neutralizer or helper was skipped. Re-run the neutralizer and confirm the initializer patch is present.

Refer to `lib/sqlite/schema_helpers.rb` and `lib/sqlite/schema_neutralizer.rb` for the latest implementation details.


