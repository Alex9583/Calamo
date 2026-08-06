# Comments

Avoid comments by default. A comment earns its place only by stating a
constraint the code cannot show, in as few words as still carry it — never
ten where three suffice.

- Delete any comment the nearby code already shows — a restated name or
  signature, a narrated next line, a summary of the body or data below —
  including `///` doc comments that paraphrase the item.
- File headers: core rationale + non-obvious gotchas, nothing the code or its
  error messages already say.
- Applies everywhere: source, tests, CI workflows, config files, scripts.

**Review check:** read each comment against the surrounding code; quote each
that fails the rule; propose deletion or the fewest-word replacement.
