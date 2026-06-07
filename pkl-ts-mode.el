;;; pkl-ts-mode.el --- Tree-sitter support for Pkl -*- lexical-binding: t -*-

;; Copyright (C) 2025-2026 Simon Génier

;; Author: Simon Génier <simon.genier@protonmail.com>
;; Assisted-by: Claude:claude-opus-4-8
;; Maintainer: Simon Génier <simon.genier@protonmail.com>
;; Version: 0.4.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages
;; URL: https://github.com/in-the-mood-for-mov/pkl-ts-mode
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Major mode for editing Pkl configuration files, powered by tree-sitter.
;; Install the grammar via M-x treesit-install-language-grammar and selecting pkl.
;;
;;; Code:

(require 'treesit)

(defvar pkl-ts-mode--grammar-source
  '(pkl "https://github.com/apple/tree-sitter-pkl")
  "Tree-sitter grammar source for Pkl.")

(defun pkl-ts-mode--anonymous-node-p (node)
  "Return non-nil if NODE is an anonymous tree-sitter node."
  (not (treesit-node-check node 'named)))

(defvar pkl-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'pkl
   :feature 'comment
   '((lineComment) @font-lock-comment-face
     (blockComment) @font-lock-comment-face
     (docComment) @font-lock-doc-face)

   :language 'pkl
   :feature 'string
   '((slStringLiteralExpr
      _ @font-lock-string-face
      (:pred pkl-ts-mode--anonymous-node-p @font-lock-string-face))
     (slStringLiteralPart) @font-lock-string-face
     (mlStringLiteralExpr
      _ @font-lock-string-face
      (:pred pkl-ts-mode--anonymous-node-p @font-lock-string-face))
     (mlStringLiteralPart) @font-lock-string-face
     (stringConstant) @font-lock-string-face)

   :language 'pkl
   :feature 'interpolation
   :override t
   '((stringInterpolation
      _ @font-lock-escape-face
      (:pred pkl-ts-mode--anonymous-node-p @font-lock-escape-face)))

   :language 'pkl
   :feature 'escape-sequence
   :override t
   '((escapeSequence) @font-lock-escape-face)

   :language 'pkl
   :feature 'number
   '((intLiteralExpr) @font-lock-number-face
     (floatLiteralExpr) @font-lock-number-face)

   :language 'pkl
   :feature 'constant
   '((trueLiteralExpr) @font-lock-constant-face
     (falseLiteralExpr) @font-lock-constant-face
     (nullLiteralExpr) @font-lock-constant-face)

   :language 'pkl
   :feature 'keyword
   '(["import" "import*" "as" "is"
      "if" "else" "for" "when" "let"
      "in" "new" "read" "read*" "read?"
      "throw" "trace" "module" "open" "class"
      "typealias" "function" "extends" "amends"
      "abstract" "external" "local" "hidden"
      "fixed" "const" "out"] @font-lock-keyword-face)

   :language 'pkl
   :feature 'builtin
   '((moduleExpr) @font-lock-builtin-face
     (outerExpr) @font-lock-builtin-face
     (thisExpr) @font-lock-builtin-face
     (superAccessExpr "super" @font-lock-builtin-face))

   :language 'pkl
   :feature 'type
   '((clazz (identifier) @font-lock-type-face)
     (typeAlias (identifier) @font-lock-type-face)
     (declaredType (qualifiedIdentifier) @font-lock-type-face)
     (moduleClause (qualifiedIdentifier) @font-lock-type-face))

   :language 'pkl
   :feature 'function
   '((classMethod (methodHeader (identifier) @font-lock-function-name-face))
     (objectMethod (methodHeader (identifier) @font-lock-function-name-face)))

   :language 'pkl
   :feature 'property
   '((classProperty (identifier) @font-lock-property-name-face)
     (objectProperty (identifier) @font-lock-property-name-face))

   :language 'pkl
   :feature 'variable
   '((typedIdentifier (identifier) @font-lock-variable-name-face)
     (letExpr (typedIdentifier (identifier) @font-lock-variable-name-face)))

   :language 'pkl
   :feature 'annotation
   :override t
   '((annotation "@" @font-lock-preprocessor-face
                 (qualifiedIdentifier) @font-lock-preprocessor-face))

   :language 'pkl
   :feature 'operator
   '(["??" "=" "==" "!=" "<" "<=" ">" ">="
      "+" "-" "*" "/" "%" "**" "~/" "&&" "||"
      "!" "|>" "->"] @font-lock-operator-face)

   :language 'pkl
   :feature 'delimiter
   '(["," ":" "." "?."] @font-lock-punctuation-face)

   :language 'pkl
   :feature 'bracket
   '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face))
  "Font-lock settings for `pkl-ts-mode'.")

