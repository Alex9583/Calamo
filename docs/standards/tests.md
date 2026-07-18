# Given/When/Then tests

Behavioral tests read given → when → then, in both harnesses.

- Names carry the full scenario — snake_case in Rust, camelCase in Swift.
- Bodies are sectioned by `// Given`, `// When`, `// Then` — the one
  sanctioned structural comment in tests; a clause may carry a short
  qualifier (`// Given: an accidental press`).

**Review check:** flag any behavioral test whose name or body departs from
the format.
