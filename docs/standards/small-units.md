# Small logical units

Split long files and functions along their natural seams into the smallest
coherent units — structure should speak instead of commentary.

- A file that needs `// ---` section separators is several modules in one
  file: make them modules (e.g. `calamo-ffi` → `types`/`ports`/`facade`;
  `engine` → facade + `pipeline` submodule).
- A function whose body reads as a run of independent paragraphs is several
  functions in one: name each paragraph and make the parent a short
  composition of those calls (e.g. `validate` → `glossary_issues` +
  `corpus_issues` + `synthetic_issues` + `manifest_issues`). Signs: past one
  screen (~40 lines), blank-line blocks each on their own concern, a local
  helper closure threaded through the blocks, mixed abstraction levels.
- A split never widens visibility: keep the public surface stable
  (re-exports) and the parts as private as possible.
- Docs too: one rule/topic per file, loaded only when relevant.

**Review check:** flag any file or function in the diff that outgrew one
logical unit; name the seams to cut. Separators and paragraph runs are cues,
not the bar — a long body with neither still gets flagged.
