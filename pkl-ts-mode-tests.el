;;; pkl-ts-mode-tests.el --- Tests for pkl-ts-mode -*- lexical-binding: t -*-

;;; Commentary:

;; Indentation tests for pkl-ts-mode.  Each test inserts Pkl source into a
;; temporary buffer, activates pkl-ts-mode, re-indents the entire buffer,
;; and verifies the result matches the expected output.

;;; Code:

(require 'ert)
(require 'pkl-ts-mode)

(defun pkl-ts-mode-test-indent (source expected)
  "Insert SOURCE into a temp buffer, re-indent, and compare with EXPECTED."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string) expected))))

(ert-deftest pkl-ts-mode-indent-class-body ()
  "Class body is indented."
  (pkl-ts-mode-test-indent
   ;; source (intentionally unindented)
   "\
class Foo {
bar = 1
baz = 2
}"
   "\
class Foo {
  bar = 1
  baz = 2
}"))

;;; --- Object indentation ---

(ert-deftest pkl-ts-mode-indent-object-body ()
  "Object body is indented."
  (pkl-ts-mode-test-indent
   "\
pigeon {
name = \"Pigeon\"
age = 42
}"
   "\
pigeon {
  name = \"Pigeon\"
  age = 42
}"))

(ert-deftest pkl-ts-mode-indent-nested-objects ()
  "Nested objects are indented progressively."
  (pkl-ts-mode-test-indent
   "\
pigeon {
name = \"Pigeon\"
address {
street = \"123 Main St\"
city = \"Anytown\"
}
}"
   "\
pigeon {
  name = \"Pigeon\"
  address {
    street = \"123 Main St\"
    city = \"Anytown\"
  }
}"))

(ert-deftest pkl-ts-mode-indent-closing-brace ()
  "Closing braces align with the parent."
  (pkl-ts-mode-test-indent
   "\
class Foo {
bar = 1
  }"
   "\
class Foo {
  bar = 1
}"))

(ert-deftest pkl-ts-mode-indent-multiline-string ()
  "Multiline strings are indented."
  (pkl-ts-mode-test-indent
   "\
birds = \"\"\"
pidgeon
robin
\"\"\"
"
   "\
birds = \"\"\"
  pidgeon
  robin
  \"\"\"
"))

(ert-deftest pkl-ts-mode-indent-multiline-string-keep-existing-inner-indent ()
  "Internal indentation inside multiline strings is preserved."
  (pkl-ts-mode-test-indent
   "\
birds = \"\"\"
pidgeon
  robin
\"\"\"
"
   "\
birds = \"\"\"
  pidgeon
    robin
  \"\"\"
"))

(provide 'pkl-ts-mode-tests)

;;; pkl-ts-mode-tests.el ends here
