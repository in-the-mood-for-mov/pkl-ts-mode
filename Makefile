EMACS ?= emacs

# How to put Evil on the load path for the optional integration targets.
# CI and local installs can override this, e.g.
#   make compile-evil PACKAGE_INIT='(progn (setq package-user-dir "/tmp/elpa") (package-initialize))'
PACKAGE_INIT ?= (package-initialize)

# Core files compile without Evil; the Evil integration is compiled separately
# because it uses Evil's macros (see pkl-ts-mode-evil.el).
CORE := pkl-ts-mode.el pkl-ts-mode-eglot.el
EVIL := pkl-ts-mode-evil.el

.PHONY: test test-evil compile compile-evil clean

# Run the suite. Without Evil installed it uses the bundled stub.
test:
	$(EMACS) --batch -L . -l pkl-ts-mode-tests.el -f ert-run-tests-batch-and-exit

# Run the suite against real (non-stubbed) Evil. Requires Evil on the load path.
test-evil:
	$(EMACS) -Q --batch --eval '$(PACKAGE_INIT)' -L . \
	  -l pkl-ts-mode-tests.el -f ert-run-tests-batch-and-exit

# Supported byte-compilation path: core only, no Evil needed.
compile:
	$(EMACS) -Q --batch -L . \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $(CORE)

# Byte-compile the optional Evil integration. Requires Evil on the load path.
compile-evil:
	$(EMACS) -Q --batch --eval '$(PACKAGE_INIT)' -L . \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $(EVIL)

clean:
	rm -f *.elc
