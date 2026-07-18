# Comments

Avoid comments by default. A comment earns its place only by stating a
constraint the code cannot show; it is one short, precise line where
possible.

- Delete any comment that restates the name, the signature, or what the next
  line does — including `///` doc comments that paraphrase the item.
- File headers: core rationale + non-obvious gotchas, nothing the code or its
  error messages already say.
- Applies everywhere: source, tests, CI workflows, config files, scripts.

**Review check:** quote each comment that fails the rule; propose deletion or
the one-line replacement.
