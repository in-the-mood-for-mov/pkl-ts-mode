# Emacs support for the Pkl language

[![CI](https://github.com/in-the-mood-for-mov/pkl-ts-mode/actions/workflows/ci.yml/badge.svg)](https://github.com/in-the-mood-for-mov/pkl-ts-mode/actions/workflows/ci.yml)

This package adds support for the [Pkl language](https://github.com/apple/pkl) to Emacs.
* indent rules, with electric reindentation of closing `}`, `]`, and `)` as you type them
* font locking through [`treesit`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Parsing-Program-Source.html)
* symbol navigation through [`imenu`](https://www.gnu.org/software/emacs/manual/html_node/emacs/Imenu.html) (classes, type aliases, methods, properties)
* structural navigation over major declarations (`beginning-of-defun` and friends)
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
  :defer t
  :config
  (pkl-ts-mode-eglot-init)
  (add-hook 'pkl-ts-mode-hook #'eglot-ensure))
```

You also need the Pkl tree-sitter grammar; see [Tree-sitter
grammar](#tree-sitter-grammar) below.

## Tree-sitter grammar

`pkl-ts-mode` is powered by tree-sitter and needs the Pkl grammar compiled and
installed. Loading the package registers Pkl in `treesit-language-source-alist`,
so once it is loaded you can install the grammar with:

```
M-x treesit-install-language-grammar RET pkl RET
```

The source URL is pre-filled from the registered source, so you can accept the
remaining prompts. Installation compiles the grammar from
[`tree-sitter-pkl`](https://github.com/apple/tree-sitter-pkl), which needs `git`
and a C compiler on your `PATH`.

### When the grammar is missing

If the grammar is missing when you open a Pkl file, the mode stops with:

> Tree-sitter grammar for Pkl is not installed.
> Install it with M-x treesit-install-language-grammar RET pkl RET

After installing the grammar, you can simply `M-x revert-buffer` to reload the
major mode without restarting Emacs.

## Language server (Eglot)

`pkl-ts-mode` talks to Apple's [`pkl-lsp`](https://github.com/apple/pkl-lsp)
language server through
[Eglot](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html).

Call `pkl-ts-mode-eglot-init` once (see the Quickstart) to register `pkl-lsp`
as the Eglot server for `pkl-ts-mode`. The server JAR is **downloaded
automatically** from the `pkl-lsp` GitHub releases the first time Eglot starts
and is cached under `pkl-ts-mode-eglot-install-dir`. Running it requires
**Java 22+** on your machine.

### Customization

All options live in the `pkl-ts-mode-eglot` group (`M-x customize-group RET
pkl-ts-mode-eglot`).

| Option | Default | Purpose |
|--------|---------|---------|
| `pkl-ts-mode-eglot-server-version` | `latest` | pkl-lsp release to download. `latest` resolves the newest GitHub release; otherwise set a string matching a release tag. |
| `pkl-ts-mode-eglot-install-dir` | `~/.emacs.d/pkl-lsp` | Directory where `pkl-lsp.jar` is stored. |
| `pkl-ts-mode-eglot-java-path` | `"java"` | Java executable used to run the server. |
| `pkl-ts-mode-eglot-java-args` | `nil` | Extra JVM arguments, e.g. `'("-Xmx512m")`. |
| `pkl-ts-mode-eglot-pkl-path` | `nil` | Path to the Pkl CLI. When `nil`, `pkl` is looked up on `exec-path`. |

`M-x pkl-ts-mode-eglot-install-server` (re)downloads the JAR, replacing any
existing copy — handy after changing `pkl-ts-mode-eglot-server-version` or to
force an upgrade.

### Troubleshooting

* **`pkl` not found.** `pkl-lsp` asks Emacs for the Pkl CLI path, and by default
  the package answers with the first `pkl` on `exec-path`. In GUI Emacs
  `exec-path` often differs from your shell `PATH`, so either install
  [`exec-path-from-shell`](https://github.com/purcell/exec-path-from-shell) or
  set `pkl-ts-mode-eglot-pkl-path` to the absolute path of `pkl`.
* **Wrong or missing Java.** Point `pkl-ts-mode-eglot-java-path` at a Java 22+
  executable.
* **Inspect LSP traffic.** `M-x eglot-events-buffer` shows the requests and
  responses between Emacs and `pkl-lsp`; the server's own stderr lands in the
  `*EGLOT … stderr*` buffer.
* **Re-download the server.** Delete `pkl-ts-mode-eglot-install-dir` or run
  `M-x pkl-ts-mode-eglot-install-server` to fetch a fresh JAR.

## Structural navigation

`pkl-ts-mode` teaches Emacs' standard "defun" commands to move by Pkl's major
declarations — classes, type aliases, methods, and object-valued properties.
Scalar assignments (`name = "app"`) are skipped, so navigation jumps between the
structural landmarks rather than every line.

| Key | Command | Effect |
|-----|---------|--------|
| `C-M-a` | `beginning-of-defun` | jump to the start of the current/previous declaration |
| `C-M-e` | `end-of-defun` | jump past the end of the current declaration |
| `C-M-h` | `mark-defun` | select the whole declaration |
| `C-x n d` | `narrow-to-defun` | narrow to the current declaration |

`which-function-mode` also reports the enclosing declaration (e.g.
`Server.url`), as do `add-log` commands.

## Evil text objects

When [`evil`](https://github.com/emacs-evil/evil) is installed, `pkl-ts-mode`
binds the following text objects in visual and operator-pending state.

| Key | Object              | Inner (`i`) selects          | Outer (`a`) selects |
|-----|---------------------|------------------------------|---------------------|
| `k` | class               | class body without braces    | + braces            |
| `e` | object              | body without braces          | + braces            |
| `f` | method              | method body without braces   | + braces            |
| `c` | comment             | comment text without markers | + markers           |
| `p` | paragraph           | paragraph (within comment)   | + separator         |
| `t` | string              | string contents              | + quotes            |
| `o` | symbol *(built-in)* | single identifier            | + whitespace        |
| `O` | qualified symbol    | identifiers joined by `.`    | + whitespace        |

For example, `dak` deletes the surrounding class and `vie` selects inside
the current object body.

The paragraph object (`p`) is comment-aware: inside a comment it selects the
paragraph clamped to the comment — empty comment lines and blank lines act as
separators — so `gqip` reflows comment prose without spilling into the
surrounding code. Outside comments it behaves like Evil's stock paragraph
object.

The qualified-name object (`O`) is the larger sibling of Evil's built-in symbol
object (`o`). Where `io` grabs one identifier component, `iO` grabs the whole
dotted chain — `config.server.port`, including any trailing call like
`config.server.port(8080)` — and works on dotted type and import names too. `aO`
adds surrounding whitespace, like `ao`.

## Development

```bash
make test          # run the test suite
make compile       # byte-compile the core files (no Evil needed)
make compile-evil  # byte-compile the optional Evil integration (needs Evil)
```

The tests need the Pkl tree-sitter grammar installed (`M-x
treesit-install-language-grammar RET pkl RET`).

Evil is an **optional** dependency of the package, but a hard dependency of the
optional `pkl-ts-mode-evil.el` file (it uses Evil's macros). The core files
neither require nor compile against Evil, so `make compile` works without it;
`make compile-evil` and `make test-evil` need Evil on the load path. When Evil
is not installed the test suite falls back to a small stub, so the core tests
still run.

CI (see `.github/workflows/ci.yml`) runs on every push and pull request across
Emacs 29 and 30. Each run byte-compiles the package with warnings treated as
errors and runs the suite twice — once without Evil (the stub path) and once
with Evil installed, which also byte-compiles the optional integration.