(defun pkl-ts-mode--ancestor-bol (n)
  "Return an anchor that walks N levels up from PARENT and returns its BOL."
  (lambda (_node parent &rest _)
    (dotimes (_ n)
      (setq parent (treesit-node-parent parent)))
    (save-excursion
      (goto-char (treesit-node-start parent))
      (back-to-indentation)
      (point))))

(defun pkl-ts-mode--grand-parent-bol (_node parent &rest _)
  (save-excursion
    (goto-char (treesit-node-start (treesit-node-parent parent)))
    (back-to-indentation)
    (point)))

(defun pkl-ts-mode--outermost-ancestor-bol (type)
  "Return an anchor that finds the outermost ancestor of TYPE.
Walks up the tree while the parent has the same TYPE, then returns
the beginning-of-line indentation of the outermost match."
  (lambda (_node parent &rest _)
    (while (equal (treesit-node-type (treesit-node-parent parent)) type)
      (setq parent (treesit-node-parent parent)))
    (save-excursion
      (goto-char (treesit-node-start parent))
      (back-to-indentation)
      (point))))

(defvar pkl-ts-mode--indent-rules
  `((pkl
     ((parent-is "module") column-0 0)
     ((node-is "}") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ;; When a declaration starts with a docComment, the node's start
     ;; shifts to the /// line. The sibling right after the docComment
     ;; must align with it, not be indented relative to parent-bol.
     ((query ((_ :anchor (docComment) :anchor _ @node))) prev-sibling 0)
     ((parent-is "^\\(?:class\\|object\\)\\(?:Body\\|Method\\|Property\\)$")
      parent-bol pkl-ts-mode-indent-offset)
     ((parent-is "typeAlias") parent-bol pkl-ts-mode-indent-offset)
     ((parent-is "parameterList") parent-bol pkl-ts-mode-indent-offset)
     ((parent-is "argumentList") parent-bol pkl-ts-mode-indent-offset)
     ((parent-is "typeArgumentList") parent-bol pkl-ts-mode-indent-offset)
     ((node-is "\\.") parent-bol pkl-ts-mode-indent-offset)
     ((node-is "\\?\\?")
      ,(pkl-ts-mode--outermost-ancestor-bol "nullCoalesceExpr")
      pkl-ts-mode-indent-offset)
     ((parent-is "blockComment") parent-bol 1)
     ;; Nested letExpr aligns with the outermost let.
     ((n-p-gp "letExpr" "letExpr" nil)
      ,(pkl-ts-mode--outermost-ancestor-bol "letExpr") 0)
     ((parent-is "letExpr") parent-bol pkl-ts-mode-indent-offset)
     ((node-is "else") parent-bol 0)
     ((parent-is "ifExpr") parent-bol pkl-ts-mode-indent-offset)
     ((parent-is "mlStringLiteralExpr") parent-bol 0)
     ;; Lines inside a multiline string are represented as a null node under a
     ;; mlStringLiteralPart. Anchor to the grandparent (msStringLiteralExpr)
     ;; whose position is stable during indent-region's batch computation,
     ;; and preserve the relative offset.
     ((parent-is "mlStringLiteralPart")
      grand-parent
      (lambda (_node parent bol &rest _)
        (let* ((string-literal-expr-node
                (treesit-node-start (treesit-node-parent parent)))
               (base-col (save-excursion
                           (goto-char string-literal-expr-node)
                           (back-to-indentation)
                           (current-column)))
               (bol-col (save-excursion
                          (goto-char bol)
                          (current-column))))
          (max 0 (- bol-col base-col)))))
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for Pkl.")

(defvar pkl-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Backslash is punctuation, not escape. Tree-sitter handles escape
    ;; sequences; making \ punctuation lets scan-lists see parens inside string
    ;; interpolations (\(expr), \#(expr), etc.).
    (modify-syntax-entry ?\\ "." table)
    table)
  "Syntax table for `pkl-ts-mode'.")

(defcustom pkl-ts-mode-indent-offset 2
  "Number of spaces for each indentation level in `pkl-ts-mode'."
  :type 'integer
  :group 'pkl)

(defun pkl-ts-mode--first-child-of-type (node type)
  "Return NODE's first direct child whose type is TYPE, or nil."
  (car (treesit-filter-child
        node (lambda (child) (equal (treesit-node-type child) type)))))

(defun pkl-ts-mode--imenu-name (node)
  "Return the declared name of NODE for an Imenu entry, or nil.
For methods the name lives inside the method header; otherwise it is the
node's first direct identifier child."
  (let* ((type (treesit-node-type node))
         (name-node
          (if (member type '("classMethod" "objectMethod"))
              (when-let ((header (pkl-ts-mode--first-child-of-type
                                  node "methodHeader")))
                (pkl-ts-mode--first-child-of-type header "identifier"))
            (pkl-ts-mode--first-child-of-type node "identifier"))))
    (and name-node (treesit-node-text name-node t))))

;;;###autoload
(define-derived-mode pkl-ts-mode prog-mode "Pkl"
  "Major mode for editing Pkl files, powered by tree-sitter."
  (unless (treesit-ready-p 'pkl)
    (user-error "Tree-sitter grammar for Pkl is not installed.
Install it with M-x treesit-install-language-grammar RET pkl RET"))

  (treesit-parser-create 'pkl)

  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local adaptive-fill-regexp "[ \t]*///?[ \t]*")
  (setq-local adaptive-fill-first-line-regexp adaptive-fill-regexp)

  (setq-local treesit-simple-indent-rules pkl-ts-mode--indent-rules)
  (setq-local treesit-font-lock-settings pkl-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword type constant number)
                (builtin function property variable annotation escape-sequence interpolation)
                (operator delimiter bracket)))

  (setq-local treesit-simple-imenu-settings
              '(("Class" "\\`clazz\\'" nil pkl-ts-mode--imenu-name)
                ("Type" "\\`typeAlias\\'" nil pkl-ts-mode--imenu-name)
                ("Method" "\\`\\(?:class\\|object\\)Method\\'" nil
                 pkl-ts-mode--imenu-name)
                ("Property" "\\`\\(?:class\\|object\\)Property\\'" nil
                 pkl-ts-mode--imenu-name)))

  ;; Reindent a line the moment its closing delimiter is typed, so an
  ;; over-indented "}", "]", or ")" snaps back to align with its parent
  ;; construct. Buffer-local, so electric indentation in other modes is
  ;; untouched.
  (setq-local electric-indent-chars
              (append "}])" electric-indent-chars))

  (when (boundp 'evil-shift-width)
    (setq-local evil-shift-width pkl-ts-mode-indent-offset))

  (treesit-major-mode-setup))

(add-to-list 'treesit-language-source-alist pkl-ts-mode--grammar-source)

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.pkl\\'" . pkl-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.pcf\\'" . pkl-ts-mode))
  (add-to-list 'auto-mode-alist '("\\(?:\\`\\|/\\)PklProject\\'" . pkl-ts-mode)))

(with-eval-after-load 'evil
  (require 'pkl-ts-mode-evil))

(provide 'pkl-ts-mode)

;;; pkl-ts-mode.el ends here
