;; todoo.el -- Major mode for editing TODO files

;; Copyright (C) 1999 Daniel Lundin <daniel@codefactory.se>
;; Copyright (C) 2004 Muli Ben-Yehuda <mulix@mulix.org>

;; Author: Daniel Lundin <daniel@codefactory.se>
;; Maintainer: Muli Ben-Yehuda <mulix@mulix.org>
;; Created: 6 Mar 2001
;; Version: $Id: todoo.el,v 1.2 2004/12/28 21:21:50 muli Exp $
;; Keywords: TODO, todo, project management

;; Contributions:
;; Johan Persson <johan.z.persson@gmail.com>

;; This file is NOT (yet) part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This software is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;; ----------------------------------------------------------------------

;;; Commentary:

;;  todoo.el is a mode for editing TODO files in an outline-mode fashion. 
;;  It has similarities to Oliver Seidel's todo-mode.el , but todoo.el
;;  has  been significantly simplified to better adhere to mine and
;;  other users' needs at the time. 

;; Installation example (~/.emacs):

;; (autoload 'todoo "todoo" "TODO Mode" t)
;; (add-to-list 'auto-mode-alist '("TODO$" . todoo-mode))

;; To show your personal todo-list:
;; M-x todoo

;; To be prompted a filename, supply any prefix to 'todoo':
;; C-u M-x todoo

;; For information on keybindings:
;; C-h f todoo-mode RET

;; Customize your todoo with:
;; M-x customize-group RET  todoo RET

;; Thanks to Kai Grossjohann for immediate feedback on the first
;; version, eventually leading to this more fit-for-human-consumption version.


;;; ChangeLog:

;; 1.7 - Added todoo-done-item and todoo-undone-item
;; 1.6 - Metadata - set the buffer to be modified whenever 
;;       the folding state changes, and set a hook so that 
;;       every save of the main buffer will also save the 
;;       metadata.
;; 1.4 - Metadata - save the point location in the file
;; 1.3 - Metadata support - save the folding and  reload it 
;;       when the file is next opened
;; 1.2 - Fixed bug in menu (todoo-show->todoo)
;;       Fixed bug when deleting window in todoo-save-and-exit
;;       Added early sub-item support (might be buggy, but still
;;          useful). 
;;       Added todoo-hide-item and todoo-show-item
;;       Added pop up menu
;;       Cleaned up keybindingss
;;       Cleaned up menubar
;; 1.1 - Code cleanup, renamed it todoo.el and made it more 
;; 1.0 - First version, derived from Olver Seidel's todo-mode.el

;;; Todo

;; * Extend item to be able to have at least one level of sub items 
;; * Insert items into a worklog.el worklog file upon removal for
;;   tracking progress.

;;; Code:

;; Required packages
(require 'outline)
(require 'custom)
(require 'easymenu)

(defgroup todoo nil
  "Maintain a list of todo items."
  :group 'calendar)


(defcustom todoo-show-pop-up-window t
  "*Wether to use a pop up window for 'todoo-show'."
  :type 'boolean
  :group 'todoo)

(defcustom todoo-collapse-items nil
  "*Wether to hide the body of multiline items."
  :type 'boolean
  :group 'todoo)

(defcustom todoo-indent-column 3
  "*Indent item body to 'todoo-indent-column' column."
  :type 'integer
  :group 'todoo)

(defcustom todoo-initials  (or (getenv "INITIALS") (user-login-name))
  "*Signature to be used for assigning todo items to oneself."
  :type 'string
  :group 'todoo)

(defcustom todoo-item-marker  "*"
  "*String used to indicate an unassigned item."
  :type 'string
  :group 'todoo)

(defcustom todoo-sub-item-marker  "-"
  "*String used to indicate a sub-item."
  :type 'string
  :group 'todoo)

(defcustom todoo-item-marker-assigned  "o"
  "*String used to indicate an assigned item."
  :type 'string
  :group 'todoo)

(defcustom todoo-item-marker-done  "x"
  "*String used to indicate a done item."
  :type 'string
  :group 'todoo)

(defcustom todoo-file-name "~/.todo"
  "*Default todo file opened by 'todoo-show'."
  :type 'file
  :group 'todoo)

(defcustom todoo-file-template (concat 
				"This is a sample todo list.\n\n"
				"* Sample item\n"
				"  This is a simple item\n\n"
				"  - Sub item\n"
				"    This is a sample sub-item\n\n")
  "*Template for creating the todo file ."
  :type 'string
  :group 'todoo)

(defcustom todoo-item-header-face 'todoo-item-header-face
  "Specify face used for unassigned items"
  :type 'face
  :group 'todoo)

(defcustom todoo-sub-item-header-face 'todoo-sub-item-header-face
  "Specify face used for sub-items"
  :type 'face
  :group 'todoo)

(defcustom todoo-item-assigned-header-face 'todoo-item-assigned-header-face
  "Specify face used for assigned items "
  :type 'face
  :group 'todoo)

(defcustom todoo-item-done-header-face 'todoo-item-done-header-face
  "Specify face used for assigned items "
  :type 'face
  :group 'todoo)


;;; Faces:

(defface todoo-item-header-face 
     '((t (:foreground "goldenrod" :bold t)))
   "Todoo-item unassigned header face")

(defface todoo-sub-item-header-face 
     '((t (:foreground "darkgoldenrod" :normal t)))
   "Todoo-sub-item header face")

(defface todoo-item-assigned-header-face 
     '((t (:foreground "red" :bold t)))
   "Todoo-item assigned header face")

(defface todoo-item-done-header-face 
     '((t (:foreground "gray" :strike-through t)))
   "Todoo-item done header face")


;;; Variables:

(defvar todoo-font-lock-keywords 
  (list
   (list (concat "^[ ]*" (regexp-quote todoo-item-marker) " .*$") 
	 0 'todoo-item-header-face t)
   (list (concat "^[ ]*" (regexp-quote todoo-sub-item-marker) " .*$") 
	 0 'todoo-sub-item-header-face t)
   (list (concat "^[ ]*" (regexp-quote todoo-item-marker-assigned) 
		 " \\[.*\\] .*$") 
	 0 'todoo-item-assigned-header-face t))
  "Fontlocking for 'todoo-mode'.")


;; Keymap
(defvar todoo-mode-map nil "'todoo-mode' keymap.")

(let ((map (make-keymap)))
  (define-key map "\C-c\C-s" 'todoo-save-and-exit)
;;  (define-key map "\C-c\C-b" 'todoo-assign-item)
;;  (define-key map "\C-c\C-d" 'todoo-unassign-item)
;;  (define-key map "\C-c\C-v" 'todoo-assign-item-to-self)
  (define-key map "\C-c\C-k" 'todoo-delete-item)
  (define-key map "\C-c\C-i" 'todoo-insert-item)
  (define-key map "\C-c\C-o" 'todoo-insert-sub-item)
  (define-key map "\C-c\C-t" 'hide-body)
  (define-key map "\C-c\C-h" 'hide-other)
  (define-key map "\C-c\C-a" 'show-all)
  (define-key map "\C-c\C-c" 'todoo-hide-item)
  (define-key map "\C-c\C-e" 'todoo-show-item)
  (define-key map "\C-c\C-p" 'outline-previous-visible-heading)
  (define-key map "\C-c\C-n" 'outline-next-visible-heading)
  (define-key map "\C-c\M-p" 'todoo-raise-item)
  (define-key map "\C-c\M-n" 'todoo-lower-item)
  (define-key map "\C-c\C-q" 'hide-sublevels)
  (define-key map "\C-c\C-d" 'hide-subtree)
  (define-key map "\C-c\C-v" 'show-subtree)
;;    (define-key map [C-up] 'outline-previous-visible-heading)
;;    (define-key map [C-down] 'outline-next-visible-heading)
;;    (define-key map [C-S-up] 'todoo-raise-item)
;;    (define-key map [C-S-down] 'todoo-lower-item)
  (setq todoo-mode-map map))

;; Menu
(easy-menu-define todoo-menu todoo-mode-map 
"'todoo-mode' menu"
                  '("Todoo"
		    ["Insert item" todoo-insert-item t]
		    ["Insert sub-item" todoo-insert-sub-item t]
                    ["Kill item" todoo-delete-item t]
		    "---"
                    ["Assign item to self" todoo-assign-item-to-self t]
                    ["Assign item to other" todoo-assign-item t]
                    ["Unassign item" todoo-unassign-item t]
		    "---"
                    ["Mark item done" todoo-done-item t]
                    ["Unmark item done" todoo-undone-item t]
                    "---"
                    ["Hide all"	hide-body t]
                    ["Show all" show-all t]
                    ["Hide item" todoo-hide-item t]
                    ["Show item" todoo-show-item t]
                    "---"
                    ["Raise item" todoo-raise-item t]
                    ["Lower item" todoo-lower-item t]
                    "---"
                    ["Customize" (customize-group "todoo") t]
                    "---"
                    ["Save and exit todoo-mode" todoo-save-and-exit t]
                    ))

;; Add todoo to the tools menubar
(define-key global-map [menu-bar tools nil] '("----" . nil))
(define-key global-map [menu-bar tools todoo] '("Todoo" . todoo))


(if (not (fboundp 'point-at-bol))
    (defsubst point-at-bol () "Return value of point at beginning of line."
      (save-excursion
       (beginning-of-line)
        (point))))


(if (not (fboundp 'point-at-eol))
    (defsubst point-at-eol () "Return value of point at end of line."
      (save-excursion
        (end-of-line)
        (point))))


(defsubst todoo-item-marker-regexp ()
  "Regexp for matching markers. Created from 'todoo-item-marker' and
'todoo-item-marker-assigned'"
  (concat "^\\(" (regexp-quote todoo-item-marker) "\\|"
	  (regexp-quote todoo-item-marker-assigned) "\\|"
          (regexp-quote todoo-item-marker-done) "\\) "))



(defun todoo-delete-item (&optional delete) 
  "Delete the current todoo-item. If DELETE is not nil, delete without
asking."
  (interactive "P")
  (if (> (count-lines (point-min) (point-max)) 0)
      (if (or delete (y-or-n-p "Remove item? "))
	  (progn 
	    (delete-region (todoo-item-start) (- (todoo-item-end) 1))
	    (message "Item removed"))
	(error "No TODO list entry to delete"))))


(defun todoo-item-start () 
  "Return point at start of current todoo-item."
  (save-excursion
    (beginning-of-line)
    (if (not (looking-at (todoo-item-marker-regexp)))
        (search-backward-regexp (todoo-item-marker-regexp) nil t))
    (point)))


(defun todoo-item-end () 
  "Return point at end of current todoo-item."
  (save-excursion
    (end-of-line)
    (search-forward-regexp (todoo-item-marker-regexp) nil 'goto-end)
    (- (point) (if (eq (point) (point-max)) 0 2))))


(defun todoo-hide-item () 
  "Hide the body of a todoo-item."
  (interactive)
  (save-excursion
    (goto-char (todoo-item-start))
    (hide-subtree)
    (set-buffer-modified-p t)))


(defun todoo-show-item () 
  "Hide the body of a todoo-item."
  (interactive)
  (save-excursion
    (goto-char (todoo-item-start))
    (show-subtree)
    (set-buffer-modified-p t)))

(defun todoo-done-item () 
  "Mark todo-item done."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (not (looking-at (todoo-item-marker-regexp)))
        (search-backward-regexp (todoo-item-marker-regexp) nil t))
    (if (or (re-search-forward 
             (concat "^" (regexp-quote todoo-item-marker) " ")
             (todoo-item-end) t)
            (re-search-forward 
             (concat "^" (regexp-quote todoo-item-marker-assigned) " ")
             (todoo-item-end) t))
        (replace-match (concat todoo-item-marker-done " ") nil nil)
      (message "doop"))))

(defun todoo-undone-item () 
  "Mark todo-item done."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (not (looking-at (todoo-item-marker-regexp)))
	(search-backward-regexp (todoo-item-marker-regexp) nil t))
    (if (re-search-forward 
         (concat "^" todoo-item-marker-done " \\[")
         (todoo-item-end) t)
        (replace-match 
         (concat todoo-item-marker-assigned " [") 
         nil nil)
      (if (re-search-forward
           (concat "^" todoo-item-marker-done " ")
           (todoo-item-end) t) 
          (replace-match (concat todoo-item-marker " ") nil nil)
        (message "Item is already active.")))))



(defun todoo-assign-item (&optional user) 
  "Assign todoo-item to USER. If USER is nil, prompt for it."
  (interactive "sAssign item to: ")
  (if (and user (> (length user) 0))
      (save-excursion
	(beginning-of-line)
	(if (not (looking-at (todoo-item-marker-regexp)))
	    (search-backward-regexp (todoo-item-marker-regexp) nil t))
	(if (re-search-forward 
	     (concat "^" (regexp-quote todoo-item-marker) " ")
	     (todoo-item-end) t)
	       (replace-match 
		(concat todoo-item-marker-assigned " [" user "] ") nil nil)
	  (if (re-search-forward 
	       (concat "^" todoo-item-marker-assigned " \\[.*\\] ")
	       (todoo-item-end) t)
	         (replace-match 
		  (concat todoo-item-marker-assigned " [" user "] ") 
		  nil nil))))))


(defun todoo-assign-item-to-self () 
  "Assign todoo-item to self, using 'todo-initials' as name."
  (interactive)
  (todoo-assign-item todoo-initials))


(defun todoo-unassign-item () 
  "Make todoo-item unassigned."
  (interactive "")
  (save-excursion
    (beginning-of-line)
    (if (not (looking-at (todoo-item-marker-regexp)))
	(search-backward-regexp (todoo-item-marker-regexp) nil t))
      (if (re-search-forward
	   (concat "^" todoo-item-marker-assigned " \\[.*\\]")
	   (todoo-item-end) t)
	      (replace-match "*" nil nil)
	(message "Item is already unassigned."))))


(defun todoo-raise-item () 
  "Raise todoo-item."
  (interactive)
  (kill-region (todoo-item-start) (todoo-item-end))
  (search-backward-regexp (todoo-item-marker-regexp) nil t)
  (yank)
  (search-backward-regexp (todoo-item-marker-regexp) nil t))


(defun todoo-lower-item () 
  "Lower todoo-item."
  (interactive)
    (kill-region (todoo-item-start) (todoo-item-end))
    (if (search-forward-regexp (todoo-item-marker-regexp) nil 'goto-end 2)
	(backward-char 2)
      (end-of-buffer))
    (yank)
    (search-backward-regexp  (todoo-item-marker-regexp) nil t))


(defun todoo-insert-item () 
  "Insert a new todoo-item."
  (interactive)
  (goto-char (- (todoo-item-end) 1))
  (insert "\n" todoo-item-marker " \n")
  (backward-char))


(defun todoo-insert-sub-item () 
  "Insert a new todoo-sub-item."
  (interactive)
  (goto-char (- (todoo-item-end) 1))
  (insert (concat "\n" (make-string todoo-indent-column ? )
		  todoo-sub-item-marker " \n"))
  (backward-char))


(defun todoo-indent-line ()
  "Indent a line properly according to 'todoo-mode'."
  (interactive)
  (beginning-of-line)

  (let ((indent-column todoo-indent-column))
    (if (eq (point) (point-at-eol))
	(insert (make-string indent-column ? )))
    (if (re-search-forward (concat "^[ ]*\\(" todoo-item-marker
				   "\\|" todoo-item-marker-assigned
				   "\\|" todoo-sub-item-marker
				   "\\)") (point-at-eol) t)
	(replace-match (concat (make-string (- indent-column
					       todoo-indent-column) ? ) "\\1")
		       nil nil)
      (if (re-search-forward "^[ ]*" (point-at-eol) t)
	  (replace-match (make-string indent-column ? )
			 nil nil)))))

(defun todoo-heading-is-hidden () 
  (re-search-backward "\^M" nil 'move))

(defun todoo-metadata-file-name (buf)
  (concat (buffer-file-name buf) ".todoo"))

(defun todoo-save-metadata (&optional buf)
  "Save the outline layout of the 'buf' todoo buffer."
  (interactive)
  (let* ((pt (point))
	 (hidden ())
	 (name (todoo-metadata-file-name buf))
	 (metadata (todoo-find-file-metadata-noselect name)))
    (save-excursion 
      (goto-char (point-max))
      (while (todoo-heading-is-hidden)
	(let* ((saved-point (point))
	       (this-point (progn
			     (goto-char (1+ (match-beginning 0)))
			     (point))))
	  (setq hidden (nconc hidden (list this-point)))
	  (goto-char saved-point))))
    (save-excursion
	(erase-buffer metadata)
	(set-buffer metadata)
	(insert (if (null hidden) "()" (format "%s " hidden)))
	(insert (format "%s" pt))
	(save-buffer)
	(kill-buffer metadata))))

(defun todoo-safe-read (buf)
  (condition-case nil
     (read buf)
    (error nil)))

(defun todoo-load-metadata (buf)
  "Load the outline layout of the 'buf' todoo buffer."
  (let* ((name (todoo-metadata-file-name buf))
	 (metadata (todoo-find-file-metadata-noselect name)))
    (set-buffer metadata)
    (beginning-of-buffer)
    (let* ((hidden (todoo-safe-read metadata))
	   (pt (or (todoo-safe-read metadata) 0)))
      (set-buffer buf)
      (mapcar 
       (lambda (x) (goto-char x) (hide-subtree))
       hidden)
      (goto-char pt))
    (kill-buffer metadata)))

(defun todoo-save-and-exit ()
  "If 'todoo-file' is open, save and kill its buffer and delete any window
that was created in 'todoo-show'. If 'todoo-file' is not open, save and kill
the current buffer if it is in 'todoo-mode'."
  (interactive)
  (let ((todoo-buffer (or (find-buffer-visiting
			   (substitute-in-file-name todoo-file-name))
			  (if (eq major-mode 'todoo-mode)
			      (current-buffer)))))
    (if todoo-buffer
	(progn
	  (set-buffer todoo-buffer)
	  (save-buffer)
	  (todoo-save-metadata todoo-buffer)
	  ; Delete window if created by todoo-show and still visible
	  (if (and (window-live-p todoo-show-created-window) 
		   (< 1 (count-windows)))
	      (delete-window todoo-show-created-window))
	  (kill-buffer todoo-buffer))
      (error "Todoo-mode not active"))))


(defun todoo-insert-template ()
  "Insert 'todoo-file-template' template into the current buffer."
  (beginning-of-buffer)
  (insert todoo-file-template))


(defun todoo-find-file-noselect (filename)
  "Open FILENAME without selecting its buffer, create it with a template
from 'todoo-insert-template' if necessary. Returns the buffer."
  (if (file-exists-p filename)
      (if (file-readable-p filename)
	  (find-file-noselect filename t)
	(error "Todoo-file not readable."))
    (let ((tbuf (find-file-noselect filename t)))
      (save-excursion
	(set-buffer tbuf)
	(todoo-insert-template))
      (message "Todoo-file '%s' created." filename) 
      tbuf)))

(defun todoo-find-file-metadata-noselect (filename)
  "Open FILENAME without selecting its buffer. Returns the buffer."
  (if (file-exists-p filename)
      (if (file-readable-p filename)
	  (find-file-noselect filename t)
	(error "Todoo-file not readable."))
    (let ((tbuf (find-file-noselect filename t)))
      tbuf)))

(defun todoo-show (filename) 
  "Open 'todoo-file-name' in 'todoo-mode'."
  (message "%s" filename)
  (let ((todoo-buffer (find-buffer-visiting filename))
	(wincount (count-windows)))
    (if (not todoo-buffer)
	(setq todoo-buffer (todoo-find-file-noselect filename))
	(or (verify-visited-file-modtime todoo-buffer)
	    (revert-buffer t t)))
    (set-buffer todoo-buffer)
    (let ((mode (symbol-value-in-buffer 'major-mode todoo-buffer)))
      (unless (eql mode 'todoo-mode)
	(todoo-mode)))
    ;; Load the buffer's metadata
    (todoo-load-metadata todoo-buffer)

    (if todoo-show-pop-up-window
	(pop-to-buffer todoo-buffer nil)
      (switch-to-buffer todoo-buffer))
    ;: Did we cause a new window?
    (if (< wincount (count-windows))
	(if (boundp 'todoo-show-created-window)
	    (setq todoo-show-created-window (get-buffer-window
					     todoo-buffer))
	  (error "Not in todoo-mode.")))))


(defun todoo (&optional prompt)
  "Interactive function for viewing a todo-file. If prefix arg PROMPT is
not NIL the user will be asked for a filename."
  (interactive "P")
  (let ((tfile (if prompt
		   (read-file-name "Todo-file: ")
		 (substitute-in-file-name todoo-file-name))))
    (todoo-show tfile)))

(defun metadata-save-hook () 
  (let ((after-save-hook nil))
    (todoo-save-metadata (current-buffer))))

(defun todoo-mode () 
  "Todoo-mode is a major mode for editing lists of
todo-items in an 'outline-mode' fashion.\n\n\\{todoo-mode-map}"
  (interactive)
  (kill-all-local-variables)

  (setq major-mode 'todoo-mode)
  (setq mode-name "Todoo")

  (use-local-map todoo-mode-map)
  (easy-menu-add todoo-menu)

  ;; Keep track of window creation when doing a pop up
  (make-local-variable 'todoo-show-created-window)
  (setq todoo-show-created-window nil)

  (make-local-variable 'paragraph-start)
  (setq paragraph-start (todoo-item-marker-regexp))

  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)

  (set-syntax-table text-mode-syntax-table)
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(todoo-font-lock-keywords t))

  (setq outline-regexp (concat "^\\(" (regexp-quote todoo-item-marker) " \\|"
			       (regexp-quote todoo-item-marker-assigned) 
			       " \\|[ ]*" (regexp-quote todoo-sub-item-marker)
			       " \\)"))

  (outline-minor-mode 1)

  (define-key outline-mode-menu-bar-map [headings] 'undefined)
  (define-key outline-mode-menu-bar-map [hide] 'undefined)
  (define-key outline-mode-menu-bar-map [show] 'undefined)

  (if todoo-collapse-items
      (hide-body))

  ; Custom indentation handling
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'todoo-indent-line)

  (setq fill-prefix (make-string todoo-indent-column ? ))
  (auto-fill-mode 1)

  ; Advertise how to leave todoo-mode
  (let* ((keys (where-is-internal 'todoo-save-and-exit
				  overriding-local-map nil nil))
	 (keys1 (mapconcat 'key-description keys ", ")))
    (if (> (length keys1) 0)
	(message "%s saves and exits todoo" keys1)))

  (setq mode-popup-menu
	'todoo-menu)

  (run-hooks 'todoo-mode-hook)
  (make-local-hook 'after-save-hook)
  (add-hook 'after-save-hook 'metadata-save-hook nil 'local))

(provide 'todoo)
;;; todoo.el ends here
