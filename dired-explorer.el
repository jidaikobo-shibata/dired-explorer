;;; dired-explorer.el --- minor-mode provides Explorer like select file at dired. -*- coding: utf-8; lexical-binding: t; -*-
;; Original: http://homepage1.nifty.com/blankspace/emacs/dired.html
;; Original2: http://www.bookshelf.jp/soft/meadow_25.html#SEC286
;; Introduce and Supervise: rubikitch
;; Maintainer: jidaikobo-shibata
;; Contributions: syohex, Steve Purcell
;; Keywords: dired explorer
;; Package-Requires: ((cl-lib "0.5"))
;; Version: 0.6
;; git tag 0.6; git push --tags
;; for Emacs 24.5.1 - 26.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; [en]
;; This mode provides "Windows / Macintosh (Mac OS X) like file selection" for dired's buffer.
;; Move cursor by just pressing alphabet or number key.
;; And also it prohibits dired from opening many buffers.
;; of course, at this mode, cannot use dired's default keybind like "c".
;; You may use keybind that made of one alphabet, use with Meta (e.g. M-d).
;; toggle mode by ":".
;; rubikitch told me about this elisp's url at his school.
;; but I couldn't know who made this originally.
;;
;; [ja]
;; WindowsやMac OS Xのデフォルトのファイラのようなファイル選択をdiredで行います。
;; 英数字のキーを打鍵するだけで、diredでファイル／ディレクトリを選択します。
;; また、diredがたくさんのバッファを開きすぎることを抑止しています。
;; 当然ながら、このモードを有効にするとデフォルトのdiredのキーバインドが使えません。
;; diredのアルファベット一文字のキーバインドは基本的に"M-"にあて直しています。
;; モードの切り替えは":"で行ってください。
;; このelispは、るびきちさんが彼のEmacs塾で、僕にURLを教えてくれましたが、
;; 僕にはオリジナルの作者が誰かわからなかったので、URLだけ明示しています。

