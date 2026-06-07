;;; pkl-ts-mode-eglot.el --- Eglot support for Pkl -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Simon Génier

;; Author: Simon Génier <simon.genier@protonmail.com>
;; Assisted-by: Claude:claude-opus-4-8
;; Maintainer: Simon Génier <simon.genier@protonmail.com>
;; Keywords: languages
;; URL: https://github.com/in-the-mood-for-mov/pkl-ts-mode
;; SPDX-License-Identifier: GPL-3.0-or-later

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

(require 'cl-generic)
(require 'eglot)
(require 'json)

(defgroup pkl-ts-mode-eglot nil
  "Eglot support for Pkl."
  :group 'pkl
  :prefix "pkl-ts-mode-eglot-")

(defcustom pkl-ts-mode-eglot-server-version 'latest
  "Version of pkl-lsp to download.
The symbol `latest' means the most recent GitHub release."
  :type '(choice (const :tag "Latest" latest) string)
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

(defcustom pkl-ts-mode-eglot-pkl-path nil
  "Path to the Pkl CLI executable.
When nil, `pkl-ts-mode-eglot' looks for pkl in `exec-path'."
  :type '(choice (const :tag "Auto-detect" nil) file)
  :group 'pkl-ts-mode-eglot)

(defclass pkl-ts-mode-eglot-server (eglot-lsp-server) ()
  :documentation "Eglot server class for pkl-lsp.")

(defconst pkl-ts-mode-eglot--scope-uri "Pkl"
  "Scope identifier pkl-lsp sends in workspace/configuration requests.
The pkl-lsp server uses the bare string \"Pkl\" rather than a real URI,
so requests with this scope must bypass `eglot-uri-to-path'.")

(defun pkl-ts-mode-eglot--jar-path ()
  "Return the full path to the pkl-lsp JAR."
  (expand-file-name "pkl-lsp.jar" pkl-ts-mode-eglot-install-dir))

(defun pkl-ts-mode-eglot--download-url (version)
  "Return the GitHub release download URL for VERSION."
  (format "https://github.com/apple/pkl-lsp/releases/download/%s/pkl-lsp-%s.jar"
          version version))

(defun pkl-ts-mode-eglot--fetch-latest-version ()
  "Fetch the latest pkl-lsp release version from GitHub."
  (require 'url)
  (require 'json)
  (with-temp-buffer
    (url-insert-file-contents
     "https://api.github.com/repos/apple/pkl-lsp/releases/latest")
    (let ((json-object-type 'alist))
      (alist-get 'tag_name (json-read)))))

(defun pkl-ts-mode-eglot--resolve-version ()
  "Return the version string to download."
  (if (eq pkl-ts-mode-eglot-server-version 'latest)
      (pkl-ts-mode-eglot--fetch-latest-version)
    pkl-ts-mode-eglot-server-version))

(defun pkl-ts-mode-eglot--ensure-server ()
  "Return the path to the pkl-lsp JAR, downloading if needed."
  (require 'url)
  (let ((jar (pkl-ts-mode-eglot--jar-path)))
    (unless (file-exists-p jar)
      (let ((version (pkl-ts-mode-eglot--resolve-version)))
        (make-directory pkl-ts-mode-eglot-install-dir t)
        (message "Downloading pkl-lsp %s..." version)
        (url-copy-file (pkl-ts-mode-eglot--download-url version) jar)
        (message "Downloaded pkl-lsp %s." version)))
    jar))

(defun pkl-ts-mode-eglot--pkl-path ()
  "Return the configured or detected Pkl CLI path."
  (or pkl-ts-mode-eglot-pkl-path
      (executable-find "pkl")))

(defun pkl-ts-mode-eglot--configuration-value (item)
  "Return pkl-lsp configuration value for ITEM."
  (pcase (plist-get item :section)
    ("pkl.cli.path" (pkl-ts-mode-eglot--pkl-path))
    (_ nil)))

(cl-defmethod eglot-handle-request
  ((server pkl-ts-mode-eglot-server)
   (_method (eql workspace/configuration))
   &key items)
  "Handle Pkl-scoped config items and delegate the rest to Eglot."
  (apply #'vector
         (mapcar
          (lambda (item)
            (if (equal (plist-get item :scopeUri) pkl-ts-mode-eglot--scope-uri)
                (pkl-ts-mode-eglot--configuration-value item)
              ;; We can invoke cl-call-next-method multiple times, but this is
              ;; not a problem because there are few items in practice.
              (aref (cl-call-next-method
                     server 'workspace/configuration
                     :items (list item))
                    0)))
          items)))

(defun pkl-ts-mode-eglot--server-contact (&optional _interactive)
  "Eglot contact function for pkl-lsp.
Downloads the server JAR if needed, then returns the command to start it."
  (let ((jar (pkl-ts-mode-eglot--ensure-server)))
    `(,pkl-ts-mode-eglot-java-path
      ,@pkl-ts-mode-eglot-java-args
      "-jar" ,jar)))

;;;###autoload
(defun pkl-ts-mode-eglot-install-server ()
  "Download the pkl-lsp JAR, replacing any existing version."
  (interactive)
  (require 'url)
  (let* ((version (pkl-ts-mode-eglot--resolve-version))
         (jar (pkl-ts-mode-eglot--jar-path)))
    (make-directory pkl-ts-mode-eglot-install-dir t)
    (message "Downloading pkl-lsp %s..." version)
    (url-copy-file (pkl-ts-mode-eglot--download-url version) jar t)
    (message "pkl-lsp %s installed at %s" version jar)))

;;;###autoload
(defun pkl-ts-mode-eglot-init ()
  "Register pkl-lsp as the Eglot server for `pkl-ts-mode'."
  (add-to-list 'eglot-server-programs
               '(pkl-ts-mode pkl-ts-mode-eglot-server
                             . pkl-ts-mode-eglot--server-contact)))

(provide 'pkl-ts-mode-eglot)
;;; pkl-ts-mode-eglot.el ends here
