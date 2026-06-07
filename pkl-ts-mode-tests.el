;;; pkl-ts-mode-tests.el --- Tests for pkl-ts-mode -*- lexical-binding: t -*-

;;; Commentary:

;; Tests for pkl-ts-mode covering indentation, syntax, and font-lock.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'pkl-ts-mode)
(require 'pkl-ts-mode-eglot)

(unless (locate-library "evil")
  (defvar pkl-ts-mode-test-evil-stub t)

  (defmacro evil-define-text-object (name args &rest body)
    `(defun ,name ,args ,@body))

  (defun evil-define-key (_states keymap &rest bindings)
    (while bindings
      (define-key keymap (kbd (pop bindings)) (pop bindings))))

  (defun evil-range (beg end &rest properties)
    (list beg end properties))

  (defun evil-range-beginning (range)
    (car range))

  (defun evil-range-end (range)
    (cadr range))

  (provide 'evil))

(require 'pkl-ts-mode-evil)

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

;;; --- Evil text objects ---

(defun pkl-ts-mode-test-text-object (source point-text text-object)
  "Return selected text from TEXT-OBJECT in SOURCE at POINT-TEXT."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (goto-char (point-min))
    (search-forward point-text)
    (let ((range (funcall text-object nil)))
      (buffer-substring-no-properties
       (evil-range-beginning range)
       (evil-range-end range)))))

(ert-deftest pkl-ts-mode-evil-comment-line-outer ()
  "Outer comment text object includes contiguous line comment prefixes."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "first = 1\n// one\n// two\nsecond = 2\n"
     "two"
     #'pkl-ts-mode-outer-comment)
    "// one\n// two")))

(ert-deftest pkl-ts-mode-evil-comment-line-inner ()
  "Inner comment text object leaves one line comment prefix outside."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "first = 1\n// one\n// two\nsecond = 2\n"
     "two"
     #'pkl-ts-mode-inner-comment)
    "one\n// two")))

(ert-deftest pkl-ts-mode-evil-comment-doc-inner ()
  "Inner comment text object handles doc comment prefixes."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "/// one\n/// two\nresult = 42\n"
     "two"
     #'pkl-ts-mode-inner-comment)
    "one\n/// two")))

(ert-deftest pkl-ts-mode-evil-comment-block-inner ()
  "Inner comment text object excludes block comment delimiters."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "/* one */\nresult = 42\n"
     "one"
     #'pkl-ts-mode-inner-comment)
    " one ")))

(ert-deftest pkl-ts-mode-evil-comment-paragraph-clamps-to-code ()
  "Inner paragraph stays within the comment when code follows immediately."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "// one two three\nfoo = 1\n"
     "two"
     #'pkl-ts-mode-inner-paragraph)
    "// one two three")))

(ert-deftest pkl-ts-mode-evil-comment-paragraph-splits-on-empty-comment ()
  "Empty comment lines separate paragraphs within a comment run."
  (let ((source "// p1 a\n// p1 b\n//\n// p2 a\nresult = 1\n"))
    (should
     (equal
      (pkl-ts-mode-test-text-object source "p2 a"
                                    #'pkl-ts-mode-inner-paragraph)
      "// p2 a"))
    (should
     (equal
      (pkl-ts-mode-test-text-object source "p1 b"
                                    #'pkl-ts-mode-inner-paragraph)
      "// p1 a\n// p1 b"))))

(ert-deftest pkl-ts-mode-evil-comment-paragraph-outer-includes-separator ()
  "Outer paragraph swallows the trailing empty comment line."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "// p1 a\n//\n// p2 a\nx = 1\n"
     "p1 a"
     #'pkl-ts-mode-outer-paragraph)
    "// p1 a\n//")))

(ert-deftest pkl-ts-mode-evil-comment-paragraph-block-splits-on-blank ()
  "Block comment paragraphs split on blank lines and stay in the block."
  (should
   (equal
    (pkl-ts-mode-test-text-object
     "/* a\n   b\n\n   c */\nx = 1\n"
     "a"
     #'pkl-ts-mode-inner-paragraph)
    "/* a\n   b")))

(ert-deftest pkl-ts-mode-evil-text-object-keybindings ()
  "Evil text object keys use c for comments, k for classes, and t for strings."
  (skip-unless (bound-and-true-p pkl-ts-mode-test-evil-stub))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "ac"))
              #'pkl-ts-mode-outer-comment))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "ic"))
              #'pkl-ts-mode-inner-comment))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "ap"))
              #'pkl-ts-mode-outer-paragraph))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "ip"))
              #'pkl-ts-mode-inner-paragraph))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "ak"))
              #'pkl-ts-mode-outer-class))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "ik"))
              #'pkl-ts-mode-inner-class))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "at"))
              #'pkl-ts-mode-outer-string))
  (should (eq (lookup-key pkl-ts-mode-map (kbd "it"))
              #'pkl-ts-mode-inner-string)))

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

;;; --- Eglot ---

(ert-deftest pkl-ts-mode-eglot-server-contact-builds-java-command ()
  "pkl-lsp starts with the configured Java command."
  (cl-letf (((symbol-function 'pkl-ts-mode-eglot--ensure-server)
             (lambda () "/tmp/pkl-lsp.jar")))
    (let ((pkl-ts-mode-eglot-java-path "java")
          (pkl-ts-mode-eglot-java-args '("-Xmx512m")))
      (should (equal (pkl-ts-mode-eglot--server-contact)
                     '("java" "-Xmx512m" "-jar" "/tmp/pkl-lsp.jar"))))))

(defun pkl-ts-mode-tests--make-eglot-server ()
  "Build a `pkl-ts-mode-eglot-server' backed by a throwaway cat process."
  (make-instance
   'pkl-ts-mode-eglot-server
   :name "pkl-test"
   :notification-dispatcher #'ignore
   :request-dispatcher #'ignore
   :process (lambda ()
              (start-process "pkl-test" nil "cat"))))

(ert-deftest pkl-ts-mode-eglot-configuration-handles-pkl-scope-uri ()
  "pkl-lsp's documented Pkl scope name does not need to be a URI."
  (let ((server (pkl-ts-mode-tests--make-eglot-server)))
    (unwind-protect
        (cl-letf (((symbol-function 'eglot-uri-to-path)
                   (lambda (_uri) (error "invalid URI")))
                  ((symbol-function 'pkl-ts-mode-eglot--pkl-path)
                   (lambda () "/opt/pkl/bin/pkl")))
          (should (equal (eglot-handle-request
                          server 'workspace/configuration
                          :items '((:scopeUri "Pkl"
                                     :section "pkl.cli.path")))
                        ["/opt/pkl/bin/pkl"])))
      (delete-process (jsonrpc--process server)))))

(ert-deftest pkl-ts-mode-eglot-configuration-delegates-other-scopes ()
  "Non-Pkl configuration items are delegated and merged by original order."
  (let ((server (pkl-ts-mode-tests--make-eglot-server)))
    (unwind-protect
        ;; `eglot--workspace-configuration-plist' is private to Eglot; if
        ;; upstream renames it this stub will need to follow.
        (cl-letf (((symbol-function 'pkl-ts-mode-eglot--pkl-path)
                   (lambda () "/opt/pkl/bin/pkl"))
                  ((symbol-function 'eglot--workspace-configuration-plist)
                   (lambda (_server _path)
                     '(:other.one "one-value"
                       :other.two "two-value"))))
          (should (equal (eglot-handle-request
                          server 'workspace/configuration
                          :items '((:scopeUri "file:///tmp/example.pkl"
                                     :section "other.one")
                                    (:scopeUri "Pkl"
                                     :section "pkl.cli.path")
                                    (:scopeUri "file:///tmp/example.pkl"
                                     :section "other.two")))
                         ["one-value" "/opt/pkl/bin/pkl" "two-value"])))
      (delete-process (jsonrpc--process server)))))

;;; --- Imenu ---

(defun pkl-ts-mode-tests--imenu (source)
  "Return the Imenu index alist for SOURCE in `pkl-ts-mode'."
  (with-temp-buffer
    (pkl-ts-mode)
    (insert source)
    (funcall imenu-create-index-function)))

(defconst pkl-ts-mode-tests--imenu-source
  "class Server {
  port: Int = 8080
  function url(): String = \"x\"
}

typealias Id = Int

name = \"app\"

function greet(x: String): String = x

server {
  host = \"localhost\"
}
")

(defun pkl-ts-mode-tests--imenu-names (entries)
  "Collect entry names from imenu ENTRIES, recursing into submenus.
The treesit \" \" self-markers (see `treesit--simple-imenu-1') are skipped."
  (let (names)
    (dolist (entry entries)
      (unless (equal (car entry) " ")
        (push (car entry) names))
      (unless (markerp (cdr entry))      ; a submenu, not a leaf marker
        (setq names (nconc (pkl-ts-mode-tests--imenu-names (cdr entry))
                           names))))
    names))

(ert-deftest pkl-ts-mode-imenu-categories ()
  "Imenu groups Pkl symbols by category and finds the right names.
Object members nested in a property (host under server) are included."
  (let* ((index (pkl-ts-mode-tests--imenu pkl-ts-mode-tests--imenu-source))
         (names (lambda (cat)
                  (sort (pkl-ts-mode-tests--imenu-names (cdr (assoc cat index)))
                        #'string<))))
    (should (equal (funcall names "Class") '("Server")))
    (should (equal (funcall names "Type") '("Id")))
    (should (equal (funcall names "Method") '("greet" "url")))
    (should (equal (funcall names "Property")
                   '("host" "name" "port" "server")))))

(ert-deftest pkl-ts-mode-imenu-positions ()
  "Imenu entries point at the start of the corresponding definition."
  ;; Build and query the index in the same live buffer; the markers are
  ;; buffer-local and would dangle if the buffer were killed first.
  (with-temp-buffer
    (pkl-ts-mode)
    (insert pkl-ts-mode-tests--imenu-source)
    (let ((index (funcall imenu-create-index-function)))
      (goto-char (cdr (assoc "Server" (cdr (assoc "Class" index)))))
      (should (looking-at-p "class Server"))
      (goto-char (cdr (assoc "greet" (cdr (assoc "Method" index)))))
      (should (looking-at-p "function greet")))))

;;; --- auto-mode-alist ---

(defun pkl-ts-mode-tests--auto-mode (file)
  "Return the major mode `auto-mode-alist' selects for FILE."
  (cdr (cl-find-if (lambda (entry) (string-match-p (car entry) file))
                   auto-mode-alist)))

(ert-deftest pkl-ts-mode-auto-mode-alist ()
  "Pkl file names map to `pkl-ts-mode', including the extensionless PklProject."
  ;; Registered unconditionally, so this holds regardless of grammar status.
  (should (eq (pkl-ts-mode-tests--auto-mode "foo.pkl") 'pkl-ts-mode))
  (should (eq (pkl-ts-mode-tests--auto-mode "/path/to/foo.pcf") 'pkl-ts-mode))
  (should (eq (pkl-ts-mode-tests--auto-mode "/path/to/PklProject") 'pkl-ts-mode))
  (should (eq (pkl-ts-mode-tests--auto-mode "PklProject") 'pkl-ts-mode))
  ;; Does not over-match similarly named files.
  (should-not (eq (pkl-ts-mode-tests--auto-mode "/path/MyPklProject") 'pkl-ts-mode))
  (should-not (eq (pkl-ts-mode-tests--auto-mode "/path/PklProject.txt") 'pkl-ts-mode)))

(provide 'pkl-ts-mode-tests)

;;; pkl-ts-mode-tests.el ends here
