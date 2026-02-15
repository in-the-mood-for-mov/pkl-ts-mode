# Emacs support for the Pkl language

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
