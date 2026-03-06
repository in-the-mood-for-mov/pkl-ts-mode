;;; pkl-ts-mode-tests.el --- Tests for pkl-ts-mode -*- lexical-binding: t -*-

;;; Commentary:

;; Tests for pkl-ts-mode covering indentation, syntax, and font-lock.

;;; Code:

(require 'ert)
(require 'pkl-ts-mode)

(defun pkl-ts-mode-test-indent (source expected)
  "Insert SOURCE into a temp buffer, re-indent, and compare with EXPECTED."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string) expected))
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string) expected))))

(ert-deftest pkl-ts-mode-indent-class-body ()
  "Class body is indented."
  (pkl-ts-mode-test-indent
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

(ert-deftest pkl-ts-mode-indent-class-method ()
  "Class method body is indented."
  (pkl-ts-mode-test-indent
   "\
class Aviary {
function listBirds(): String =
birds.join()
}"
   "\
class Aviary {
  function listBirds(): String =
    birds.join()
}"))

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

(ert-deftest pkl-ts-mode-indent-object-method ()
  "Object method body is indented"
  (pkl-ts-mode-test-indent
   "\
pigeon {
local function greet() =
\"Hello\\(name)\"
}"
   "\
pigeon {
  local function greet() =
    \"Hello\\(name)\"
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
birds =
\"\"\"
pidgeon
robin
\"\"\"
"
   "\
birds =
  \"\"\"
  pidgeon
  robin
  \"\"\"
"))

(ert-deftest pkl-ts-mode-indent-multiline-string-keep-existing-inner-indent ()
  "Internal indentation inside multiline strings is preserved."
  (pkl-ts-mode-test-indent
   "\
birds =
\"\"\"
pidgeon
  robin
\"\"\"
"
   "\
birds =
  \"\"\"
  pidgeon
    robin
  \"\"\"
"))

(ert-deftest pkl-ts-mode-indent-block-comment ()
  "Block comment continuation lines are indented correctly."
  (pkl-ts-mode-test-indent
   "\
/*
* This is a block comment
* with multiple lines
*/
"
   "\
/*
 * This is a block comment
 * with multiple lines
 */
"))

(ert-deftest pkl-ts-mode-indent-doc-comment-before-class-property ()
  "Class property after a doc comment is not over-indented."
  (pkl-ts-mode-test-indent
   "\
class Foo {
/// doc comment for bar
bar = 1
}"
   "\
class Foo {
  /// doc comment for bar
  bar = 1
}"))

(ert-deftest pkl-ts-mode-indent-doc-comment-before-class-method ()
  "Class method after a doc comment is not over-indented."
  (pkl-ts-mode-test-indent
   "\
class Aviary {
/// Lists all birds.
function listBirds(): String =
birds.join()
}"
   "\
class Aviary {
  /// Lists all birds.
  function listBirds(): String =
    birds.join()
}"))

(ert-deftest pkl-ts-mode-indent-doc-comment-module-level ()
  "Module-level property after a doc comment is not over-indented."
  (pkl-ts-mode-test-indent
   "\
/// Doc comment for result.
result = 42
"
   "\
/// Doc comment for result.
result = 42
"))

(ert-deftest pkl-ts-mode-indent-chained-method-calls ()
  "Chained method calls are indented relative to the receiver."
  (pkl-ts-mode-test-indent
   "\
result =
items
.filter((x) -> x > 0)
.map((x) -> x * 2)
.toList()
"
   "\
result =
  items
    .filter((x) -> x > 0)
    .map((x) -> x * 2)
    .toList()
"))

(ert-deftest pkl-ts-mode-indent-let-expression ()
  "Chained let expressions align and body is indented."
  (pkl-ts-mode-test-indent
   "\
result =
let (x = 42)
let (y = x + 1)
x + y
"
   "\
result =
  let (x = 42)
  let (y = x + 1)
    x + y
"))

(ert-deftest pkl-ts-mode-indent-null-coalesce-chain ()
  "Null coalesce operator continuation lines are indented."
  (pkl-ts-mode-test-indent
   "\
value =
a
?? b
?? c
"
   "\
value =
  a
    ?? b
    ?? c
"))

(ert-deftest pkl-ts-mode-indent-if-expression ()
  "If expressions have their consequent and alternatives indented."
  (pkl-ts-mode-test-indent
   "\
birds =
if (size == \"large\")
\"turkey\"
else
\"robin\"
"
   "\
birds =
  if (size == \"large\")
    \"turkey\"
  else
    \"robin\"
"))

(ert-deftest pkl-ts-mode-indent-nested-if-expression ()
  "Nested if expressions are indented progressively."
  (pkl-ts-mode-test-indent
   "\
result =
if (a > 0)
if (b > 0)
\"both positive\"
else
\"b not positive\"
else
\"a not positive\"
"
   "\
result =
  if (a > 0)
    if (b > 0)
      \"both positive\"
    else
      \"b not positive\"
  else
    \"a not positive\"
"))

(ert-deftest pkl-ts-mode-indent-typealias-body ()
  "Typealias body is indented when split across lines."
  (pkl-ts-mode-test-indent
   "\
typealias Duration =
Int|Float
"
   "\
typealias Duration =
  Int|Float
"))

(defun pkl-ts-mode-test-scan-lists (source pos)
  "Insert SOURCE, propertize, scan-lists backward/forward from POS.
Return (OPEN-POS . CLOSE-POS) of the enclosing parens."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (syntax-propertize (point-max))
    (cons (scan-lists pos -1 1)
          (scan-lists pos 1 1))))

(ert-deftest pkl-ts-mode-scan-lists-interpolation ()
  "Parens inside \\(...) interpolation are visible to scan-lists."
  ;; x = "hello \(name)"
  ;; Positions:  5678901234567890
  ;; \=12, (=13, )=18, "=19
  (let ((result (pkl-ts-mode-test-scan-lists
                 "x = \"hello \\(name)\"" 15)))
    (should (equal (car result) 13))    ; ( found
    (should (equal (cdr result) 19))))  ; ) found

(ert-deftest pkl-ts-mode-scan-lists-interpolation-adjacent ()
  "Adjacent interpolations each have visible parens."
  ;; x = "\(a)\(b)"
  (let ((r1 (pkl-ts-mode-test-scan-lists "x = \"\\(a)\\(b)\"" 8))
        (r2 (pkl-ts-mode-test-scan-lists "x = \"\\(a)\\(b)\"" 12)))
    (should (equal (car r1) 7))
    (should (equal (car r2) 11))
    (should (equal (cdr r1) 10))
    (should (equal (cdr r2) 14))))

(ert-deftest pkl-ts-mode-scan-lists-interpolation-custom-delimiters ()
  "Parens inside interpolations with custom delimiters are visible to scan-lists."
  (let ((r1 (pkl-ts-mode-test-scan-lists "x = #\"\\#(a)\\(b)\"#" 10))
        (r2 (pkl-ts-mode-test-scan-lists "x = #\"\\#(a)\\(b)\"#" 14)))
    (should (equal (car r1) 9))
    (should (equal (car r2) 13))
    (should (equal (cdr r1) 12))
    (should (equal (cdr r2) 16))))

;;; --- Font-lock: string interpolation ---

(defun pkl-ts-mode-test-faces (source)
  "Insert SOURCE, fontify, return list of (START END FACE) spans."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (font-lock-ensure)
    (let (result pos)
      (setq pos (point-min))
      (while (< pos (point-max))
        (let ((face (get-text-property pos 'face))
              (next (next-single-property-change pos 'face nil (point-max))))
          (when face
            (push (list pos next face) result))
          (setq pos next)))
      (nreverse result))))

(defun pkl-ts-mode-test-face-at (source offset)
  "Return the face at OFFSET (1-based) after fontifying SOURCE."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (font-lock-ensure)
    (get-text-property offset 'face)))

(ert-deftest pkl-ts-mode-font-lock-string-no-interpolation ()
  "Plain string without interpolation is entirely string-faced."
  (let ((faces (pkl-ts-mode-test-faces "x = \"hello world\"")))
    ;; Property name "x"
    (should (cl-some (lambda (f) (eq (nth 2 f) 'font-lock-property-name-face)) faces))
    ;; All string-related spans should be font-lock-string-face
    (let ((string-spans (cl-remove-if-not
                         (lambda (f) (eq (nth 2 f) 'font-lock-string-face))
                         faces)))
      (should (> (length string-spans) 0)))))

(ert-deftest pkl-ts-mode-font-lock-interpolation-delimiters ()
  "Interpolation delimiters \\( and ) get escape face, not string face."
  ;; "hello \(name) world"
  ;; 123456789...
  (let* ((src "x = \"hello \\(name) world\""))
    ;; \( should be escape face
    (should (eq (pkl-ts-mode-test-face-at src 12) 'font-lock-escape-face))
    ;; ) should be escape face
    (should (eq (pkl-ts-mode-test-face-at src 18) 'font-lock-escape-face))
    ;; "name" should NOT be string face
    (should (not (eq (pkl-ts-mode-test-face-at src 14) 'font-lock-string-face)))
    ;; Surrounding text is still string face
    (should (eq (pkl-ts-mode-test-face-at src 6) 'font-lock-string-face))
    (should (eq (pkl-ts-mode-test-face-at src 19) 'font-lock-string-face))
    ;; Quotes are string face
    (should (eq (pkl-ts-mode-test-face-at src 5) 'font-lock-string-face))
    (should (eq (pkl-ts-mode-test-face-at src 25) 'font-lock-string-face))))

(ert-deftest pkl-ts-mode-font-lock-interpolation-custom-delimiters ()
  "Interpolation in #\"...\"# strings is fontified correctly."
  ;; x = #"hello \#(name) world"#
  ;; 1234567890123456789012345678
  (let* ((src "x = #\"hello \\#(name) world\"#"))
    ;; #" opening delimiter is string face
    (should (eq (pkl-ts-mode-test-face-at src 5) 'font-lock-string-face))
    ;; Literal text is string face
    (should (eq (pkl-ts-mode-test-face-at src 7) 'font-lock-string-face))
    ;; \#( should be escape face
    (should (eq (pkl-ts-mode-test-face-at src 13) 'font-lock-escape-face))
    ;; "name" should NOT be string face
    (should (not (eq (pkl-ts-mode-test-face-at src 16) 'font-lock-string-face)))
    ;; ) should be escape face
    (should (eq (pkl-ts-mode-test-face-at src 20) 'font-lock-escape-face))
    ;; "# closing delimiter is string face
    (should (eq (pkl-ts-mode-test-face-at src 27) 'font-lock-string-face))))

(ert-deftest pkl-ts-mode-font-lock-multiline-interpolation ()
  "Interpolation in multiline strings is fontified correctly."
  (let* ((src "x = \"\"\"\nhello \\(name) world\n\"\"\""))
    ;; \"\"\" opening is string face
    (should (eq (pkl-ts-mode-test-face-at src 5) 'font-lock-string-face))
    ;; Literal text is string face
    (should (eq (pkl-ts-mode-test-face-at src 9) 'font-lock-string-face))
    ;; \( is escape face
    (should (eq (pkl-ts-mode-test-face-at src 15) 'font-lock-escape-face))
    ;; "name" is NOT string face
    (should (not (eq (pkl-ts-mode-test-face-at src 17) 'font-lock-string-face)))
    ;; ) is escape face
    (should (eq (pkl-ts-mode-test-face-at src 21) 'font-lock-escape-face))
    ;; \"\"\" closing is string face
    (should (eq (pkl-ts-mode-test-face-at src 29) 'font-lock-string-face))))

;;; --- Fill / reflow ---

(defun pkl-ts-mode-test-fill-region (source expected)
  "Insert SOURCE, fill-region the whole buffer, compare with EXPECTED."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (fill-region (point-min) (point-max))
    (should (equal (buffer-string) expected))))

(ert-deftest pkl-ts-mode-fill-region-line-comment ()
  "fill-region reflows a long // comment preserving the prefix."
  (pkl-ts-mode-test-fill-region
   "// This is a very long comment that should be wrapped because it exceeds the fill column which is typically set to seventy characters.\n"
   "// This is a very long comment that should be wrapped because it
// exceeds the fill column which is typically set to seventy
// characters.\n"))

(ert-deftest pkl-ts-mode-fill-region-doc-comment ()
  "fill-region reflows a long /// doc comment preserving the prefix."
  (pkl-ts-mode-test-fill-region
   "/// This is a very long doc comment that should be wrapped because it exceeds the fill column which is typically set to seventy characters.\n"
   "/// This is a very long doc comment that should be wrapped because it
/// exceeds the fill column which is typically set to seventy
/// characters.\n"))

(provide 'pkl-ts-mode-tests)

;;; pkl-ts-mode-tests.el ends here
