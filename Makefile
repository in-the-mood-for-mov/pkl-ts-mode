.PHONY: test

test:
	emacs --batch -L . -l pkl-ts-mode-tests.el -f ert-run-tests-batch-and-exit
