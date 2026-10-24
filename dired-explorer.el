;;; dired-explorer.el --- Provide Explorer-like file selection in Dired. -*- coding: utf-8; lexical-binding: t; -*-
;; Original: http://homepage1.nifty.com/blankspace/emacs/dired.html
;; Original2: http://www.bookshelf.jp/soft/meadow_25.html#SEC286
;; Introduce and Supervise: rubikitch
;; Maintainer: jidaikobo-shibata
;; Contributions: syohex, Steve Purcell
;; Keywords: dired explorer
;; Package-Requires: ((emacs "24.3"))
;; Version: 0.7
;; git tag 0.7; git push --tags
;; tested on Emacs 30.2

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
;; Select files and directories in Dired by typing lowercase letters or digits,
;; as in Windows Explorer or macOS Finder.
;; Loading this package leaves the mode disabled and preserves Dired's keymap.
;; Use M-x dired-explorer-mode to toggle it in the current Dired buffer.
;; While enabled, lowercase letters and digits select files instead of running
;; their usual Dired commands.  Uppercase letters (such as M to change file
;; permissions) and punctuation retain their usual bindings by default.
;; To use Dired commands while dired-explorer-mode is enabled, bind them to
;; modifier-key combinations of your choice, taking care not to overwrite
;; existing bindings.  For example:
;; (define-key dired-explorer-mode-map (kbd "M-m") #'dired-mark)
;; The mode also binds M-g to refresh and M-o to open in another window.
;; This elisp is based on the original elisp that rubikichi introduced me
;; to at his Emacs school "Emacs Juku". He also gave me some advice on elisp.
;;
;; [ja]
;; WindowsのExplorerやmacOSのFinderのように、小文字の英字と数字を入力して、
;; Diredでファイルやディレクトリを選択します。
;; 読み込むだけではモードは有効にならず、Diredのキーマップも変更しません。
;; M-x dired-explorer-mode で、現在のDiredバッファでの有効・無効を切り替えます。
;; 有効にすると、小文字の英字と数字は通常のDired操作の代わりにファイル選択に
;; 使われます。デフォルトでは、大文字（パーミッションを変更する M など）や
;; 記号の通常のキー操作は引き続き使えます。
;; dired-explorer-modeの有効時にも使いたいDired操作は、
;; 既存の割り当てとの重複に注意して、
;; モディファイアキーとの組み合わせなどに設定してください。
;; 例:
;; (define-key dired-explorer-mode-map (kbd "M-m") #'dired-mark)
;; このほか、有効時はM-gで再表示、M-oで別ウィンドウに開く操作を使えます。
;; このelispは、かつて、るびきちさんが彼のEmacs塾で、もとになるElispを
;; 紹介くださったものをもとにしています。また、彼はelispにアドバイスもくださいました。

;;; Usage:
;; Load the package, then run M-x dired-explorer-mode in a Dired buffer:
;; パッケージを読み込み、Diredで M-x dired-explorer-mode を実行します:
;; (require 'dired-explorer)
;;
;; Optional: add this to init.el to enable the mode in every new Dired buffer:
;; 任意設定: 新しく開くDiredで毎回有効にする場合はinit.elに追加します:
;; (add-hook 'dired-mode-hook #'dired-explorer-mode)

;;; Change Log:
;; If you have issues with these changes, please contact me by email.
;;
;; 0.7
;; refactor isearch internals and trigger-key customization
;; replace shell-command-to-string with process-lines for macOS alias lookup
;; convert source encoding to UTF-8 for MELPA display
;;
;; 0.6
;; add make-directory
;;
;; 0.5
;; dired-explorer-dired-open is deleted. It seemed meaningless.
;; I was too foolish that I killed important Emacs keybinding M-x in this mode.
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
    (cl-loop for ch across dired-explorer--active-isearch-keys
             do (define-key dired-explorer-mode-map (char-to-string ch) nil))
    (cl-loop for ch across keys
             do (define-key dired-explorer-mode-map
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
    (define-key map "\M-g" #'revert-buffer)
    (define-key map "\M-o" #'dired-find-file-other-window)
    map))

(define-minor-mode dired-explorer-mode
  "Minor-mode dired-explorer-mode."
  :lighter " Expl")

(defun dired-explorer--search-filename (regexp &optional backward count)
  "Find a Dired filename matching REGEXP in the given direction.
Search backward when BACKWARD is non-nil, otherwise forward.
COUNT specifies which matching entry to select.  Leave point unchanged
when no matching entry is found."
  (let ((origin (point))
        (remaining (or count 1))
        found)
    (save-excursion
      (beginning-of-line)
      (while (and (> remaining 0) (not found))
        (let ((filename (dired-get-filename 'no-dir t)))
          (when (and filename
                     (dired-move-to-filename)
                     (if backward
                         (< (point) origin)
                       (>= (point) origin))
                     (string-match-p regexp filename))
            (setq remaining (1- remaining))
            (when (= remaining 0)
              (setq found (point)))))
        (unless found
          (when (/= (forward-line (if backward -1 1)) 0)
            (setq remaining 0)))))
    (when found
      (goto-char found))))

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
           ((dired-explorer--trigger-char-p input)
            (setq str (char-to-string input)
                  n (if (string= last-word str) 2 1)
                  regx (concat regex1 "[\.~#+_]*" (regexp-quote str) regex2))
            (unless (dired-explorer--search-filename regx nil n)
              (goto-char (point-min))
              (dired-explorer--search-filename regx))
            (setq last-word str))

           ;; backspace
           ((or (eq 'backspace input)
                (and (integerp input)
                     (= input (string-to-char dired-explorer-isearch-backspace))))
            (when (> (length str) 0)
              (setq str (substring str 0 -1)
                    last-word ""
                    regx (concat regex1 (regexp-quote str) regex2))
              (goto-char oldpoint)
              (dired-explorer--search-filename regx)))

           ;; next
           ((and regx
                 (integerp input)
                 (= input (string-to-char dired-explorer-isearch-next)))
            (dired-explorer--search-filename regx nil rpt))

           ;; previous
           ((and regx
                 (integerp input)
                 (= input (string-to-char dired-explorer-isearch-prev)))
            (dired-explorer--search-filename regx t))

           ;; return
           ((and (integerp input)
                 (= input (string-to-char dired-explorer-isearch-return)))
            (goto-char oldpoint)
            (message "return")
            (throw 'END nil))

           ;; other command
           (t
            (setq unread-command-events (cons input unread-command-events))
            (throw 'END nil)))

          (funcall func2)
          (setq input (read-event)))))))

(defun dired-explorer-isearch ()
  "Incremental search for dired."
  (interactive)
  (dired-explorer-do-isearch
   "\\`" "" #'beginning-of-line #'dired-move-to-filename 2))

(dired-explorer--set-trigger-keys dired-explorer-isearch-trigger-keys)

;; for older environment
(defsubst dired-explorer-string-trim (string)
  "Remove leading and trailing whitespace from STRING."
  (when (string-match "\\`[ \t\n\r]+" string)
    (setq string (replace-match "" t t string)))
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
