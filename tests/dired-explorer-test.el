;;; dired-explorer-test.el --- Regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'dired-explorer)

(defmacro dired-explorer-test--with-files (names &rest body)
  "Run BODY in a temporary Dired buffer containing NAMES."
  (declare (indent 1))
  `(let ((directory (make-temp-file "dired-explorer-test-" t)))
     (unwind-protect
         (progn
           (dolist (name ,names)
             (write-region "" nil (expand-file-name name directory) nil 'silent))
           (with-current-buffer (dired-noselect directory)
             (unwind-protect (progn ,@body)
               (kill-buffer (current-buffer)))))
       (delete-directory directory t))))

(defun dired-explorer-test--type (events)
  "Run explorer search using EVENTS, returning unconsumed events."
  (let ((last-command-event (car events))
        (pending (cdr events))
        (unread-command-events nil))
    (cl-letf (((symbol-function 'read-event)
               (lambda (&rest _)
                 (unless pending (error "Unexpected read-event"))
                 (pop pending))))
      (dired-explorer-isearch))
    unread-command-events))

(ert-deftest dired-explorer-search-filename-shapes ()
  (dired-explorer-test--with-files '("a" "alpha" "charlie space" "file 1 zebra")
    (dolist (case '((?a . "a") (?c . "charlie space")))
      (goto-char (point-min))
      (should (equal (dired-explorer-test--type (list (car case) 13)) '(13)))
      (should (equal (dired-get-filename 'no-dir t) (cdr case))))
    ;; Text inside a filename must not be mistaken for its beginning.
    (goto-char (point-min))
    (dired-explorer-test--type '(?z 13))
    (should-not (dired-get-filename 'no-dir t))))

(ert-deftest dired-explorer-search-navigation ()
  (dired-explorer-test--with-files '("alpha" "amber" "azure")
    (dolist (case '(((?a ?a 13) . "amber")
                    ((?a ?a ?a ?a 13) . "alpha")
                    ((?a ?\C-r 13) . "amber")
                    ((?a ?a ?\C-e 13) . "alpha")))
      (goto-char (point-min))
      (dired-explorer-test--type (car case))
      (should (equal (dired-get-filename 'no-dir t) (cdr case))))))

(ert-deftest dired-explorer-search-literal-trigger-characters ()
  (dired-explorer-test--with-files '("alpha" "[literal" "*literal" "^literal")
    (let ((dired-explorer-isearch-trigger-keys ".[*^"))
      (dolist (case '((?. . ".") (?\[ . "[literal")
                      (?* . "*literal") (?^ . "^literal")))
        (goto-char (point-min))
        (dired-explorer-test--type (list (car case) 13))
        (should (equal (dired-get-filename 'no-dir t) (cdr case)))))))

(ert-deftest dired-explorer-search-backspace-events ()
  (dired-explorer-test--with-files '("alpha" "amber" "beta")
    (dolist (event '(backspace ?\C-h))
      (goto-char (point-min))
      (should (equal (dired-explorer-test--type (list ?a event ?b 13)) '(13)))
      (should (equal (dired-get-filename 'no-dir t) "beta"))
      ;; Deleting the search character also clears repeated-key state.
      (goto-char (point-min))
      (should (equal (dired-explorer-test--type (list ?a event event ?a 13)) '(13)))
      (should (equal (dired-get-filename 'no-dir t) "alpha")))))

;;; dired-explorer-test.el ends here
