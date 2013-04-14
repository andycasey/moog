;;
;; GNU-lisp functions for editing SM macro files
;;
;; The following should be put in your .emacs file to automatically
;; load these functions when editing files *.m or *.sav
;;
;;(setq auto-mode-alist
;;      (cons (cons "\\.m$" 'sm-mode)
;;	    (cons (cons "\\.sav$" 'sm-mode) auto-mode-alist)))
;;(autoload 'sm-mode "~rhl/sm/sm.el" nil t)
;;
;; Alternatively, if the first line of a file contains the string
;;		-*-SM-*-
;; emacs will load sm-mode (note the lower case sm).
;;
;; Of course, you'd usually want to have the first line of the macro file
;; start with ## in the first two columns.
;;
;; This file is based on code in GNU Emacs, and is accordingly covered
;; by the GNU General Public License: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 1, or (at your option)
;; any later version.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
;;
(require 'comint)
;; 
(defvar SM-macro-file t
  "*Indent as SM macro file, rather than executable SM code, if non-nil")
(defvar SM-mode-type-name "" "name associated with value of SM-macro-file")
(defvar SM-indent 3 "*Indentation for blocks.")
(defvar SM-indent-continue 4 "*Extra indentation for continuation lines.")
(defvar SM-comment-column 40 "*Comments start in this column")
(defvar SM-tab-always-indent nil
  "*Non-nil means TAB in SM mode should always reindent the current line,
regardless of where in the line point is when the TAB command is used.")

(defvar SM-mode-syntax-table nil
  "Syntax table in use in SM-mode buffers.")

(if (not SM-mode-syntax-table)
    (progn 
      (setq SM-mode-syntax-table (make-syntax-table))
      (modify-syntax-entry ?_ "w" SM-mode-syntax-table)
      (modify-syntax-entry ?. "w" SM-mode-syntax-table)
      (modify-syntax-entry ?+ "." SM-mode-syntax-table)
      (modify-syntax-entry ?- "." SM-mode-syntax-table)
      (modify-syntax-entry ?* "." SM-mode-syntax-table)
      (modify-syntax-entry ?/ "." SM-mode-syntax-table)
      (modify-syntax-entry ?% "." SM-mode-syntax-table)
      (modify-syntax-entry ?\" "\"" SM-mode-syntax-table)
      (modify-syntax-entry ?\\ "/" SM-mode-syntax-table)
      (modify-syntax-entry ?{ "(}" SM-mode-syntax-table)
      (modify-syntax-entry ?} "){" SM-mode-syntax-table)
      (modify-syntax-entry ?# "<" SM-mode-syntax-table)
      (modify-syntax-entry ?\n ">" SM-mode-syntax-table)))

(defvar SM-mode-map () 
  "Keymap used in SM mode.")

(if SM-mode-map
    ()
  (setq SM-mode-map (make-sparse-keymap))
  (define-key SM-mode-map "\t" 'SM-tab)
  (define-key SM-mode-map "\C-m" 'SM-newline-and-indent)
  (define-key SM-mode-map "}" 'SM-insert-and-indent)
  (define-key SM-mode-map "\e\C-a" 'beginning-of-SM-macro)
  (define-key SM-mode-map "\e\C-e" 'end-of-SM-macro)
  (define-key SM-mode-map "\e\C-h" 'mark-SM-macro)
  (define-key SM-mode-map "\e\C-m" 'SM-indent-macro)
  (define-key SM-mode-map "\e\t" 'SM-indent-line)
  (define-key SM-mode-map "\e;" 'SM-add-comment)
  (define-key SM-mode-map "\C-c0"
    '(lambda () "Switch to device 0"
       (interactive)
       (sm-send-string "dev x11 -dev 0\n")))
  (define-key SM-mode-map "\C-c1"
    '(lambda () "Switch to device 1"
       (interactive)
       (sm-send-string "dev x11 -dev 1\n")))
  (define-key SM-mode-map "\C-c2"
    '(lambda () "Switch to device 2"
       (interactive)
       (sm-send-string "dev x11 -dev 2\n")))
  (define-key SM-mode-map "\C-c\C-c" 'sm-eval-current-buffer)
  (define-key SM-mode-map "\C-c\C-e"
    '(lambda () "Erase device"
       (interactive)
       (sm-send-string "erase\n")))
  (define-key SM-mode-map "\C-c\C-l" 'sm-eval-current-line)
  (define-key SM-mode-map "\C-x4\C-c\C-l" 'sm-eval-other-window-current-line)
  (define-key SM-mode-map "\C-c\C-m" 'sm-eval-current-macro)
  (define-key SM-mode-map "\C-cm" 'sm-macro-file)
  (define-key SM-mode-map "\C-c\C-p"
    '(lambda (show-window)
       "Switch to device $printer; with prefix-argument show SM buffer"
       (interactive "P")
       (if show-window
	   (display-buffer sm-process-buffer))
       (sm-send-string "echo Switching to device $printer\n")
       (sm-send-string "device $printer\n")))
  (define-key SM-mode-map "\C-c\C-r"
    '(lambda ()
       "Clear and display SM buffer"
       (interactive)
       (let ( (initial-window (get-buffer-window (buffer-name))) )
	 (switch-to-buffer-other-window sm-process-buffer)
	 (delete-region (point-min) (point-max))
	 (sm-send-string "\n")
	 (recenter)
	 (select-window initial-window))
       ))
  (define-key SM-mode-map "\C-c\C-s" 'switch-to-sm-process)
  (define-key SM-mode-map "\C-c\C-x" 'sm-eval-region)

(defun SM-mode () "alias for sm-mode for backwards compatibility"
  (interactive) (sm-mode))
;;
(defun sm-mode (&optional executable-file) "Major mode for editing SM code.

If SM-macro-file is non-nil, lines starting anywhere but the
left margin are indented by 2 tabs, then all further indentation is done
with spaces. In this case, macro declarations are followed by a tab, then
the number of args, then another tab.

If SM-macro-file is nil, format code as a series of executable statements,
which may, of course, include \"macro name { ... }\" commands.

Setting SM-macro-file only affects the buffer in which it is set; the default
is t, to set it to nil invoke sm-mode or \\[sm-macro-file] with an
argument. (Simply saying \\[sm-macro-file] toggles between modes).
The type (Macro or Executable) is set in the command line.

If a file has a \"define\", \"macro\", or \"set\" in the first column,
SM-macro-file is set to nil when SM mode is entered.

You can evaluate the current line with the command
\\[sm-eval-current-line], the region with the command
\\[sm-eval-region], or the entire current buffer with
\\[sm-eval-current-buffer]; note that this won't work very well in a
macro file; in such files you can however use
\\[sm-eval-current-macro] You must first start an SM process with
\\[run-sm]; you can switch to the SM buffer with
\\[switch-to-sm-process] (with a prefix argument, switch to it in a
different window).

Variables controlling indentation style and extra features:

 SM-macro-file                            (default: see above)
    Assume file is of SM macros.
 SM-indent                                (default: 3)
    Indentation for blocks.
 SM-indent-continue                       (default: 4)
    Extra indentation for continuation lines.
 SM-comment-column                        (default: 40)
    Starting column for comments following code.
 SM-tab-always-indent                     (default: nil)
    Non-nil means TAB in SM mode should always reindent the current line,
    regardless of where in the line point is when the TAB command is used.

Useful user functions include:

  narrow-to-SM-macro
     Narrow buffer to current SM macro. The opposite is widen.
  next-narrow-SM-macro
     Skip to the next SM macro, and narrow to it. If the optional how-many
     argument is provided, skip forward that many macros first.
  SM-macro-name
     Print the name of the SM macro containing the cursor

Turning on SM mode calls the value of the variable SM-mode-hook 
with no args, if it is non-nil.
\\{SM-mode-map}"
  (interactive "p")
  (kill-all-local-variables)
  (set-syntax-table SM-mode-syntax-table)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'SM-indent-line)
  (setq indent-tabs-mode nil)
  (make-local-variable 'comment-indent-function)
  (setq comment-indent-function nil)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "[^\\\\]#+[ \t]*")
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (setq comment-column SM-comment-column)
  (make-variable-buffer-local 'SM-macro-file)
  (make-local-variable 'require-final-newline)
  (setq require-final-newline t)
  (make-local-variable 'font-lock-keywords-case-fold-search)
  (setq font-lock-keywords-case-fold-search t)
  (make-local-variable 'font-lock-keywords)
  (setq font-lock-keywords SM-font-lock-keywords)
  (make-local-variable 'font-lock-keywords)
  (setq font-lock-keywords SM-font-lock-keywords)
  (if (or executable-file
	  (save-excursion
	    (goto-char (point-min))
	    (search-forward-regexp "^\\(define\\|macro\\|set\\)\\>" nil t)))
	  (setq SM-macro-file nil))
  (use-local-map SM-mode-map)
  (setq mode-name "SM")
  (setq major-mode 'sm-mode)
  (make-local-variable 'global-mode-string)
  (sm-macro-file (if SM-macro-file 1 0))
  (run-hooks 'SM-mode-hook))

(defun sm-macro-file (&optional macro-file)
  "Toggle between an SM macro file, as read by \"macro read\" and
an executable file, as loaded by \"input\". With argument, choose one or other"
  (interactive "P")
  (setq macro-file
	(if (equal nil macro-file) (if SM-macro-file 0 1)
	  (prefix-numeric-value macro-file)))
  (setq SM-macro-file (not (= 0 macro-file)))
  (setq SM-mode-type-name (if SM-macro-file "Macro" "Executable"))
  (setq mode-line-format
	'("-" mode-line-mule-info mode-line-modified
	  mode-line-frame-identification mode-line-buffer-identification
	  "   " global-mode-string
	  "   %[("
	  mode-name " [" SM-mode-type-name "] "
	  mode-line-process minor-mode-alist "%n" ")%]--"
	  (line-number-mode "L%l--")
	  (column-number-mode "C%c--") (-3 . "%p") "-%-"))
  (force-mode-line-update))

(add-hook 'font-lock-mode-hook
	  '(lambda () 
	    (if (eq major-mode 'sm-mode)
		(setq font-lock-keywords SM-font-lock-keywords))))

(defun SM-comment-hook ()
  (save-excursion
    (skip-chars-backward " \t")
    (max (+ 1 (current-column))
	 comment-column)
))

(defun beginning-of-SM-macro (num)
  "Moves point to the beginning of the current SM macro."
  (interactive "p")
  (while (not (= num 0))
    (setq num (- num 1))
    (if SM-macro-file
	(re-search-backward "^[^ \t\n]" nil 'move)
      (re-search-backward "^\\(macro\\|MACRO\\)[ \t]" nil 'move))))

(defun end-of-SM-macro (num)
  "Moves point to the end of the current SM macro."
  (interactive "p")
  (while (not (= num 0))
    (setq num (- num 1))
    (if SM-macro-file
	(progn
	  (end-of-line)
	  (re-search-forward "^[^ \t\n]" nil 'move)
	  (beginning-of-line))
      (re-search-forward "^}" nil 'move))))

(defun mark-SM-macro ()
  "Put mark at end of SM macro, point at beginning. Marks are pushed."
  (interactive)
  (end-of-SM-macro 1)
  (push-mark (point))
  (beginning-of-SM-macro 1)
  (buffer-substring (point)
		  (save-excursion (skip-chars-forward "^ \t\n") (point))))
;;
;; Now definitions to narrow the buffer to the next/current/previous definition
;;
(defun narrow-to-SM-macro ()
  "Narrow buffer to current SM macro."
  (interactive)
  (if (looking-at "^[^ \t]") (forward-word 1))
  (let ( (end (save-excursion (end-of-SM-macro 1) (point)))
	 (start (save-excursion (beginning-of-SM-macro 1) (point))) )
    (narrow-to-region start end)
    (beginning-of-line)))
;;
(defun next-narrow-SM-macro (&optional how-many)
  "Skip to the next SM macro, and narrow to it. If the optional how-many
argument is provided, skip forward that many macros first."
  (interactive "p")
  (if (not how-many) (setq how-many 1))
  (widen)
  (if (not (= how-many 0))
      (progn
	(if (> how-many 0)
	    (end-of-SM-macro how-many)
	  (beginning-of-SM-macro (abs how-many)))
	(narrow-to-SM-macro))))
;;
(defun SM-macro-name ()
  "Print the name of the SM macro containing the cursor"
  (interactive)
  (save-excursion
    (if (not (looking-at "^[^ \t]"))
	(beginning-of-SM-macro 1))
    (let ( (start (point)) (name) (nargs) )
      (if (not SM-macro-file)
	  (progn
	    (skip-chars-forward "^ \t")
	    (skip-chars-forward " \t")))
      (skip-chars-forward "^ \t")
      (setq name (buffer-substring start (point)))
      (skip-chars-forward " \t")
      (setq start (point))
      (setq nargs
	    (if (looking-at "[0-9]")
		(progn
		  (skip-chars-forward "0-9")
		  (buffer-substring start (point)))
	      "0"))
      (message (concat "Current macro is " name
		       (if (not (string-equal nargs "0"))
			   (format " (%s args)" nargs)))))))
      


(defun SM-indent-line ()
  "Indent current SM line based on its contents and on previous lines.
Deal with first lines of macros correctly."
  (interactive)
  (let ((cfi (calculate-SM-indent)))
    (save-excursion
      (SM-indent-to-column cfi)
      (beginning-of-line)
      (if (and SM-macro-file		; a file of SM macros
	       (looking-at "[^ \t\n]"))	; macro declaration
	  (progn
	    (skip-chars-forward "^ \t")
	    (cond ((looking-at "[ \t]*$") (delete-horizontal-space))
		  ((looking-at "[ \t]*[^ \t0-9]") ; No arguments
		   (if (< (current-column) 8)
		       (if (not (looking-at "\t\t[^ \t]"))
			   (progn
			     (delete-horizontal-space)
			     (insert "\t\t")))
		       (if (not (looking-at "\t[^ \t]"))
			   (progn
			     (delete-horizontal-space)
			     (insert "\t")))))
		  (t			; Macro has arguments
		   (if (< (current-column) 8)
		       (if (not (looking-at "\t[0-9]+\t"))
			   (progn
			     (delete-horizontal-space)
			     (insert "\t")
			     (skip-chars-forward "0-9")
			     (delete-horizontal-space)
			     (insert "\t")))
		       (if (not (looking-at " [0-9]+\t"))
			   (progn
			     (delete-horizontal-space)
			     (insert " ")
			     (skip-chars-forward "0-9")
			     (delete-horizontal-space)
			     (insert "\t")))))))))
	    (if (< (current-column) cfi) (move-to-column cfi))))
(defun SM-newline-and-indent ()
  "Insert a newline, and indent. When splitting lines, preserve indentation"
  (interactive)
  (if (looking-at "$")
      (newline-and-indent)
    (progn (newline) (insert " ") (SM-indent-line))))

(defun SM-indent-macro ()
  "Properly indents the SM macro which contains point."
  (interactive)
  (save-excursion
    (mark-SM-macro)
    (let ((name (mark-SM-macro)))
      (message (format "Indenting macro %s..." name))
      (indent-region (point) (mark) nil)
      (message (format "Indenting macro %s... done." name))))
  (let ((col (calculate-SM-indent)))
    (if (< (current-column) col)
	(move-to-column col)))
  )

(defun calculate-SM-indent ()
  "Calculates the SM indent column based on previous lines."
  (let ((icol)
	(min-indent (if SM-macro-file 16 0)))	; minimum indent (16 == 2 tabs)
    (save-excursion
      (if (SM-previous-statement)
	  (setq icol min-indent)	
	(progn
	  (if (= (point) (point-min))
	      (setq icol min-indent)
	    (setq icol (SM-current-line-indentation))))))
    (save-excursion
      (beginning-of-line)
      (cond
       ((and SM-macro-file (looking-at "[^ \t\n]") (setq icol 0)))
       ((save-excursion
	  (forward-line -1)
	  (if (looking-at ".*\\\\$") (setq icol (+ icol SM-indent-continue)))))
       ((save-excursion
	  (skip-paired-braces)
	  (looking-at "[^#\n]*}")) (setq icol (- icol SM-indent)))
      )
      (if (looking-at "[ \t\n]")
	  (progn
	    (forward-line -1)
	    (skip-paired-braces)
	    (if (looking-at "[^#\n]*{")
		(setq icol (+ icol SM-indent))))))
    (max (if (= icol 0) 0 min-indent) icol)))

(defun skip-paired-braces () "Skip pairs of braces {...}"
  (interactive)
  (while
      (re-search-forward "{[^#}]*}" (save-excursion (end-of-line) (point)) t)
    (goto-char (match-end 0))))

(defun SM-current-line-indentation ()
  "Indentation of current line. If it's zero, look back until we find a
non-empty line"
  (save-excursion
    (beginning-of-line)
    (while (and (> (point) (point-min)) (looking-at "^[ \t]*$"))
      (forward-line -1))
    ;; Move past whitespace.
    (skip-chars-forward " \t")
    (current-column)))

(defun SM-indent-to-column (col)
  "Indents current line with up to 2 tabs then spaces to column COL if
SM-macro-file is true; otherwise simply indent appropriately"
  (save-excursion
    (beginning-of-line)
    (if (not (and
	      (progn (skip-chars-forward "\t ") (= (current-column) col))
	      (not (and SM-macro-file (looking-at "\t\t")))))
	(progn
	  (beginning-of-line)
	  (delete-horizontal-space)
	  (SM-indent-to col)))
	  (skip-chars-forward "\t ")
      ;; Indent any comment following code on the same line
	  (if (and
	       (not (looking-at comment-start))
;	       (save-excursion
;		 (beginning-of-line) (looking-at "[ \t\n]"))
	       (re-search-forward comment-start-skip
				  (save-excursion (end-of-line) (point)) t))
	      (progn (goto-char (match-beginning 0))
		     (if (not (= (+ 1 (current-column)) (SM-comment-hook)))
			 (progn
			   (delete-horizontal-space)
			   (SM-indent-to (SM-comment-hook))))))))

(defun SM-indent-to (arg)
  "Like indent-to, but use tabs for first 16 columns if SM-macro-file is non-nil"
   (interactive)
   (indent-to arg)
   (if SM-macro-file
       (save-excursion
	 (beginning-of-line)
	 (if (looking-at "                ") ; 16 spaces
	     (progn (delete-char 16) (insert "\t\t"))))))

(defun SM-previous-statement ()
  "Moves point to beginning of the previous SM statement.
Returns 'first-statement if that statement is the first
non-comment SM statement in the file, and nil otherwise.
Skip to first line of multiple line-statements (ending in \\)."
  (interactive)
  (cond ((or
	  (not (= (forward-line -1) 0))
	  (looking-at "[^ \t\n]"))
	      'first-statement)
	(t
	 (beginning-of-line)
	 (while (and (or (looking-at "[ \t]*$") (looking-at ".*\\\\$"))
		     (= (forward-line -1) 0)
		     ))
	 nil
	 )))

(defun SM-add-comment ()
  (interactive)
  (beginning-of-line)
  (if (re-search-forward comment-start-skip
		     (save-excursion (end-of-line) (point)) t)
      (progn (if (not (=
	    (progn (goto-char (+ 1 (match-beginning 0)))
		   (current-column)) (SM-comment-hook)))
	  (progn
	    (delete-horizontal-space)
	    (SM-indent-to (SM-comment-hook))))
	     (if (looking-at "#* ")	; move to start of text
		 (skip-chars-forward "# ")
	       (progn (end-of-line) (insert " "))))
    (progn
      (end-of-line)
      (delete-horizontal-space)
      (SM-indent-to (SM-comment-hook))
      (insert comment-start))))

(defun SM-insert-and-indent ()
  "Insert a key, and indent the line"
  (interactive)
  (insert last-command-char)
  (SM-indent-line)
  (blink-matching-open))

(defun SM-tab (a)
  "With a prefix argument simply insert a tab (or spaces as appropriate).
If SM-tab-always-indent is nil indent the current line if dot is to the
left of any text, otherwise insert an (SM) tab. If SM-tab-always-indent
is non-nil, simply reindent line"
  (interactive "p")
;  (debug)
  (if (not (= 1 a))			; insert an (SM) tab
      (SM-insert-tab)
    (if SM-tab-always-indent
	(SM-indent-line)
      (let ((before-all-text
	     (save-excursion (skip-chars-backward " \t") (looking-at "^"))))
	(if before-all-text
	    (SM-indent-line)
	  (SM-insert-tab))))))
  
(defun SM-insert-tab ()
  "insert spaces to the next tab stop, except at the start of a line where
up to two real tabs are allowed"
  (interactive)
  (if (or (looking-at "^") (save-excursion (backward-char) (looking-at "^")))
	  (insert ?\C-i) (insert-tab)))
)

;;
;; Font lock mode for SM
;;
(defconst SM-font-lock-keywords-1 nil
 "For consideration as a value of `SM-font-lock-keywords'.
This does fairly subdued highlighting.")

(defconst SM-font-lock-keywords-2 nil
 "For consideration as a value of `SM-font-lock-keywords'.
This does a lot more highlighting.")

(let ((storage "auto\\|extern\\|register\\|static\\|volatile")
      (prefixes "unsigned\\|short\\|long")
      (types (concat "int\\|char\\|float\\|double\\|void\\|struct\\|"
		     "union\\|enum\\|typedef"))
      (ctoken "[a-zA-Z0-9_:~*]+")
      )
  (setq SM-font-lock-keywords-1
   (list
    ;; '("#.*" . font-lock-comment-face) ;; this is done automatically
    ;;
    ;; fontify macros being defined.
    '("macro[ \t]+\\([^ \t]+\\)[ \t]*[0-9]*[ \t]*{" 1 font-lock-function-name-face)
    ;;
    ;; define -- draw something
    ;;
    '("\\<\\(axis\\|box?\\|\\(putla?\\|[xy]?la\\)?\\(bel\\)?\\)\\>"
      . font-lock-type-face)
    '("\\<\\(contour\\|surface\\)\\>" . font-lock-type-face)
    '("\\<\\(draw\\|rel\\(ocate\\)?\\)\\>"  . font-lock-type-face)
    '("\\<\\(con\\(nect\\)?\\|hi\\(stogram\\)?\\|poi\\(nts\\)?\\)\\>"
     . font-lock-type-face)
    ;;
    ;; include something
    ;;
    '("\\<\\(da\\(ta\\)?\\|image\\|load\\|macro read\\|restore\\|save\\)[ \t]+[^ \t\n]+" . font-lock-comment-face)
    '("\\<read[ \t]*[^ \t]*" . font-lock-comment-face)
    '("\\<lin\\(es\\)?[ \t]+[^ \t\n]+[ \t]+[^ \t\n]+" . font-lock-comment-face)
    ;;
    ;; keyword -- control the plotting window
    ;;
    '("\\<\\(lim\\(its\\)?\\|location\\|viewpoint\\|window\\)\\>"
      . font-lock-keyword-face)
    '("\\<\\(angle\\|expand\\|[cl]t\\(ype\\)?\\|lw\\(eight\\)?\\)[ \t]+[^ \t\n]+" 
      . font-lock-keyword-face)
    '("\\<\\(pt\\(ype\\)?\\)[ \t]+[^ \t\n]+\\([ \t]+[^ \t\n]+\\)?"
      . font-lock-keyword-face)
    ;;
    ;;
    ;; string -- "quoted text" and 'strings'
    '("\"\\([^\"]*\\)\"" 1 font-lock-string-face)
    '("'\\([^\']*\\)'" 1 font-lock-string-face)
    ))

  (setq SM-font-lock-keywords-2
   (append SM-font-lock-keywords-1
    (list
     ;;
     ;; flow control, macros, variables, and vectors
     ;;
     '("[{}]" . font-lock-type-face)
     '("\\<\\(break\\|define\\|do\\|else\\|foreach\\|if\\|local\\|macro\\|set\\|while\\)\\>"
       . font-lock-keyword-face)
     )))
  )

; default to the gaudier variety?
;(defvar SM-font-lock-keywords SM-font-lock-keywords-2
;  "Additional expressions to highlight in SM mode.")
(defvar SM-font-lock-keywords SM-font-lock-keywords-1
  "Additional expressions to highlight in SM mode.")
(setq SM-font-lock-keywords SM-font-lock-keywords-2)

;;{{{ patterns for hilit19

;; hilit19 is deprecated; your are supposed to use font-lock (see above)
;; these days

;; Define some useful highlighting patterns for the hilit19 package.
;; These will activate only if the function hilit-set-mode-patterns
;; is already bound - ie, if hilit19 has already been loaded when this
;; mode is loaded. Nonoptimal. I could put this in the mode function,
;; but then that has other problems.

;; suggestions for highlight patterns are most welcome. We tried to
;; choose a middle ground between lots of highlighting (ugly and slow)
;; and only a little bit (not so useful).

;; Author: Wes Colley wes@astro.princeton.edu. Much hacked up by RHL

;;     name     light               dark               mono
;;
;;    (comment	firebrick-italic    moccasin           italic)
;;    (include	purple		    Plum1	       bold-italic)
;;    (define	ForestGreen-bold    green	       bold)
;;    (defun	blue-bold	    cyan-bold	       bold-italic)
;;    (decl	RoyalBlue	    cyan	       bold)
;;    (type	nil		    yellow	       nil)
;;    (keyword	RoyalBlue	    cyan	       bold-italic)
;;    (label	red-underline	    orange-underlined  underline)
;;    (string	grey40		    orange	       underline)

(if (fboundp 'hilit-set-mode-patterns)
    (hilit-set-mode-patterns
     'SM-mode
     '(;; comment -- comments
       ("#" "\n" comment)
       ;; define -- draw something
       ("\\<\\(axis\\|box?\\|\\(putla?\\|[xy]?la\\)?\\(bel\\)?\\)\\>" "$\\|\\\\n" define)
       ("\\<\\(contour\\|surface\\)\\>" nil define)
       ("\\<\\(draw\\|rel\\(ocate\\)?\\)\\>" nil define)
       ("\\<\\(con\\(nect\\)?\\|hi\\(stogram\\)?\\|poi\\(nts\\)?\\)\\>" "$\\|\\\\n" define)
       ;; defun -- macro definitions
       ("^[^ \t\n]+\\([ \t]+[0-9]+\\)?" nil defun)
       ;; include -- read data or macros
       ("\\<\\(da\\(ta\\)?\\|image\\|load\\|macro read\\|restore\\|save\\)[ \t]+[^ \t\n]+" nil include)
       ("\\<read\\>" "$\\|\\(.*\\\\\n[^\n;]+\\)+" include)
       ("\\<lin\\(es\\)?[ \t]+[^ \t\n]+[ \t]+[^ \t\n]+" nil include)
       ;; keyword -- control the plotting window
       ("\\<\\(lim\\(its\\)?\\|location\\|viewpoint\\|window\\)\\>" "$\\|\\\\n" keyword)
       ("\\<\\(angle\\|expand\\|[cl]t\\(ype\\)?\\|lw\\(eight\\)?\\)[ \t]+[^ \t\n]+" nil keyword)
       ("\\<\\(pt\\(ype\\)?\\)[ \t]+[^ \t\n]+\\([ \t]+[^ \t\n]+\\)?" nil keyword)
       ;; string -- "quoted text" and 'strings'
       ("\"[^\"\n]*\"\\|'[^\n']*'" nil string)
       ;; type -- flow control, macros, variables, and vectors
       ("[{}]" nil type)
       ("\\<\\(break\\|define\\|do\\|else\\|foreach\\|if\\|local\\|macro\\|set\\|while\\)\\>" nil type)
       )
     nil 'case-insensitive)
  nil)

;;}}}

;;;
;;; Code to run SM from an emacs buffer. This code is based on that in
;;; tcl-mode.el
;;;
(defvar sm-application "sm"
  "*Name of executable to run in SM mode.")

(defvar sm-command-switches '("-s" "-t" "dumb:200")
  "*Switches to supply to `sm-application'.")

(defvar sm-prompt-regexp "^\\(: \\|\\+ \\|SM> \\)"
  "*If not nil, a regexp that will match the prompt in the slave process.
If nil, the prompt is the name of the application with \">\" appended.

The default is \"^\\(: \\|\\+ \\|SM> \\)\", which will match the default
primary and secondary prompts.")

(defvar sm-process-buffer nil "name of buffer running SM")

(defvar sm-process-mode-map nil
  "Keymap used in slave SM mode.")

(defconst sm-using-emacs-19 (string-match "19\\." emacs-version)
  "Nil unless using Emacs 19 (XEmacs or FSF).")

(defconst sm-omit-ws-regexp "^[^ \t\n#}][^\n}]+}*[ \t]+"
  "Regular expression that matches everything except space, comment
starter, and comment ender syntax codes.")


(defun sm-process-mode ()
  "Major mode for interacting with SM interpreter.

A SM process can be started with M-x sm-process.

Entry to this mode runs the hooks comint-mode-hook and
sm-process-mode-hook, in that order.

You can send text to the slave SM process from other buffers
containing SM source.

Variables controlling slave SM mode:
  sm-application
    Name of program to run.
  sm-command-switches
    Command line arguments to `sm-application'.
  sm-prompt-regexp
    Matches prompt.
  sm-process-source-command
    Command to use to read SM file in running application.
  sm-process-buffer
    The current SM process buffer.  See variable
    documentation for details on multiple-process support.

The following commands are available:
\\{sm-process-mode-map}"
  (interactive)
  (comint-mode)
  (if nil
  (setq comint-prompt-regexp (or sm-prompt-regexp
				 (concat "^"
					 (regexp-quote sm-application)
					 ">")))
  )
  (setq major-mode 'sm-process-mode)
  (setq mode-name "Slave SM")
  (setq mode-line-process '(": %s"))

  (if (not sm-process-mode-map)
      (setq sm-process-mode-map (copy-keymap comint-mode-map)))
  (use-local-map sm-process-mode-map)
  
  (set-syntax-table SM-mode-syntax-table)
  (if sm-using-emacs-19
      (progn
	(make-local-variable 'defun-prompt-regexp)
	(setq defun-prompt-regexp sm-omit-ws-regexp)))
  (make-local-variable 'sm-process-delete-prompt-marker)
  (setq sm-process-delete-prompt-marker (make-marker))
  (set-process-filter (get-buffer-process (current-buffer)) 'sm-filter)
  (run-hooks 'sm-process-mode-hook))

(defun sm-process (&optional cmd)
  "Run slave SM process.
Prefix arg means enter program name interactively.
See documentation for function `sm-process-mode' for more information."
  (interactive
   (list (if current-prefix-arg
	     (read-string "Run SM: " sm-application)
	   sm-application)))

  (if (not 'cmd)
      (setq cmd (read-string "Run SM: " sm-application)))

  (if (not (comint-check-proc "*sm-process*"))
      (progn
	(set-buffer (apply (function make-comint) "sm-process" cmd nil
			   sm-command-switches))
	(sm-process-mode)))
  (make-local-variable 'sm-application)
  (setq sm-application cmd)
  (setq sm-process-buffer "*sm-process*"))

(defun switch-to-sm-process (other-window)
  "Switch to the buffer running SM; with prefix argument in other window"
  (interactive "P")
  (let ( (buffer sm-process-buffer) )
    (if other-window
	(switch-to-buffer-other-window buffer)
      (switch-to-buffer buffer))))

(defun sm-process-cc ()
  "Send a ^C to the slave SM process"
  (interactive)
  (if (comint-check-proc sm-process-buffer)
      (signal-process (process-id (get-buffer-process sm-process-buffer)) 'SIGINT)
    (error "There is no slave SM process running")))

(defun delete-sm-process ()
  "Kill the slave SM process"
  (interactive)
  (if (comint-check-proc sm-process-buffer)
      (delete-process  "sm-process")
    (error "There is no slave SM process running")))

(and (fboundp 'defalias)
     (defalias 'kill-sm 'delete-sm-process)
     (defalias 'run-sm 'sm-process))

;;
;; Send commands to SM process
;;
(defun sm-send-string (string &optional proc)
  (if (not proc)
      (setq proc (sm-process-proc)))
  (save-excursion
    (set-buffer (process-buffer proc))
    (goto-char (process-mark proc))
    (beginning-of-line)
    (if (looking-at comint-prompt-regexp)
	(set-marker sm-process-delete-prompt-marker (point))))
  (comint-send-string proc string))

(defun sm-send-region (start end &optional proc)
  (save-excursion
    (set-buffer (process-buffer proc))
    (goto-char (process-mark proc))
    (beginning-of-line)
    (if (looking-at comint-prompt-regexp)
	(set-marker sm-process-delete-prompt-marker (point))))
  (comint-send-region proc start end))

(defun sm-eval-current-line (&optional and-go)
  "Send the current region to the slave SM process.
Prefix argument means switch to the SM buffer afterwards."
  (interactive "P")
  (save-excursion
    (let (
	  (proc (sm-process-proc))
	  (start (progn (beginning-of-line) (point)))
	  (end (progn (end-of-line) (point)))
	  )
      (sm-send-region start end proc)
      (sm-send-string "\n" proc)
      (if and-go (switch-to-sm t)))))

(defun sm-eval-other-window-current-line (&optional and-go)
  "execute sm-eval-current-line in the other window"
  (interactive "P")
  (other-window 1)
  (sm-eval-current-line and-go)
  (other-window -1))

(defun sm-eval-region (start end &optional and-go)
  "Send the current region to the slave SM process.
Prefix argument means switch to the SM buffer afterwards."
  (interactive "r\nP")
  (let ((proc (sm-process-proc)))
    (sm-send-region start end proc)
    (sm-send-string "\n" proc)
    (if and-go (switch-to-sm t))))

(defun sm-eval-current-buffer (&optional and-go)
  "Send the current buffer to the slave SM process. Stop at first line that
starts with \"return\" or \"RETURN\" (useful for sourcing macros at the
top of an executable file)

Prefix argument means switch to the SM buffer afterwards."
  (interactive "P")
  (let ((proc (sm-process-proc))
	(min (point-min))
	(max (point-max)))
    (save-excursion
      (goto-char min)
      (if (re-search-forward "^\\(return\\|RETURN\\)\\>" max t)
	  (progn
	    (beginning-of-line)      
	    (setq max (point)))))
    (if SM-macro-file
	(progn
	  (if (and (buffer-modified-p)
		   (y-or-n-p (format "Save file %s? " buffer-file-name)))
	      (save-buffer))
	  (message (format "Loading file: %s" buffer-file-name))
	  (sm-send-string (format "load %s \n" buffer-file-name) proc))
      (sm-send-region min max proc)
      (sm-send-string "\n" proc))
    (if and-go (switch-to-sm t))))

(defun sm-eval-current-macro (&optional and-go)
  "Define the macro around dot to the slave SM process; works even in
SM macro files. Prefix argument means switch to the SM buffer afterwards."
  (interactive "P")
  (let ((proc (sm-process-proc))
	(start) (end) (name) (nargs) (tmp))
    (save-excursion
      (if (not (looking-at "^[A-Za-z_0-9]"))
	  (beginning-of-SM-macro 1))
      (setq start (point))
      (if SM-macro-file
	  (progn
	    (skip-chars-forward "^ \t")
	    (setq name (buffer-substring start (point)))
	    (skip-chars-forward " \t")
	    (setq start (point))
	    (setq nargs
		  (if (looking-at "[0-9]")
		      (progn
			(skip-chars-forward "0-9")
			(buffer-substring start (point)))
		    "0"))
	    (skip-chars-forward "^ \t")
	    (setq start (point))
	    (end-of-SM-macro 1))
	(skip-chars-forward "^ \t")
	(skip-chars-forward " \t")
	(setq tmp (point))
	(skip-chars-forward "^ \t")
	(setq name (buffer-substring tmp (point)))
	(end-of-SM-macro 1))
      (setq end (point)))
    
    (message (format "Macro: %s" name))
    (if SM-macro-file
	(progn
	  (sm-send-string (format "macro %s %s {" name nargs) proc)
	  (sm-send-region start end proc)
	  (sm-send-string "}\n" proc))
      (sm-send-region start end proc)
      (sm-send-string "\n" proc))
    (if and-go (switch-to-sm t))))

(defun switch-to-sm (eob-p)
  "Switch to slave SM process buffer.
With argument, positions cursor at end of buffer."
  (interactive "P")
  (let ( (this (current-buffer)) )
    (if (get-buffer sm-process-buffer)
	(pop-to-buffer sm-process-buffer)
      (error "No current slave SM buffer"))
    (cond (eob-p
	   (push-mark)
	   (goto-char (point-max))))
    (pop-to-buffer this)))

(defun sm-process-proc ()
  "Return current slave SM process.
See variable `sm-process-buffer'."
  (let ((proc (get-buffer-process (if (eq major-mode 'sm-process-mode)
				      (current-buffer)
				    sm-process-buffer))))
    (or proc
	(error "No SM process; please execute \"run-sm\""))))

;;
;; Helper functions for enslaved SM mode.
;;

;; This exists to let us delete the prompt when commands are sent
;; directly to the slave SM process.  See gud.el for an explanation of how
;; it all works (it came from there via tcl-mode).

(defvar sm-process-delete-prompt-marker nil)

(defun sm-filter (proc string)
  (let ((inhibit-quit t))
    (save-excursion
      (set-buffer (process-buffer proc))
      (goto-char (process-mark proc))
      ;; Delete prompt if requested.
      (if (marker-buffer sm-process-delete-prompt-marker)
	  (progn
	    (delete-region (point) sm-process-delete-prompt-marker)
	    (set-marker sm-process-delete-prompt-marker nil)))))
  (if sm-using-emacs-19
      (comint-output-filter proc string)
    (funcall 'comint-output-filter proc string)))
