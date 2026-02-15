;;; pkl-ts-mode-eglot.el --- Eglot support for Pkl -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Simon Génier

;;; Commentary:

;; Eglot integration for the Pkl language server (pkl-lsp).
;; Automatically downloads and manages the pkl-lsp JAR from GitHub releases.
;;
;; Usage:
;;   (require 'pkl-ts-mode-eglot)
;;   (pkl-ts-mode-eglot-init)
;;   ;; Then M-x eglot in a .pkl buffer, or:
;;   ;; (add-hook 'pkl-ts-mode-hook #'eglot-ensure)

;;; Code:

(defgroup pkl-ts-mode-eglot nil
  "Eglot support for Pkl."
  :group 'pkl
  :prefix "pkl-ts-mode-eglot-")

(defcustom pkl-ts-mode-eglot-server-version "0.5.3"
  "Version of pkl-lsp to download."
  :type 'string
  :group 'pkl-ts-mode-eglot)

(defcustom pkl-ts-mode-eglot-install-dir
  (expand-file-name "pkl-lsp" user-emacs-directory)
  "Directory where the pkl-lsp JAR is stored."
  :type 'directory
  :group 'pkl-ts-mode-eglot)

(defcustom pkl-ts-mode-eglot-java-path "java"
  "Path to the Java executable."
  :type 'string
  :group 'pkl-ts-mode-eglot)

(defcustom pkl-ts-mode-eglot-java-args nil
  "Extra arguments passed to the JVM when starting pkl-lsp."
  :type '(repeat string)
  :group 'pkl-ts-mode-eglot)

(defun pkl-ts-mode-eglot--jar-path ()
  "Return the full path to the versioned pkl-lsp JAR."
  (expand-file-name
   (format "pkl-lsp-%s.jar" pkl-ts-mode-eglot-server-version)
   pkl-ts-mode-eglot-install-dir))

(defun pkl-ts-mode-eglot--download-url ()
  "Return the GitHub release download URL for the configured version."
  (format "https://github.com/apple/pkl-lsp/releases/download/%s/pkl-lsp-%s.jar"
          pkl-ts-mode-eglot-server-version
          pkl-ts-mode-eglot-server-version))

(defun pkl-ts-mode-eglot--ensure-server ()
  "Download the pkl-lsp JAR if it is not already present."
  (require 'url)
  (let ((jar (pkl-ts-mode-eglot--jar-path)))
    (unless (file-exists-p jar)
      (make-directory pkl-ts-mode-eglot-install-dir t)
      (message "Downloading pkl-lsp %s..." pkl-ts-mode-eglot-server-version)
      (url-copy-file (pkl-ts-mode-eglot--download-url) jar)
      (message "Downloaded pkl-lsp %s." pkl-ts-mode-eglot-server-version))
    jar))

(defun pkl-ts-mode-eglot--server-contact (_interactive)
  "Eglot contact function for pkl-lsp.
Downloads the server JAR if needed, then returns the command to start it."
  (let ((jar (pkl-ts-mode-eglot--ensure-server)))
    `(,pkl-ts-mode-eglot-java-path
      ,@pkl-ts-mode-eglot-java-args
      "-jar" ,jar)))

;;;###autoload
(defun pkl-ts-mode-eglot-install-server ()
  "Download the pkl-lsp JAR."
  (interactive)
  (pkl-ts-mode-eglot--ensure-server)
  (message "pkl-lsp %s is installed at %s"
           pkl-ts-mode-eglot-server-version (pkl-ts-mode-eglot--jar-path)))

;;;###autoload
(defun pkl-ts-mode-eglot-init ()
  "Register pkl-lsp as the Eglot server for `pkl-ts-mode'."
  (require 'eglot)
  (add-to-list 'eglot-server-programs
               '(pkl-ts-mode . pkl-ts-mode-eglot--server-contact)))

(provide 'pkl-ts-mode-eglot)
;;; pkl-ts-mode-eglot.el ends here
