;;; helm-eca-test.el --- Tests for helm-eca -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for the chat label functions.  They use pure inputs only and
;; do not need a running ECA server.  Run with the deps (`eca', `helm') on
;; the load path; see AGENTS.md for the batch Emacs invocation.

;;; Code:

(require 'ert)
(require 'helm-eca)

(defun helm-eca-test--with-buffer-named (name fn)
  "Call FN with a temporary buffer whose name is NAME.

The buffer is killed afterwards.  NAME must not already be in use."
  (when (get-buffer name)
    (ert-skip (format "Buffer %s already exists" name)))
  (let ((buf (generate-new-buffer name)))
    (unwind-protect
        (funcall fn buf)
      (kill-buffer buf))))

;;;; ECA default chat buffer names

(ert-deftest helm-eca-default-chat-buffer-name-p-standard ()
  (should (helm-eca--default-chat-buffer-name-p
           "<eca-chat[7]:~:main>")))

(ert-deftest helm-eca-default-chat-buffer-name-p-duplicate ()
  (should (helm-eca--default-chat-buffer-name-p
           "<eca-chat[7]:~:main><2>")))

(ert-deftest helm-eca-default-chat-buffer-name-p-closed ()
  (should (helm-eca--default-chat-buffer-name-p
           "<eca-chat[7]:~:main>:closed")))

(ert-deftest helm-eca-default-chat-buffer-name-p-rejects-renamed ()
  (dolist (name '("*eca:commander:master*"
                  "eca-chat[7]:~:main"
                  "<eca-chat[7]:~:main> renamed"
                  "<eca-chat[7]:~:main><x>"))
    (should-not (helm-eca--default-chat-buffer-name-p name))))

(ert-deftest helm-eca-default-chat-buffer-name-p-non-string ()
  (should-not (helm-eca--default-chat-buffer-name-p nil))
  (should-not (helm-eca--default-chat-buffer-name-p 'symbol)))

(ert-deftest helm-eca-default-chat-buffer-name-p-varied-fields ()
  (dolist (name '("<eca-chat[project/name]:workspace:chat-123>"
                  "<eca-chat[project with spaces]:~:main><12>"
                  "<eca-chat[project]:session:chat>:closed"))
    (should (helm-eca--default-chat-buffer-name-p name))))

(ert-deftest helm-eca-default-chat-buffer-name-p-rejects-malformed ()
  (dolist (name '("<eca-chat:~:main>:closed"
                  "<eca-chat[]:~:main>"
                  "<eca-chat[project]:session>"
                  "<eca-chat[project]:session:chat>:closed-more"))
    (should-not (helm-eca--default-chat-buffer-name-p name))))

;;;; Label functions on buffers (session stubbed)

(ert-deftest helm-eca-chat-label-auto-uses-workspace-for-default-name ()
  (helm-eca-test--with-buffer-named
   "<eca-chat[7]:~:main>"
   (lambda (buf)
     (cl-letf (((symbol-function 'helm-eca-session-label)
                (lambda (_session) "myproject")))
       (let ((label (helm-eca-chat-label-auto 'fake-session buf)))
         (should (equal label "myproject"))
         (should (eq (get-text-property 0 'face label) 'shadow)))))))

(ert-deftest helm-eca-chat-label-auto-uses-raw-renamed-name ()
  (helm-eca-test--with-buffer-named
   "*eca:commander:master*"
   (lambda (buf)
     (cl-letf (((symbol-function 'helm-eca-session-label)
                (lambda (_session) "myproject")))
       (let ((label (helm-eca-chat-label-auto 'fake-session buf)))
         (should (equal label "*eca:commander:master*"))
         (should (eq (get-text-property 0 'face label) 'shadow)))))))

(ert-deftest helm-eca-chat-label-auto-uses-arbitrary-raw-name ()
  (helm-eca-test--with-buffer-named
   "Renamed by a tool"
   (lambda (buf)
     (cl-letf (((symbol-function 'helm-eca-session-label)
                (lambda (_session) "myproject")))
       (should (equal (helm-eca-chat-label-auto 'fake-session buf)
                      "Renamed by a tool"))))))

(ert-deftest helm-eca-chat-label-workspace-ignores-buffer-name ()
  (helm-eca-test--with-buffer-named
   "*eca:commander:master*"
   (lambda (buf)
     (cl-letf (((symbol-function 'helm-eca-session-label)
                (lambda (_session) "ws")))
       (should (equal (helm-eca-chat-label-workspace 'fake-session buf)
                      "ws"))))))

(ert-deftest helm-eca-chat-label-buffer-name-is-verbatim ()
  (helm-eca-test--with-buffer-named
   "*eca:commander:master*"
   (lambda (buf)
     (should (equal (helm-eca-chat-label-buffer-name 'fake-session buf)
                    "*eca:commander:master*")))))

(ert-deftest helm-eca-chat-label-respects-custom-function ()
  "A custom `helm-eca-chat-label-function' is honoured and gets `shadow'."
  (helm-eca-test--with-buffer-named
   "*eca:commander:master*"
   (lambda (buf)
     (let ((helm-eca-chat-label-function
            (lambda (session buffer)
              (format "%s/%s" session (buffer-name buffer)))))
       (let ((label (helm-eca-chat-label 'S buf)))
         (should (equal label "S/*eca:commander:master*"))
         (should (eq (get-text-property 0 'face label) 'shadow)))))))

(ert-deftest helm-eca-chat-label-keeps-existing-face ()
  (helm-eca-test--with-buffer-named
   "*renamed-chat*"
   (lambda (buf)
     (let ((helm-eca-chat-label-function
            (lambda (_session _buffer)
              (propertize "custom" 'face 'bold))))
       (should (eq (get-text-property 0 'face
                                       (helm-eca-chat-label 'S buf))
                   'bold))))))

(provide 'helm-eca-test)
;;; helm-eca-test.el ends here
