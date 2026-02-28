;;; helm-eca.el --- Helm UI for ECA chats/workspaces -*- lexical-binding: t; -*-

;; Copyright (C) 2026 PalaceChan
;; Author: PalaceChan <PalaceChan@users.noreply.github.com>
;; Maintainer: PalaceChan <PalaceChan@users.noreply.github.com>
;; URL: https://github.com/PalaceChan/helm-eca
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (eca "0.8.1") (helm "3.9.0"))
;; Keywords: tools, convenience
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;; This is a tiny Helm frontend for `eca-emacs`, intended as an alternative to
;; the widget/tree-based `eca-workspaces` buffer.

;;; Commentary:

;; Provides `helm-eca`:
;; - Source "ECA chats": all chat buffers across all sessions, displayed as:
;; WORKSPACE • CHAT-TITLE [USAGE]
;; - Source "ECA workspaces": all sessions (workspace roots)
;; This code uses some ECA internals (such as `eca--sessions` and `eca--session-chats`)
;; because eca-emacs doesn't currently expose a stable "list chats across sessions"
;; API.  If upstream changes those internals, small tweaks may be needed.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(require 'eca-util) ;; eca--sessions, eca-vals, eca--session struct accessors
(require 'eca-chat) ;; eca-chat-open + chat buffer locals

(require 'helm)
(require 'helm-source)

(defgroup helm-eca nil
  "Helm integration for ECA."
  :group 'tools
  :prefix 'helm-eca-)

(defcustom helm-eca-workspace-display 'basename
  "How to display workspace roots in Helm candidates."
  :type '(choice
          (const :tag "Basename (directory name)" basename)
          (const :tag "Abbreviated path" abbrev)
          (const :tag "Full path" full))
  :group 'helm-eca)

(defcustom helm-eca-separator " • "
  "Separator between workspace label and chat title."
  :type 'string
  :group 'helm-eca)

(defcustom helm-eca-show-usage t
  "Whether to show token/cost usage string when available."
  :type 'boolean
  :group 'helm-eca)

(defcustom helm-eca-loading-indicator "#"
  "Prefix shown for chats that are currently loading."
  :type 'string
  :group 'helm-eca)

(defcustom helm-eca-buffer-name "*helm eca*"
  "Helm buffer name used by `helm-eca`."
  :type 'string
  :group 'helm-eca)

(declare-function eca-workspaces "eca" ())

(defun helm-eca--sessions ()
  "Return a list of ECA sessions."
  (when (boundp 'eca--sessions)
    (eca-vals eca--sessions)))

(defun helm-eca--session-workspace-folders (session)
  "Return workspace folders for SESSION."
  (when (fboundp 'eca--session-workspace-folders)
    (eca--session-workspace-folders session)))

(defun helm-eca--session-chats (session)
  "Return the chat map for SESSION."
  (when (fboundp 'eca--session-chats)
    (eca--session-chats session)))

(defun helm-eca--session-status (session)
  "Return SESSION status."
  (when (fboundp 'eca--session-status)
    (eca--session-status session)))

(defun helm-eca--session-last-chat-buffer (session)
  "Return SESSION last chat buffer."
  (when (fboundp 'eca--session-last-chat-buffer)
    (eca--session-last-chat-buffer session)))

(defun helm-eca--session-p (obj)
  "Return non-nil if OBJ is an ECA session."
  (and (fboundp 'eca--session-p)
       (eca--session-p obj)))

(defun helm-eca--set-session-last-chat-buffer (session buffer)
  "Set SESSION last chat buffer to BUFFER."
  (when (fboundp 'eca--session-last-chat-buffer)
    (setf (eca--session-last-chat-buffer session) buffer)))

(defun helm-eca-format-workspace (path)
  "Format workspace PATH according to `helm-eca-workspace-display`."
  (pcase helm-eca-workspace-display
    ('basename (file-name-nondirectory (directory-file-name path)))
    ('abbrev (abbreviate-file-name (directory-file-name path)))
    ('full (expand-file-name path))
    (_ path)))

(defun helm-eca-session-label (session)
  "Return display label for SESSION workspace roots."
  (mapconcat #'helm-eca-format-workspace
             (helm-eca--session-workspace-folders session)
             ","))

(defun helm-eca-chat-title (buffer)
  "Return a human label for chat BUFFER."
  (with-current-buffer buffer
    (or (and (fboundp 'eca-chat-title)
             (ignore-errors (eca-chat-title)))
        (and (boundp 'eca-chat--custom-title)
             (symbol-value 'eca-chat--custom-title))
        (and (boundp 'eca-chat-custom-title)
             (symbol-value 'eca-chat-custom-title))
        (and (boundp 'eca-chat--title)
             (symbol-value 'eca-chat--title))
        (and (boundp 'eca-chat-title)
             (symbol-value 'eca-chat-title))
        (and (boundp 'eca-chat--id)
             (symbol-value 'eca-chat--id))
        (and (boundp 'eca-chat-id)
             (symbol-value 'eca-chat-id))
        (buffer-name buffer))))

(defun helm-eca-chat-usage (buffer)
  "Return usage string for chat BUFFER, or nil."
  (when (and helm-eca-show-usage
             (buffer-live-p buffer)
             (fboundp 'eca-chat--usage-str))
    (condition-case nil
        (with-current-buffer buffer
          (let ((s (eca-chat--usage-str)))
            (unless (or (null s) (string-empty-p s)) s)))
      (error nil))))

(defun helm-eca-chat-loading-p (buffer)
  "Return non-nil if chat BUFFER is currently loading."
  (with-current-buffer buffer
    (and (boundp 'eca-chat--chat-loading)
         (symbol-value 'eca-chat--chat-loading))))

(defun helm-eca-session-for-chat-buffer (buffer)
  "Return the ECA session object that owns chat BUFFER."
  (or (with-current-buffer buffer
        (when (and (boundp 'eca--session-id-cache)
                   (symbol-value 'eca--session-id-cache)
                   (boundp 'eca--sessions))
          (eca-get eca--sessions (symbol-value 'eca--session-id-cache))))
      (when (fboundp 'eca-session)
        (ignore-errors (with-current-buffer buffer (eca-session))))
      (cl-loop for session in (helm-eca--sessions)
               if (memq buffer (eca-vals (helm-eca--session-chats session)))
               return session)))

(defun helm-eca-chat-candidate (session buffer)
  "Build a Helm candidate (DISPLAY . BUFFER) for BUFFER in SESSION."
  (let* ((ws (helm-eca-session-label session))
         (title (helm-eca-chat-title buffer))
         (usage (helm-eca-chat-usage buffer))
         (loading (helm-eca-chat-loading-p buffer))
         (prefix (if loading helm-eca-loading-indicator "")))
    (cons (concat prefix
                  (propertize ws 'face 'shadow)
                  helm-eca-separator
                  title
                  (when usage
                    (concat " " (propertize usage 'face 'shadow))))
          buffer)))

(defun helm-eca-chat-candidates ()
  "Return Helm candidates for all live ECA chat buffers."
  (cl-loop with out = nil
           for session in (helm-eca--sessions)
           do (dolist (buf (eca-vals (helm-eca--session-chats session)))
                (when (buffer-live-p buf)
                  (push (helm-eca-chat-candidate session buf) out)))
           finally return (reverse out)))

(defun helm-eca-session-candidate (session)
  "Build a Helm candidate (DISPLAY . SESSION) for SESSION."
  (let* ((label (helm-eca-session-label session))
         (nchats (length (helm-eca--session-chats session)))
         (status (helm-eca--session-status session))
         (status-str (if status (symbol-name status) "unknown")))
    (cons (concat (propertize label 'face 'shadow)
                  (format " %s, %d chat%s" status-str nchats (if (= nchats 1) "" "s")))
          session)))

(defun helm-eca-session-candidates ()
  "Return Helm candidates for ECA sessions."
  (mapcar #'helm-eca-session-candidate (helm-eca--sessions)))

(defun helm-eca-open-chat (buffer)
  "Open BUFFER as the active chat using ECA's display logic."
  (unless (buffer-live-p buffer)
    (user-error "Chat buffer is no longer live!"))
  (let ((session (helm-eca-session-for-chat-buffer buffer)))
    (unless session
      (user-error "Couldn't find ECA session for %s" (buffer-name buffer)))
    (helm-eca--set-session-last-chat-buffer session buffer)
    (eca-chat-open session)))

(defun helm-eca-switch-to-chat-buffer (buffer)
  "Pop to chat BUFFER without going through `eca-chat-open'."
  (unless (buffer-live-p buffer)
    (user-error "Chat buffer is no longer live!"))
  (pop-to-buffer buffer))

(defun helm-eca-rename-chat (buffer)
  "Rename chat BUFFER.

Set buffer-local `eca-chat--custom-title`."
  (unless (buffer-live-p buffer)
    (user-error "Chat buffer is no longer live"))
  (let* ((old (helm-eca-chat-title buffer))
         (new (read-string (format "Rename chat (%s): " old))))
    (with-current-buffer buffer
      (cond
       ((boundp 'eca-chat--custom-title)
        (set (make-local-variable 'eca-chat--custom-title) new))
       ((boundp 'eca-chat-custom-title)
        (set (make-local-variable 'eca-chat-custom-title) new)))
      (force-mode-line-update t))
    (message "ECA chat renamed to: %s" new)))

(defun helm-eca-kill-chat-buffer (buffer)
  "Kill chat BUFFER (and close its window if visible)."
  (unless (buffer-live-p buffer)
    (user-error "Chat buffer is no longer live!"))
  (when-let ((win (get-buffer-window buffer t)))
    (quit-window nil win))
  (kill-buffer buffer))

(defun helm-eca-open-session (session)
  "Open SESSION using ECA's display logic (opens last chat)."
  (unless (helm-eca--session-p session)
    (user-error "Not a session: %S" session))
  (eca-chat-open session))

(defun helm-eca-new-chat-in-session (session)
  "Create a new chat in SESSION."
  (unless (helm-eca--session-p session)
    (user-error "Not a session: %S" session))
  (eca-chat-open session)
  (let ((buf (or (helm-eca--session-last-chat-buffer session)
                 (car (eca-vals (helm-eca--session-chats session))))))
    (unless (buffer-live-p buf)
      (user-error "Couldn't find a live chat buffer for that session"))
    (with-current-buffer buf
      (call-interactively #'eca-chat-new))))

(defvar helm-eca-source-chats
  (helm-build-sync-source "ECA chats"
    :candidates #'helm-eca-chat-candidates
    :action '(("Open chat (ECA)" . helm-eca-open-chat)
              ("Switch to buffer" . helm-eca-switch-to-chat-buffer)
              ("Rename chat" . helm-eca-rename-chat)
              ("Kill chat buffer" . helm-eca-kill-chat-buffer))))

(defvar helm-eca-source-sessions
  (helm-build-sync-source "ECA workspaces"
    :candidates #'helm-eca-session-candidates
    :action '(("Open workspace (ECA)" . helm-eca-open-session)
              ("New chat in workspace" . helm-eca-new-chat-in-session)
              ("Show workspaces tree" . eca-workspaces))))

;;;###autoload
(defun helm-eca ()
  "Helm UI to switch ECA workspaces and chats."
  (interactive)
  (if (null (helm-eca--sessions))
      (user-error "No ECA sessions are running (start one with M-x eca)")
    (helm :sources (list helm-eca-source-chats helm-eca-source-sessions)
          :buffer helm-eca-buffer-name)))

(provide 'helm-eca)
;;; helm-eca.el ends here
