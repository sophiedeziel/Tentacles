# Tentacles

Before writing or changing backend code, read `app/models/README.md` and follow it. In short:

- No `app/services`. Everything is a model in `app/models`, grouped by domain (`Printer::`, `Dashboard::`, `Library::`,
  `Gcode::`).
- Non-table models inherit `ApplicationModel`. Commands are nouns with a private `#persist`, run with `save` / `save!`.
- No callbacks: `#persist` runs every step inline. GraphQL mutations and jobs stay thin.

Run `bin/check` before calling a change done: it runs RuboCop, ESLint, Sorbet, RSpec and Vitest, and lists the ones that failed.
