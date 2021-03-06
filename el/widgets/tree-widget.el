;;; tree-widget.el --- Tree widget

;; Copyright (C) 2001, 2003 by David Ponce

;; Author: David Ponce <david@dponce.com>
;; Maintainer: David Ponce <david@dponce.com>
;; Created: 16 Feb 2001
;; Keywords: extensions
;; Revision: $Id: tree-widget.el,v 1.14 2003/10/03 15:30:27 ponced Exp $

(defconst tree-widget-version "2.0")

;; This file is not part of Emacs

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; This library provide a tree widget useful to display data
;; structures organized in a hierarchical order.
;;
;; The following properties are specific to the tree widget:
;;
;;   :open
;;      Set to non-nil to unfold the tree.  By default the tree is
;;      folded.
;;
;;   :node
;;      Specify the widget used to represent a tree node.  By default
;;      this is an `item' widget which displays the tree-widget :tag
;;      property value if defined or a string representation of the
;;      tree-widget value.
;;
;;   :keep
;;      Specify a list of properties to keep when the tree is
;;      folded so they can be recovered when the tree is unfolded.
;;      This property can be used in child widgets too.
;;
;;   :dynargs
;;      Specify a function to be called when the tree is unfolded, to
;;      dynamically provide the tree children in response to an unfold
;;      request.  This function will be passed the tree widget and
;;      must return a list of child widgets.  That list will be stored
;;      as the :args property of the parent tree.

;;      To speed up successive unfold requests, the :dynargs function
;;      can directly return the :args value if non-nil.  Refreshing
;;      child values can be achieved by giving the :args property the
;;      value nil, then redrawing the tree.
;;
;;   :has-children
;;      Specify if this tree has children.  This property has meaning
;;      only when used with the above :dynargs one.  It indicates that
;;      child widgets exist but will be dynamically provided when
;;      unfolding the node.
;;
;;   :open-control  (default `tree-widget-open-control')
;;   :close-control (default `tree-widget-close-control')
;;   :empty-control (default `tree-widget-empty-control')
;;   :leaf-control  (default `tree-widget-leaf-control')
;;   :guide         (default `tree-widget-guide')
;;   :end-guide     (default `tree-widget-end-guide')
;;   :no-guide      (default `tree-widget-no-guide')
;;   :handle        (default `tree-widget-handle')
;;   :no-handle     (default `tree-widget-no-handle')
;;
;; The above nine properties define the widgets used to draw the tree.
;; For example, using widgets that display this values:
;;
;;   open-control     "[-] "
;;   close-control    "[+] "
;;   empty-control    "[X] "
;;   leaf-control     "[>] "
;;   guide            " |"
;;   noguide          "  "
;;   end-guide        " `"
;;   handle           "-"
;;   no-handle        " "
;;
;; A tree will look like this:
;;
;;   [-] 1            open-control
;;    |-[+] 1.0       guide+handle+close-control
;;    |-[X] 1.1       guide+handle+empty-control
;;    `-[-] 1.2       end-guide+handle+open-control
;;       |-[>] 1.2.1  no-guide+no-handle+guide+handle+leaf-control
;;       `-[>] 1.2.2  no-guide+no-handle+end-guide+handle+leaf-control
;;
;; On versions of [X]Emacs that support this feature, the tree widget
;; try to use images instead of strings to draw a nice-looking tree.
;; See the `tree-widget-themes-directory' and `tree-widget-theme'
;; options for more details.
;;
;; Basic examples of tree-widget usage are provided in the file
;; tree-widget-examples.el.  A more sophisticated example is in the
;; dir-tree.el file.
;;
;; To install and use the tree widget first download the latest
;; distribution tarball (tree-widget-VERSION.tar.gz) from
;; <http://sourceforge.net/projects/emhacks/> and unpack it in a
;; directory on your `load-path'.  Then add the following into your
;; ~/.emacs startup file or in libraries that depend on tree-widget:
;;
;; (require 'tree-widget)
;;

;;; History:
;;

;;; Code:
(eval-when-compile (require 'cl))
(require 'wid-edit)

;;; Customization
;;
(defgroup tree-widget nil
  "Customization support for the Tree Widget Library."
  :group 'widgets)

(defcustom tree-widget-image-enable
  (not (or (featurep 'xemacs) (< emacs-major-version 21)))
  "*non-nil means that tree-widget will try to use images."
  :type  'boolean
  :group 'tree-widget)

(defcustom tree-widget-themes-directory nil
  "*Directory where to lookup for image themes.
If nil, use the \"tree-widget-themes\" subdirectory of the directory
where the tree-widget library is located."
  :type '(choice (const :tag "Default" nil)
                 (directory :format "%{%t%}:\n%v")
                 )
  :group 'tree-widget)

(defcustom tree-widget-theme nil
  "*Name of the theme to use to lookup for images.
The theme name must be a subdirectory in `tree-widget-themes-directory'.
If nil use the \"default\" theme.
When a image is not found in the current theme, the \"default\" theme
is searched too.
A complete theme should contain images with these file names:

Name         Represents
-----------  ------------------------------------------------
open         opened node (for example an open folder)
close        closed node (for example a close folder)
empty        empty node (a node without children)
leaf         leaf node (for example a document)
guide        a vertical guide line
no-guide     an invisible guide line
end-guide    the end of a vertical guide line
handle       an horizontal line drawn before a node control
no-handle    an invisible handle
-----------  ------------------------------------------------"
  :type '(choice (const  :tag "Default" nil)
                 (string :tag "Name"))
  :group 'tree-widget)

(defcustom tree-widget-image-properties-emacs
  '(:ascent center :mask (heuristic t))
  "*Properties of GNU Emacs images."
  :type 'plist
  :group 'tree-widget)

(defcustom tree-widget-image-properties-xemacs
  nil
  "*Properties of XEmacs images."
  :type 'plist
  :group 'tree-widget)

;;; Image support
;;
(eval-when-compile ;; GNU Emacs/XEmacs compatibility stuff
  (cond
   ;; XEmacs
   ((featurep 'xemacs)
    (defsubst tree-widget-use-image-p ()
      "Return non-nil if image support is currently enabled."
      (and tree-widget-image-enable
           widget-glyph-enable
           (console-on-window-system-p)))
    (defsubst tree-widget-image-type-available-p (type)
      "Return non-nil if image type TYPE is available.
Image types are symbols like `xbm' or `jpeg'."
      (valid-image-instantiator-format-p type))
    (defsubst tree-widget-create-image (type file)
      "Create an image of type TYPE from FILE.
Give the image the specified `tree-widget-image-properties-xemacs'
properties.  Return the new image."
      (apply 'make-glyph
             `([,type :file ,file
                      ,@tree-widget-image-properties-xemacs])))
    (defsubst tree-widget-image-formats ()
      "Return the list of image formats, file name suffixes associations.
See also the option `widget-image-file-name-suffixes'."
      widget-image-file-name-suffixes)
    )
   ;; GNU Emacs
   (t
    (defsubst tree-widget-use-image-p ()
      "Return non-nil if image support is currently enabled."
      (and tree-widget-image-enable
           widget-image-enable
           (display-images-p)))
    (defsubst tree-widget-image-type-available-p (type)
      "Return non-nil if image type TYPE is available.
Image types are symbols like `xbm' or `jpeg'."
      (image-type-available-p type))
    (defsubst tree-widget-create-image (type file)
      "Create an image of type TYPE from FILE.
Give the image the specified `tree-widget-image-properties-emacs'
properties.  Return the new image."
      (apply 'create-image
             `(,file ,type nil
                     ,@tree-widget-image-properties-emacs)))
    (defsubst tree-widget-image-formats ()
      "Return the list of image formats, file name suffixes associations.
See also the option `widget-image-conversion'."
      widget-image-conversion)
    ))
  )

(defvar tree-widget--image-cache nil)
(make-variable-buffer-local 'tree-widget--image-cache)
(defvar tree-widget--theme nil)
(make-variable-buffer-local 'tree-widget--theme)

(defsubst tree-widget-set-theme (&optional name)
  "Define the current image theme to use.
The theme is defined locally to the current buffer, where the tree
widget is drawn.  Also clear the image cache.
If optional argument NAME is non-nil, it is the name of the theme to
use.  By default it is the global theme defined by the option
`tree-widget-theme'."
  (setq tree-widget--image-cache nil
        tree-widget--theme (or name tree-widget-theme "default")))

(defsubst tree-widget-themes-directory ()
  "Return the directory where to search for image themes.
Return nil if not found."
  (let ((dir (if tree-widget-themes-directory
                 (expand-file-name tree-widget-themes-directory)
               (expand-file-name "../tree-widget-themes"
                                 (locate-library "tree-widget")))))
    (and (file-directory-p dir) dir)))

(defun tree-widget-find-image (image-name)
  "Create the image with IMAGE-NAME found in current theme.
IMAGE-NAME must be a file name sans extension located in the current
theme directory (see the options `tree-widget-themes-directory' and
`tree-widget-theme').  Use the first image found having a supported
format in those returned by the function `tree-widget-image-formats'.
Return the image found or nil if not found."
  (cond
   ;; No image support
   ((not (tree-widget-use-image-p))
    nil)
   ;; Image with IMAGE-NAME found in cache
   ((cdr (assoc image-name tree-widget--image-cache))
    )
   ;; Search for an image with IMAGE-NAME
   (t
    (let ((dir (tree-widget-themes-directory)))
      (when dir
        ;; Don't use `tree-widget-set-theme' here, because it clears
        ;; the image cache.
        (setq tree-widget--theme
              (or tree-widget--theme tree-widget-theme "default"))
        (let* ((default-directory dir)
               (path (mapcar 'expand-file-name
                             (list tree-widget--theme "default")))
               (fmts (tree-widget-image-formats))
               fmt file image)
          (while (and fmts (not file))
            (setq fmt  (car fmts)
                  fmts (cdr fmts))
            (when (tree-widget-image-type-available-p (car fmt))
              (setq file (locate-library
                          (concat image-name (nth 1 fmt)) t path))))
          (when file
            (setq image (tree-widget-create-image (car fmt) file))
            ;; Add the image into the cache.
            (push (cons image-name image) tree-widget--image-cache)
            image))))
    )))

;;; Widgets
;;
(defvar tree-widget-button-keymap
  (let (parent-keymap mouse-button1 keymap)
    (if (featurep 'xemacs)
        (setq parent-keymap widget-button-keymap
              mouse-button1 [button1])
      (setq parent-keymap widget-keymap
            mouse-button1 [down-mouse-1]))
    (setq keymap (copy-keymap parent-keymap))
    (define-key keymap mouse-button1 'widget-button-click)
    keymap)
  "Keymap used inside node handle buttons.")

(define-widget 'tree-widget-control 'push-button
  "Base `tree-widget' control."
  :format        "%[%t%]"
  :button-keymap tree-widget-button-keymap ; XEmacs
  :keymap        tree-widget-button-keymap ; Emacs
  )

(define-widget 'tree-widget-open-control 'tree-widget-control
  "Control widget that represents a opened `tree-widget' node."
  :tag       "[-] "
  ;;:tag-glyph (tree-widget-find-image "open")
  :notify    'tree-widget-close-node
  :help-echo "Hide node"
  )

(define-widget 'tree-widget-empty-control 'tree-widget-open-control
  "Control widget that represents an empty opened `tree-widget' node."
  :tag       "[X] "
  ;;:tag-glyph (tree-widget-find-image "empty")
  )

(define-widget 'tree-widget-close-control 'tree-widget-control
  "Control widget that represents a closed `tree-widget' node."
  :tag       "[+] "
  ;;:tag-glyph (tree-widget-find-image "close")
  :notify    'tree-widget-open-node
  :help-echo "Show node"
  )

(define-widget 'tree-widget-leaf-control 'item
  "Control widget that represents a leaf node."
  :tag       " " ;; Need at least a char to display the image :-(
  ;;:tag-glyph (tree-widget-find-image "leaf")
  :format    "%t"
  )

(define-widget 'tree-widget-guide 'item
  "Widget that represents a guide line."
  :tag       " |"
  ;;:tag-glyph (tree-widget-find-image "guide")
  :format    "%t"
  )

(define-widget 'tree-widget-end-guide 'item
  "Widget that represents the end of a guide line."
  :tag       " `"
  ;;:tag-glyph (tree-widget-find-image "end-guide")
  :format    "%t"
  )

(define-widget 'tree-widget-no-guide 'item
  "Widget that represents an invisible guide line."
  :tag       "  "
  ;;:tag-glyph (tree-widget-find-image "no-guide")
  :format    "%t"
  )

(define-widget 'tree-widget-handle 'item
  "Widget that represent a node handle."
  :tag       " "
  ;;:tag-glyph (tree-widget-find-image "handle")
  :format    "%t"
  )

(define-widget 'tree-widget-no-handle 'item
  "Widget that represent an invisible node handle."
  :tag       " "
  ;;:tag-glyph (tree-widget-find-image "no-handle")
  :format    "%t"
  )

(define-widget 'tree-widget 'default
  "Tree widget."
  :format         "%v"
  :convert-widget 'widget-types-convert-widget
  :value-get      'widget-value-value-get
  :value-create   'tree-widget-value-create
  :value-delete   'tree-widget-value-delete
  )

;;; Widget support functions
;;
(defun tree-widget-p (widget)
  "Return non-nil if WIDGET is a `tree-widget' widget."
  (let ((type (widget-type widget)))
    (while (and type (not (eq type 'tree-widget)))
      (setq type (widget-type (get type 'widget-type))))
    (eq type 'tree-widget)))

(defsubst tree-widget-get-super (widget property)
  "Return WIDGET's inherited PROPERTY value."
  (widget-get (get (widget-type (get (widget-type widget)
                                     'widget-type))
                   'widget-type)
              property))

(defsubst tree-widget-super-format-handler (widget escape)
  "Call WIDGET's inherited format handler to process ESCAPE character."
  (let ((handler (tree-widget-get-super widget :format-handler)))
    (and handler (funcall handler widget escape))))

(defun tree-widget-format-handler (widget escape)
  "For WIDGET, signal that the %p format template is obsolete.
Call WIDGET's inherited format handler to process other ESCAPE
characters."
  (if (eq escape ?p)
      (message "The %p format template is obsolete and ignored")
    (tree-widget-super-format-handler widget escape)))
(make-obsolete 'tree-widget-format-handler
               'tree-widget-super-format-handler)

(defsubst tree-widget-node (widget)
  "Return the tree WIDGET :node value.
If not found setup a default 'item' widget."
  (let ((node (widget-get widget :node)))
    (unless node
      (setq node `(item :tag ,(or (widget-get widget :tag)
                                  (widget-princ-to-string
                                   (widget-value widget)))))
      (widget-put widget :node node))
    node))

(defsubst tree-widget-open-control (widget)
  "Return the opened node control specified in WIDGET."
  (or (widget-get widget :open-control)
      'tree-widget-open-control))

(defsubst tree-widget-close-control (widget)
  "Return the closed node control specified in WIDGET."
  (or (widget-get widget :close-control)
      'tree-widget-close-control))

(defsubst tree-widget-empty-control (widget)
  "Return the empty node control specified in WIDGET."
  (or (widget-get widget :empty-control)
      'tree-widget-empty-control))

(defsubst tree-widget-leaf-control (widget)
  "Return the leaf node control specified in WIDGET."
  (or (widget-get widget :leaf-control)
      'tree-widget-leaf-control))

(defsubst tree-widget-guide (widget)
  "Return the guide line widget specified in WIDGET."
  (or (widget-get widget :guide)
      'tree-widget-guide))

(defsubst tree-widget-end-guide (widget)
  "Return the end of guide line widget specified in WIDGET."
  (or (widget-get widget :end-guide)
      'tree-widget-end-guide))

(defsubst tree-widget-no-guide (widget)
  "Return the invisible guide line widget specified in WIDGET."
  (or (widget-get widget :no-guide)
      'tree-widget-no-guide))

(defsubst tree-widget-handle (widget)
  "Return the node handle line widget specified in WIDGET."
  (or (widget-get widget :handle)
      'tree-widget-handle))

(defsubst tree-widget-no-handle (widget)
  "Return the node invisible handle line widget specified in WIDGET."
  (or (widget-get widget :no-handle)
      'tree-widget-no-handle))

(defun tree-widget-keep (arg widget)
  "Save in ARG the WIDGET properties specified by :keep."
  (dolist (prop (widget-get widget :keep))
    (widget-put arg prop (widget-get widget prop))))

(defun tree-widget-children-value-save (widget &optional args node)
  "Save WIDGET children values.
Children properties and values are saved in ARGS if non-nil else in
WIDGET :args property value.  Data node properties and value are saved
in NODE if non-nil else in WIDGET :node property value."
  (let ((args       (or args (widget-get widget :args)))
        (node       (or node (tree-widget-node widget)))
        (children   (widget-get widget :children))
        (node-child (widget-get widget :tree-widget--node))
        arg child)
    (while (and args children)
      (setq arg      (car args)
            args     (cdr args)
            child    (car children)
            children (cdr children))
       (if (tree-widget-p child)
;;;; The child is a tree node.
           (progn
             ;; Backtrack :args and :node properties.
             (widget-put arg :args (widget-get child :args))
             (widget-put arg :node (tree-widget-node child))
             ;; Save :open property.
             (widget-put arg :open (widget-get child :open))
             ;; The node is open.
             (when (widget-get child :open)
               ;; Save the widget value.
               (widget-put arg :value (widget-value child))
               ;; Save properties specified in :keep.
               (tree-widget-keep arg child)
               ;; Save children.
               (tree-widget-children-value-save
                child (widget-get arg :args) (widget-get arg :node))))
;;;; Another non tree node.
         ;; Save the widget value
         (widget-put arg :value (widget-value child))
         ;; Save properties specified in :keep.
         (tree-widget-keep arg child)))
    (when (and node node-child)
      ;; Assume that the node child widget is not a tree!
      ;; Save the node child widget value.
      (widget-put node :value (widget-value node-child))
      ;; Save the node child properties specified in :keep.
      (tree-widget-keep node node-child))
    ))

(defvar tree-widget-after-toggle-functions nil
  "Hooks run after toggling a `tree-widget' folding.
Each function will receive the `tree-widget' as its unique argument.
This variable should be local to each buffer used to display
widgets.")

(defun tree-widget-close-node (widget &rest ignore)
  "Close the `tree-widget' node associated to this control WIDGET.
WIDGET's parent should be a `tree-widget'.
IGNORE other arguments."
  (let ((tree (widget-get widget :parent)))
    ;; Before folding the node up, save children values so next open
    ;; can recover them.
    (tree-widget-children-value-save tree)
    (widget-put tree :open nil)
    (widget-value-set tree nil)
    (run-hook-with-args 'tree-widget-after-toggle-functions tree)))

(defun tree-widget-open-node (widget &rest ignore)
  "Open the `tree-widget' node associated to this control WIDGET.
WIDGET's parent should be a `tree-widget'.
IGNORE other arguments."
  (let ((tree (widget-get widget :parent)))
    (widget-put tree :open t)
    (widget-value-set tree t)
    (run-hook-with-args 'tree-widget-after-toggle-functions tree)))

(defun tree-widget-value-delete (widget)
  "Delete tree WIDGET children."
  ;; Delete children
  (widget-children-value-delete widget)
  ;; Delete node child
  (widget-delete (widget-get widget :tree-widget--node))
  (widget-put widget :tree-widget--node nil))

(defun tree-widget-value-create (tree)
  "Create the TREE widget."
  (let* ((widget-image-enable (tree-widget-use-image-p))     ; Emacs
         (widget-glyph-enable widget-image-enable)           ; XEmacs
         (node (tree-widget-node tree))
         children buttons)
    (if (widget-get tree :open)
;;;; Unfolded node.
        (let* ((args     (widget-get tree :args))
               (dynargs  (widget-get tree :dynargs))
               (flags    (widget-get tree :tree-widget--guide-flags))
               (rflags   (reverse flags))
               (guide    (tree-widget-guide     tree))
               (noguide  (tree-widget-no-guide  tree))
               (endguide (tree-widget-end-guide tree))
               (handle   (tree-widget-handle    tree))
               (nohandle (tree-widget-no-handle tree))
               ;; Lookup for images and set widgets' tag-glyphs here,
               ;; to allow to dynamically change the image theme.
               (guidi    (tree-widget-find-image "guide"))
               (noguidi  (tree-widget-find-image "no-guide"))
               (endguidi (tree-widget-find-image "end-guide"))
               (handli   (tree-widget-find-image "handle"))
               (nohandli (tree-widget-find-image "no-handle"))
               child)
          (when dynargs
            ;; Request the definition of dynamic children
            (setq dynargs (funcall dynargs tree))
            ;; Unless children have changed, reuse the widgets
            (unless (eq args dynargs)
              (setq args (mapcar 'widget-convert dynargs))
              (widget-put tree :args args)))
          ;; Insert the node control
          (push (widget-create-child-and-convert
                 tree (if args (tree-widget-open-control tree)
                        (tree-widget-empty-control tree))
                 :tag-glyph (tree-widget-find-image
                             (if args "open" "empty")))
                buttons)
          ;; Insert the node element
          (widget-put tree :tree-widget--node
                      (widget-create-child-and-convert tree node))
          ;; Insert children
          (while args
            (setq child (car args)
                  args  (cdr args))
            ;; Insert guide lines elements
            (dolist (f rflags)
              (widget-create-child-and-convert
               tree (if f guide noguide)
               :tag-glyph (if f guidi noguidi))
              (widget-create-child-and-convert
               tree nohandle :tag-glyph nohandli)
              )
            (widget-create-child-and-convert
             tree (if args guide endguide)
             :tag-glyph (if args guidi endguidi))
            ;; Insert the node handle line
            (widget-create-child-and-convert
             tree handle :tag-glyph handli)
            ;; If leaf node, insert a leaf node control
            (unless (tree-widget-p child)
              (push (widget-create-child-and-convert
                     tree (tree-widget-leaf-control tree)
                     :tag-glyph (tree-widget-find-image "leaf"))
                    buttons))
            ;; Insert the child element
            (push (widget-create-child-and-convert
                   tree child
                   :tree-widget--guide-flags (cons (if args t) flags))
                  children)))
;;;; Folded node.
      ;; Insert the closed node control
      (push (widget-create-child-and-convert
             tree (tree-widget-close-control tree)
             :tag-glyph (tree-widget-find-image "close"))
            buttons)
      ;; Insert the node element
      (widget-put tree :tree-widget--node
                  (widget-create-child-and-convert tree node)))
    ;; Save widget children and buttons
    (widget-put tree :children (nreverse children))
    (widget-put tree :buttons  buttons)
    ))

;;; Utilities
;;
(defun tree-widget-map (widget fun)
  "For each WIDGET displayed child call function FUN.
FUN is called with three arguments like this:

 (FUN CHILD IS-NODE WIDGET)

where:
- - CHILD is the child widget.
- - IS-NODE is non-nil if CHILD is WIDGET node widget."
  (when (widget-get widget :tree-widget--node)
    (funcall fun (widget-get widget :tree-widget--node) t widget)
    (dolist (child (widget-get widget :children))
      (if (tree-widget-p child)
          ;; The child is a tree node.
          (tree-widget-map child fun)
        ;; Another non tree node.
        (funcall fun child nil widget)))))

(provide 'tree-widget)

;;; tree-widget.el ends here
