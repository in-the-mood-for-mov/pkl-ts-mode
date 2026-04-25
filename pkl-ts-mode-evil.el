;;; pkl-ts-mode-evil.el --- Evil text objects for Pkl -*- lexical-binding: t -*-

;;; Commentary:

;; Evil integration for pkl-ts-mode.  Provides tree-sitter powered text
;; objects for classes, comments, objects, methods, and strings.
;;
;; This file is loaded automatically when evil is available.
;; Do not require it directly.

;;; Code:

(require 'treesit)
(require 'evil)

(defun pkl-ts-mode--capture-at-point (query capture-name)
  "Run QUERY on the buffer and return the innermost CAPTURE-NAME containing point."
  (let* ((root (treesit-buffer-root-node 'pkl))
         (captures (treesit-query-capture root query))
         (pos (point))
         (best nil))
    (dolist (capture captures best)
      (when (and (eq (car capture) capture-name)
                 (<= (treesit-node-start (cdr capture)) pos)
                 (>= (treesit-node-end (cdr capture)) pos)
                 (or (null best)
                     (< (- (treesit-node-end (cdr capture))
                           (treesit-node-start (cdr capture)))
                        (- (treesit-node-end best)
                           (treesit-node-start best)))))
        (setq best (cdr capture))))))

(defun pkl-ts-mode--text-object-range (query)
  "Return an evil range for the innermost QUERY capture containing point."
  (when-let ((node (pkl-ts-mode--capture-at-point query 'cap)))
    (evil-range (treesit-node-start node) (treesit-node-end node))))

(defun pkl-ts-mode--shrink-range (offset range)
  "Shrink RANGE by OFFSET characters on each side.  Return nil if RANGE is nil."
  (when range
    (evil-range (+ (evil-range-beginning range) offset)
                (- (evil-range-end range) offset))))

(defun pkl-ts-mode--line-comment-at-point-p ()
  "Return non-nil when point is at a Pkl line or doc comment."
  (looking-at-p "///?"))

(defun pkl-ts-mode--line-comment-prefix-end (pos)
  "Return the end of the line comment prefix at POS."
  (save-excursion
    (goto-char pos)
    (when (looking-at "///?[ \t]?")
      (match-end 0))))

(defun pkl-ts-mode--line-comment-range (node inner)
  "Return an evil range for the contiguous line-comment run around NODE.
When INNER is non-nil, start after the first comment prefix so deleting the
range leaves one leading prefix for multiline comment runs."
  (save-excursion
    (let (start end)
      (goto-char (treesit-node-start node))
      (back-to-indentation)
      (setq start (point))
      (while (and (= (forward-line -1) 0)
                  (progn
                    (back-to-indentation)
                    (pkl-ts-mode--line-comment-at-point-p)))
        (setq start (point)))

      (goto-char (treesit-node-start node))
      (end-of-line)
      (setq end (point))
      (while (and (= (forward-line 1) 0)
                  (progn
                    (back-to-indentation)
                    (pkl-ts-mode--line-comment-at-point-p)))
        (end-of-line)
        (setq end (point)))

      (evil-range (if inner
                      (or (pkl-ts-mode--line-comment-prefix-end start) start)
                    start)
                  end))))

(defun pkl-ts-mode--block-comment-range (node inner)
  "Return an evil range for block comment NODE.
When INNER is non-nil, exclude the opening and closing delimiters."
  (let ((start (treesit-node-start node))
        (end (treesit-node-end node)))
    (evil-range (if inner (min (+ start 2) end) start)
                (if inner (max start (- end 2)) end))))

(defun pkl-ts-mode--comment-range (inner)
  "Return an evil range for the comment at point.
When INNER is non-nil, leave the first comment delimiter outside the range."
  (when-let ((node (pkl-ts-mode--capture-at-point
                    '([(lineComment) (docComment) (blockComment)] @cap) 'cap)))
    (if (member (treesit-node-type node) '("lineComment" "docComment"))
        (pkl-ts-mode--line-comment-range node inner)
      (pkl-ts-mode--block-comment-range node inner))))

(evil-define-text-object pkl-ts-mode-outer-class (count &optional _beg _end _type)
  "Select around a class."
  (pkl-ts-mode--text-object-range '((clazz) @cap)))

(evil-define-text-object pkl-ts-mode-inner-class (count &optional _beg _end _type)
  "Select inner class body."
  (pkl-ts-mode--shrink-range 1
   (pkl-ts-mode--text-object-range '((clazz (classBody) @cap)))))

(evil-define-text-object pkl-ts-mode-outer-comment (count &optional _beg _end _type)
  "Select around a comment."
  (pkl-ts-mode--comment-range nil))

(evil-define-text-object pkl-ts-mode-inner-comment (count &optional _beg _end _type)
  "Select inner comment text."
  (pkl-ts-mode--comment-range t))

(evil-define-text-object pkl-ts-mode-outer-object (count &optional _beg _end _type)
  "Select around an object body."
  (pkl-ts-mode--text-object-range '((objectBody) @cap)))

(evil-define-text-object pkl-ts-mode-inner-object (count &optional _beg _end _type)
  "Select inner object body."
  (pkl-ts-mode--shrink-range 1
   (pkl-ts-mode--text-object-range '((objectBody) @cap))))

(evil-define-text-object pkl-ts-mode-outer-method (count &optional _beg _end _type)
  "Select around a method."
  (pkl-ts-mode--text-object-range '(([classMethod objectMethod]) @cap)))

(evil-define-text-object pkl-ts-mode-inner-method (count &optional _beg _end _type)
  "Select inner method body."
  (pkl-ts-mode--shrink-range 1
   (pkl-ts-mode--text-object-range '(([classMethod objectMethod] (objectBody) @cap)))))

(evil-define-text-object pkl-ts-mode-outer-string (count &optional _beg _end _type)
  "Select around a string literal."
  (pkl-ts-mode--text-object-range '([(slStringLiteralExpr) (mlStringLiteralExpr)] @cap)))

(evil-define-text-object pkl-ts-mode-inner-string (count &optional _beg _end _type)
  "Select inner string (excluding quotes)."
  (when-let ((node (pkl-ts-mode--capture-at-point
                    '([(slStringLiteralExpr) (mlStringLiteralExpr)] @cap) 'cap)))
    (pkl-ts-mode--shrink-range
     (if (equal (treesit-node-type node) "mlStringLiteralExpr") 3 1)
     (evil-range (treesit-node-start node) (treesit-node-end node)))))

(evil-define-key '(visual operator) pkl-ts-mode-map
  "ak" #'pkl-ts-mode-outer-class
  "ik" #'pkl-ts-mode-inner-class
  "ac" #'pkl-ts-mode-outer-comment
  "ic" #'pkl-ts-mode-inner-comment
  "ae" #'pkl-ts-mode-outer-object
  "ie" #'pkl-ts-mode-inner-object
  "af" #'pkl-ts-mode-outer-method
  "if" #'pkl-ts-mode-inner-method
  "at" #'pkl-ts-mode-outer-string
  "it" #'pkl-ts-mode-inner-string)

(provide 'pkl-ts-mode-evil)

;;; pkl-ts-mode-evil.el ends here
