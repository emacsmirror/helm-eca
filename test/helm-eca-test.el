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

;;;; helm-eca-fleet-label: buffer name -> Fleet identity

(ert-deftest helm-eca-fleet-label-commander ()
  (should (equal (helm-eca-fleet-label "*eca:commander:master*")
                 "commander:master")))

(ert-deftest helm-eca-fleet-label-lieutenant ()
  (should (equal (helm-eca-fleet-label "*eca:lieutenant:master/openclaw*")
                 "lieutenant:master/openclaw")))

(ert-deftest helm-eca-fleet-label-operator-task ()
  (should (equal (helm-eca-fleet-label "*eca:operator:master/fleet:my-task*")
                 "operator:master/fleet:my-task")))

(ert-deftest helm-eca-fleet-label-detached-short-id ()
  (should (equal (helm-eca-fleet-label "*eca:operator:master/fleet:my-task:a1b2c3*")
                 "operator:master/fleet:my-task:a1b2c3")))

(ert-deftest helm-eca-fleet-label-lenient-grammar ()
  "Anything between `*eca:' and the trailing `*' is accepted verbatim."
  (should (equal (helm-eca-fleet-label "*eca:future role/with spaces*")
                 "future role/with spaces")))

(ert-deftest helm-eca-fleet-label-rejects-regular-eca-chat ()
  (should-not (helm-eca-fleet-label "<eca-chat[1]:~:main>"))
  (should-not (helm-eca-fleet-label "<eca-chat:~:main>:closed")))

(ert-deftest helm-eca-fleet-label-rejects-near-misses ()
  (should-not (helm-eca-fleet-label "*eca:*"))
  (should-not (helm-eca-fleet-label "*eca*"))
  (should-not (helm-eca-fleet-label "eca:commander:master"))
  (should-not (helm-eca-fleet-label "*eca:commander:master"))
  (should-not (helm-eca-fleet-label "x*eca:commander:master*"))
  (should-not (helm-eca-fleet-label "*scratch*")))

(ert-deftest helm-eca-fleet-label-non-string ()
  (should-not (helm-eca-fleet-label nil))
  (should-not (helm-eca-fleet-label 'symbol)))

;;;; Label functions on buffers (session stubbed)

(ert-deftest helm-eca-chat-label-auto-uses-fleet-identity ()
  (helm-eca-test--with-buffer-named
   "*eca:lieutenant:master/fleet*"
   (lambda (buf)
     (cl-letf (((symbol-function 'helm-eca-session-label)
                (lambda (_session) "ws")))
       (let ((label (helm-eca-chat-label-auto 'fake-session buf)))
         (should (equal label "lieutenant:master/fleet"))
         (should (eq (get-text-property 0 'face label)
                     'helm-eca-fleet-label)))))))

(ert-deftest helm-eca-chat-label-auto-falls-back-to-workspace ()
  (helm-eca-test--with-buffer-named
   "<eca-chat[7]:~:main>"
   (lambda (buf)
     (cl-letf (((symbol-function 'helm-eca-session-label)
                (lambda (_session) "myproject")))
       (let ((label (helm-eca-chat-label-auto 'fake-session buf)))
         (should (equal label "myproject"))
         (should (eq (get-text-property 0 'face label) 'shadow)))))))

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
   "*eca:commander:master*"
   (lambda (buf)
     (let ((helm-eca-chat-label-function #'helm-eca-chat-label-auto))
       (should (eq (get-text-property 0 'face (helm-eca-chat-label 'S buf))
                   'helm-eca-fleet-label))))))

(provide 'helm-eca-test)
;;; helm-eca-test.el ends here
