;;; pkl-ts-mode-evil.el --- Evil text objects for Pkl -*- lexical-binding: t -*-

;;; Commentary:

;; Evil integration for pkl-ts-mode.  Provides tree-sitter powered text
;; objects for classes, objects, methods, and strings.
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

(evil-define-text-object pkl-ts-mode-outer-class (count &optional _beg _end _type)
  "Select around a class."
  (pkl-ts-mode--text-object-range '((clazz) @cap)))

(evil-define-text-object pkl-ts-mode-inner-class (count &optional _beg _end _type)
  "Select inner class body."
  (pkl-ts-mode--shrink-range 1
   (pkl-ts-mode--text-object-range '((clazz (classBody) @cap)))))

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
  "ac" #'pkl-ts-mode-outer-class
  "ic" #'pkl-ts-mode-inner-class
  "ae" #'pkl-ts-mode-outer-object
  "ie" #'pkl-ts-mode-inner-object
  "af" #'pkl-ts-mode-outer-method
  "if" #'pkl-ts-mode-inner-method
  "at" #'pkl-ts-mode-outer-string
  "it" #'pkl-ts-mode-inner-string)

(provide 'pkl-ts-mode-evil)

;;; pkl-ts-mode-evil.el ends here
