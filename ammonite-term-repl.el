;;; ammonite-term-repl.el --- Scala Ammonite REPL in term mode.

;; Copyright (C) 2018-2019 Wei Zhao

;; Author: zwild <judezhao@outlook.com>
;; Created: 2018-12-26T22:41:19+08:00
;; URL: https://github.com/zwild/ammonite-term-repl
;; Package-Requires: ((emacs "24.3") (s "1.12.0") (scala-mode "0.23"))
;; Version: 0.2
;; Keywords: processes, ammnite, term, scala

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.


;;; Commentary:
;; Usage
;; (add-hook 'scala-mode-hook
;;           (lambda ()
;;             (ammonite-term-repl-minor-mode t)))

;; You can modify your arguments by
;; (setq ammonite-term-repl-program-args '("-s" "--no-default-predef"))

;;; Code:
(require 'term)
(require 'comint)
(require 'scala-mode)
(require 's)
(require 'subr-x)

(defgroup ammonite-term-repl nil
  "A minor mode for a Ammonite REPL."
  :group 'scala)

(defcustom ammonite-term-repl-buffer-name "*Ammonite*"
  "Buffer name for ammonite."
  :type 'string
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-program "amm"
  "Program name for ammonite."
  :type 'string
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-program-args '()
  "Arguments for ammonite command."
  :type '(repeat string)
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-prompt-regex "^@ "
  "Regex for ammonite prompt."
  :type 'string
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-run-hook nil
  "Hook to run after starting an Ammonite REPL buffer."
  :type 'hook
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-predef-sc-filename "predef.sc"
  "'predef.sc' filename for ammonite."
  :type 'string
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-default-predef-dir "~/.ammonite"
  "The default dirtory of the 'predef.sc' file."
  :type 'string
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-auto-detect-predef-file t
  "Auto detect predef from project."
  :type 'boolean
  :group 'ammonite-term-repl)

(defcustom ammonite-term-repl-auto-config-mill-project t
  "Auto config mill project.
This will change `ammonite-term-repl-program' to mill
and `ammonite-term-repl-program-args' to '(-i foo.repl)."
  :type 'boolean
  :group 'ammonite-term-repl)

(defvar ammonite-term-repl-program-local-args '()
  "Local args for ammonite term repl program.")

(defun ammonite-term-repl-check-process ()
  "Check if there is an active ammonite process."
  (unless (comint-check-proc ammonite-term-repl-buffer-name)
    (error "Ammonite is not running")))

(defun ammonite-term-repl-code-first-line (code)
  "Get the first line of CODE."
  (s-trim (car-safe (s-split "\n" code))))

;;;###autoload
(defun ammonite-term-repl-send-defun ()
  "Send the definition to the ammonite buffer."
  (interactive)
  (ammonite-term-repl-check-process)
  (save-mark-and-excursion
    (let (start end)
      (scala-syntax:beginning-of-definition)
      (setq start (point))
      (scala-syntax:end-of-definition)
      (setq end (point))
      (let ((code (buffer-substring-no-properties start end)))
        (comint-send-string ammonite-term-repl-buffer-name code)
        (comint-send-string ammonite-term-repl-buffer-name "\n")
        (message
         (format "Sent: %s..." (ammonite-term-repl-code-first-line code)))))))

;;;###autoload
(defun ammonite-term-repl-send-region (start end)
  "Send the region to the ammonite buffer.
Argument START the start region.
Argument END the end region."
  (interactive "r")
  (ammonite-term-repl-check-process)
  (let ((code (buffer-substring-no-properties start end)))
    (comint-send-string ammonite-term-repl-buffer-name "{\n")
    (comint-send-string ammonite-term-repl-buffer-name code)
    (comint-send-string ammonite-term-repl-buffer-name "\n}")
    (comint-send-string ammonite-term-repl-buffer-name "\n")
    (message
     (format "Sent: %s..." (ammonite-term-repl-code-first-line code)))))

;;;###autoload
(defun ammonite-term-repl-send-buffer ()
  "Send the buffer to the ammonite buffer."
  (interactive)
  (save-mark-and-excursion
    (goto-char (point-min))
    (re-search-forward "^package .+\n+" nil t)
    (ammonite-term-repl-send-region (point) (point-max))))

;;;###autoload
(defun ammonite-term-repl-load-file (file-name)
  "Load a file to the ammonite buffer.
Argument FILE-NAME the file name."
  (interactive (comint-get-source "Load Scala file: " nil '(scala-mode) t))
  (comint-check-source file-name)
  (with-temp-buffer
    (insert-file-contents file-name)
    (ammonite-term-repl-send-buffer)))

;;;###autoload
(defun ammonite-term-repl ()
  "Run an Ammonite REPL."
  (interactive)
  (unless (executable-find ammonite-term-repl-program)
    (error (format "%s is not found." ammonite-term-repl-program)))

  (unless (comint-check-proc ammonite-term-repl-buffer-name)
    (ignore-errors (kill-buffer ammonite-term-repl-buffer-name))

    (setq ammonite-term-repl-program-local-args ammonite-term-repl-program-args)

    (when-let ((_ ammonite-term-repl-auto-detect-predef-file)
               (path (or (locate-dominating-file default-directory ammonite-term-repl-predef-sc-filename)
                         ammonite-term-repl-default-predef-dir))
               (file (expand-file-name ammonite-term-repl-predef-sc-filename path)))
      (setq ammonite-term-repl-program-local-args
            (append ammonite-term-repl-program-args `("-p" ,file))))

    (when-let ((_ ammonite-term-repl-auto-config-mill-project)
               (target "build.sc")
               (path (locate-dominating-file default-directory target))
               (file (expand-file-name target path)))
      (setq default-directory path)
      (setq-local ammonite-term-repl-program (if path "mill" "amm"))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (let ((res))
          (while (re-search-forward "^object[ ]+\\([^ ]+\\)[ ]+extends" nil t)
            (add-to-list 'res (match-string 1) t))
          (let* ((project (completing-read "Project: " res))
                 (full (concat project ".repl")))
            (setq ammonite-term-repl-program-local-args
                  (append ammonite-term-repl-program-args `("-i" ,full)))))))

    (message (format "Run: %s %s"
                     ammonite-term-repl-program
                     (s-join " " ammonite-term-repl-program-local-args)))

    (with-current-buffer
        (apply 'term-ansi-make-term
               ammonite-term-repl-buffer-name
               ammonite-term-repl-program
               nil
               ammonite-term-repl-program-local-args)
      (term-char-mode)
      (term-set-escape-char ?\C-x)
      (setq-local term-prompt-regexp ammonite-term-repl-prompt-regex)
      (setq-local term-scroll-show-maximum-output t)
      (setq-local term-scroll-to-bottom-on-output t)
      (run-hooks 'ammonite-term-repl-run-hook)))

  (pop-to-buffer ammonite-term-repl-buffer-name))

;;;###autoload
(defalias 'run-ammonite 'ammonite-term-repl)

(defun ammonite-term-repl--send-string (string)
  "Send the code to the ammonite buffer.
Argument STRING the code to send."
  (ammonite-term-repl-check-process)
  (comint-send-string ammonite-term-repl-buffer-name "{\n")
  (comint-send-string ammonite-term-repl-buffer-name string)
  (comint-send-string ammonite-term-repl-buffer-name "\n}")
  (comint-send-string ammonite-term-repl-buffer-name "\n")
  (message
   (format "Sent: %s..." (ammonite-term-repl-code-first-line string))))

;;;###autoload
(defun ammonite-term-repl-import-ivy-dependencies-from-sbt ()
  "Try to import ivy dependencies from sbt file.
Currently only form like
libraryDependencies += \"com.typesafe.akka\" %% \"akka-actor\" % \"2.5.21\"
is available."
  (interactive)
  (when-let* ((file-name "build.sbt")
              (path (locate-dominating-file default-directory file-name))
              (file (concat path file-name)))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let ((regex "libraryDependencies[ ]+\\+=[ ]+\"\\(.+?\\)\"[ ]+%\\{1,2\\}[ ]+\"\\(.+?\\)\"[ ]+%\\{1,2\\}[ ]+\"\\(.+?\\)\"")
            (res))
        (while (re-search-forward regex nil t)
          (add-to-list
           'res
           (format "import $ivy.`%s::%s:%s`" (match-string 1) (match-string 2) (match-string 3))
           t))
        (ammonite-term-repl--send-string (s-join "\n" res))))))

(defvar ammonite-term-repl-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-`") 'ammonite-term-repl)
    (define-key map (kbd "C-c C-z") 'ammonite-term-repl)
    (define-key map (kbd "C-c C-e") 'ammonite-term-repl-send-defun)
    (define-key map (kbd "C-c C-r") 'ammonite-term-repl-send-region)
    (define-key map (kbd "C-c C-b") 'ammonite-term-repl-send-buffer)
    (define-key map (kbd "C-c C-l") 'ammonite-term-repl-load-file)
    map)
  "Keymap while function ‘ammonite-term-repl-minor-mode’ is active.")

;;;###autoload
(define-minor-mode ammonite-term-repl-minor-mode
  "Minor mode for interacting with an Ammonite REPL."
  :keymap ammonite-term-repl-minor-mode-map)

(provide 'ammonite-term-repl)

;;; ammonite-term-repl.el ends here
