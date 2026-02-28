# AGENTS.md (helm-eca)

## Build / lint / test
- Byte-compile (deps `eca` + `helm` must be in Emacs `load-path`):
  emacs -Q --batch -L . -f batch-byte-compile helm-eca.el
- Doc/lint (built-in Checkdoc):
  emacs -Q --batch -l checkdoc --eval '(checkdoc-file "helm-eca.el")'
- Tests: none in this repo. If/when ERT tests exist (e.g. `test/helm-eca-test.el`):
  emacs -Q --batch -L . -l test/helm-eca-test.el -f ert-run-tests-batch-and-exit
  emacs -Q --batch -L . -l test/helm-eca-test.el --eval '(ert-run-tests-batch-and-exit "^helm-eca-")'  # single/regex

## Code style
- Emacs Lisp; keep `lexical-binding: t`, file header, `;;;###autoload`, and `(provide 'helm-eca)` at EOF.
- Public symbols use `helm-eca-` prefix (main entry point is `helm-eca`); private helpers use `helm-eca--`.
- `require` order: built-ins first, then external deps; don’t add unused requires.
- Naming: prefer descriptive names; keep `defcustom`/`defgroup` docs user-facing.
- Error handling: use `user-error` for interactive failures; keep `condition-case` narrow.
- Compatibility: ECA internals may change—guard optional calls with `fboundp`/`boundp`.
- Formatting: 2-space indent, no trailing whitespace; run Checkdoc after docstring changes.
