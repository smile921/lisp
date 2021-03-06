(require 'pp)

(defun update-lispdoc-tags ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "^@c lispfun \\(.+\\)" nil t)
      (let ((name (match-string 1)) begin end)
	(message "Update lispdoc for function '%s'" name)
	(if (re-search-forward (concat "^@defun " name) nil t)
	    (setq begin (match-beginning 0)))
	(if (re-search-forward "^@end defun" nil t)
	    (setq end (match-end 0)))
	(if (and begin end)
	    (delete-region begin end))
	(let* ((sym (or (intern-soft name)
			(signal 'wrong-type-argument
				(list 'functionp name))))
	       (data (let ((func (symbol-function sym)))
		       (while (symbolp func)
			 (setq func (symbol-function func)))
		       func))
	       (args (pp-to-string (if (listp data)
				       (cadr data)
				     (aref data 0))))
	       (doc (documentation sym)))
	  (if (or (null doc) (= (length doc) 0))
	      (message "warning: no documentation available for '%s'" name)
	    (unless (and begin end)
	      (insert ?\n ?\n))
	    (insert (format "@defun %s %s\n" name
			    (substring args 1 (- (length args) 2))))
	    (setq begin (point))
	    (insert doc ?\n)
	    (save-restriction
	      (narrow-to-region begin (point))
	      (goto-char (point-min))
	      (let ((case-fold-search nil))
		(while (re-search-forward "[A-Z][A-Z-]+" nil t)
		  (replace-match (format "@var{%s}"
					 (downcase (match-string 0))) t t)))
	      (goto-char (point-max)))
	    (insert "@end defun")))))))

(defun chess-undocd-functions ()
  (interactive)
  (save-excursion
    (dolist (func (apropos-internal "^chess-" 'functionp))
      (goto-char (point-min))
      (unless (search-forward (concat "@c lispfun " (symbol-name func)) nil t)
	(message "Missing documentation for '%s'" (symbol-name func))))))

(provide 'lispdoc)