;;; Usage:
;; just write below in your .init.
;; (require 'dired-explorer)
;; (add-hook 'dired-mode-hook
;;           (lambda ()
;;             (define-key dired-mode-map ":" (lambda () (interactive) (dired-explorer-mode t)))
;;             (dired-explorer-mode t)))
;;
;; toggle mode by ":".

;;; Change Log:
;; If You troubled with my change. Please contact me on Email.
;;
;; 0.6
;; add make-directory
;;
;; 0.5
;; dired-explorer-dired-open is deleted. it seems meanless.
;; I was too foolish that I killed important Emacs keybind M-x at this mode.
;;
;; 0.4
;; first release

;;; Code:

(require 'dired)
(require 'cl-lib)

(defvar dired-explorer-isearch-next      "\C-r")
(defvar dired-explorer-isearch-prev      "\C-e")
(defvar dired-explorer-isearch-backspace "\C-h")
(defvar dired-explorer-isearch-return    "\C-g")


(defvar dired-explorer--active-isearch-keys ""
  "Keys currently bound to `dired-explorer-isearch' in mode map.")

(defun dired-explorer--set-trigger-keys (keys)
  "Refresh dired-explorer isearch bindings with KEYS."
  (when (boundp 'dired-explorer-mode-map)
    (cl-loop for ch across dired-explorer--active-isearch-keys do
             (define-key dired-explorer-mode-map (char-to-string ch) nil))
    (cl-loop for ch across keys do
             (define-key dired-explorer-mode-map
               (char-to-string ch)
               #'dired-explorer-isearch))
    (setq dired-explorer--active-isearch-keys keys)))


(defcustom dired-explorer-isearch-trigger-keys
  "abcdefghijklmnopqrstuvwxyz0123456789"
  "Characters that trigger dired-explorer-isearch in dired-explorer-mode."
  :type 'string
  :set (lambda (symbol value)
         (set-default symbol value)
         (dired-explorer--set-trigger-keys value))
  :group 'dired)

(defun dired-explorer--trigger-char-p (input)
  "Return non-nil when INPUT should trigger explorer isearch."
  (and (integerp input)
       (string-match-p
        (regexp-quote (char-to-string input))
        dired-explorer-isearch-trigger-keys)))

(defvar dired-explorer-mode-map
  (let ((map (make-sparse-keymap)))
    ;; ;; Lower keys for normal dired-mode are replaced M-* at thid mode.
    ;; ;; except for "x".
    ;; (define-key map "\M-a" 'dired-find-alternate-file)
    ;; (define-key map "\M-d" 'dired-flag-file-deletion)
    ;; (define-key map "\M-e" 'dired-find-file)
    ;; (define-key map "\M-f" 'dired-find-file)
    (define-key map "\M-g" 'revert-buffer)
    ;; (define-key map "\M-i" 'dired-maybe-insert-subdir)
    ;; (define-key map "\M-j" 'dired-goto-file)
    ;; (define-key map "\M-k" 'dired-do-kill-lines)
    ;; (define-key map "\M-l" 'dired-do-redisplay)
    ;; (define-key map "\M-m" 'dired-mark)
    ;; (define-key map "\M-n" 'dired-next-line)
    (define-key map "\M-o" 'dired-find-file-other-window)
    ;; (define-key map "\M-p" 'dired-previous-line)
    ;; (define-key map "\M-t" 'dired-toggle-marks)
    ;; (define-key map "\M-u" 'dired-unmark)
    ;; (define-key map "\M-v" 'dired-view-file)
    ;; (define-key map "\M-w" 'dired-copy-filename-as-kill)
    ;; (define-key map "\M-X" 'dired-do-flagged-delete) ; this must be capital
    ;; (define-key map "\M-y" 'dired-show-file-type)
    ;; (define-key map ":"    'dired-explorer-mode)
    ;; (define-key map "+"    'make-directory)
    ;; 以下、副作用のある怖いものたち
    ;; ;; (define-key map "\M-s" 'dired-sort-toggle-or-edit)
    ;; ;; (define-key map "\C-m" 'dired-find-file)
    ;; ;; (define-key map (kbd "<return>") 'dired-find-file)
    ;; ;; (define-key map "^" 'dired-find-file)
    ;; ;; (define-key map "I" 'dired-kill-subdir)
    map))

(define-minor-mode dired-explorer-mode
  "Minor-mode dired-explorer-mode."
  :lighter " Expl")
(defun dired-explorer-do-isearch (regex1 regex2 func1 func2 rpt)
  "Dired explorer isearch.  REGEX1 REGEX2 FUNC1 FUNC2 RPT."
  (interactive)
  (let ((input last-command-event)
        (inhibit-quit t)
        (oldpoint (point))
        (last-word "")
        regx
        str
        (n 1))
    (save-match-data
      (catch 'END
        (while t
          (funcall func1)
          (cond
           ;; end
           ((and (integerp input) (= input ?:))
            (setq unread-command-events (cons input unread-command-events))
            (throw 'END nil))

           ;; character
           ;; _. - + ~ #
           ((dired-explorer--trigger-char-p input)
            (setq str (char-to-string input)
                  n (if (string= last-word str) 2 1)
                  regx (concat regex1 "[\.~#+_]*" str regex2))
            (unless (re-search-forward regx nil t n)
              (goto-char (point-min))
              (re-search-forward regx nil t nil))
            (setq last-word str))

           ;; backspace
           ((and (integerp input)
                 (or (eq 'backspace input)
                     (= input (string-to-char dired-explorer-isearch-backspace))))
            (when (> (length str) 0)
              (setq str (substring str 0 -1)
                    regx (concat regex1 str regex2))
              (goto-char oldpoint)
              (re-search-forward regx nil t nil)))

           ;; next
           ((and regx (integerp input) (= input (string-to-char dired-explorer-isearch-next)))
            (re-search-forward regx nil t rpt))

           ;; previous
           ((and regx (integerp input) (= input (string-to-char dired-explorer-isearch-prev)))
            (re-search-backward regx nil t nil))

           ;; return
           ((and (integerp input) (= input (string-to-char dired-explorer-isearch-return)))
            (goto-char oldpoint)
            (message "return")
            (throw 'END nil))

           ;; other command
           (t
            (setq unread-command-events (cons input unread-command-events))
            (throw 'END nil)))

          (funcall func2)
          ;; (highline-highlight-current-line)
          ;; (message str)
          (setq input (read-event)))))))

(defun dired-explorer-isearch()
  "Incremental search for dired."
  (interactive)
  (dired-explorer-do-isearch
   "[0-9] "                                                        ; REGEX1
   "[^ \n]+$"                                                      ; REGEX2
   (lambda() (if (not (= (point-min) (point))) (backward-char 3))) ; FUNC1
   'dired-move-to-filename                                         ; FUNC2
   2                                                               ; RPT
   ))

(dired-explorer--set-trigger-keys dired-explorer-isearch-trigger-keys)

;; for older environment
(defsubst dired-explorer-string-trim (string)
  "Remove leading and trailing whitespace from STRING."
  (if (string-match "\\`[ \t\n\r]+" string)
      (replace-match "" t t string)
    string)
  (if (string-match "[ \t\n\r]+\\'" string)
      (replace-match "" t t string)
    string))

(defun dired-mac-alias-path (path)
  "Mac alias path.  PATH is POSIX path."
  (let (mac-orig-path)
    (setq mac-orig-path
          (when (eq system-type 'darwin)
            (condition-case nil
                (dired-explorer-string-trim
                 (mapconcat
                  #'identity
                  (process-lines
                   "osascript"
                   "-e" "on run argv"
                   "-e" "tell application \"Finder\" to return POSIX path of (original item of item (POSIX file (item 1 of argv)) as alias)"
                   "-e" "end run"
                   "--"
                   path)
                  "\n"))
              (error nil))))
    (when (and mac-orig-path ;; thx syohex
               (not (string-match "execution error" mac-orig-path))
               (file-exists-p mac-orig-path))
      mac-orig-path)))

;;; ------------------------------------------------------------
;;; Provide

(provide 'dired-explorer)

;;; dired-explorer.el ends here
