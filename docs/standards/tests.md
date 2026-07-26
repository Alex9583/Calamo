# Given/When/Then tests

Behavioral tests read given → when → then, in both harnesses.

- Names spell the scenario as given-when-then — `given_x_when_y_then_z` in
  Rust, `givenXWhenYThenZ` in Swift.
- Bodies are sectioned by `// Given`, `// When`, `// Then` — the one
  sanctioned structural comment in tests; a clause may carry a short
  qualifier (`// Given: an accidental press`).

**Review check:** flag any behavioral test whose name or body departs from
the format.
