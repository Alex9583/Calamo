# Small logical units

Split long files and functions along their natural seams into the smallest
coherent units — structure should speak instead of commentary.

- A file that needs `// ---` section separators is several modules in one
  file: make them modules (e.g. `calamo-ffi` → `types`/`ports`/`facade`;
  `engine` → facade + `pipeline` submodule).
- A function past one screen or mixing abstraction levels gets the same
  treatment.
- A split never widens visibility: keep the public surface stable
  (re-exports) and the parts as private as possible.
- Docs too: one rule/topic per file, loaded only when relevant.

**Review check:** flag any file or function in the diff that outgrew one
logical unit; name the seams to cut.
