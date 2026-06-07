# Emacs support for the Pkl language

[![CI](https://github.com/in-the-mood-for-mov/pkl-ts-mode/actions/workflows/ci.yml/badge.svg)](https://github.com/in-the-mood-for-mov/pkl-ts-mode/actions/workflows/ci.yml)

This package adds support for the [Pkl language](https://github.com/apple/pkl) to Emacs.
* indent rules
* font locking through [`treesit`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Parsing-Program-Source.html)
* language service through [`eglot`](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html)

## Requisites

You need to provide the following dependencies for this mode to work.
* Emacs 29+, for treesit support
* Java 22+, to [run the language server](https://github.com/apple/pkl-lsp/issues/60)

## Quickstart

Here is a basic `use-package` invocation for this package.

```elisp
(use-package pkl-ts-mode
  :ensure t
  :vc (:url "https://github.com/in-the-mood-for-mov/pkl-ts-mode.git")
  :mode ("\\.pkl\\'" "\\.pcf\\'")
  :config
  (pkl-ts-mode-eglot-init)
  (add-hook 'pkl-ts-mode-hook #'eglot-ensure))
```

You can then install the Pkl grammar with `M-x treesit-install-language-grammar`.

## Evil text objects

When [`evil`](https://github.com/emacs-evil/evil) is installed, `pkl-ts-mode`
binds the following text objects in visual and operator-pending state:

| Key  | Object    | Outer (`a`) selects       | Inner (`i`) selects              |
|------|-----------|---------------------------|----------------------------------|
| `k`  | class     | the whole class           | the class body without braces    |
| `c`  | comment   | the comment run           | the comment text without markers |
| `e`  | object    | the whole object body     | the body without braces          |
| `f`  | method    | the whole method          | the method body without braces   |
| `p`  | paragraph | the paragraph + separator | the paragraph at point           |
| `t`  | string    | the string with quotes    | the string contents              |

For example, `dak` deletes the surrounding class and `vie` selects inside
the current object body.

## Development

Run the test suite with:

```bash
make test
```

The tests need the Pkl tree-sitter grammar installed (`M-x
treesit-install-language-grammar RET pkl RET`). Evil is optional: when it is
not installed the test suite falls back to a small stub, so the core tests run
without it.

CI (see `.github/workflows/ci.yml`) runs on every push and pull request across
Emacs 29 and 30. Each run byte-compiles the package with warnings treated as
errors and runs the suite twice — once without Evil (the stub path) and once
with Evil installed, which also byte-compiles the optional integration.

The paragraph object (`p`) is comment-aware: inside a comment it selects the
paragraph within the comments.
