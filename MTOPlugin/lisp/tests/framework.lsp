;;; ============================================================
;;; framework.lsp -- Test framework toi gian cho MTO LISP
;;; Ghi ket qua ra FILE (tranh phu thuoc encoding console UTF-16)
;;; ============================================================

(if (null *MTO-TEST-PASS*) (setq *MTO-TEST-PASS* 0))
(if (null *MTO-TEST-FAIL*) (setq *MTO-TEST-FAIL* 0))
(if (null *MTO-TEST-LOG*)  (setq *MTO-TEST-LOG* '()))

(defun mto-test-reset ()
  (setq *MTO-TEST-PASS* 0)
  (setq *MTO-TEST-FAIL* 0)
  (setq *MTO-TEST-LOG* '()))

(defun mto-val->str (v)
  (cond
    ((null v) "nil")
    ((= (type v) 'STR) (strcat "\"" v "\""))
    ((= (type v) 'REAL) (rtos v 2 4))
    ((= (type v) 'INT) (itoa v))
    ((= (type v) 'SYM) (vl-symbol-name v))
    ((= (type v) 'LIST) (strcat "(" (mto-list->str v) ")"))
    (t (vl-princ-to-string v))))

(defun mto-list->str (l)
  (if (null l) ""
    (apply 'strcat (mapcar '(lambda (x) (strcat (mto-val->str x) " ")) l))))

(defun mto-test-pass (name)
  (setq *MTO-TEST-PASS* (1+ *MTO-TEST-PASS*))
  (setq *MTO-TEST-LOG* (cons (strcat "TEST-PASS: " name) *MTO-TEST-LOG*)))

(defun mto-test-fail (name detail)
  (setq *MTO-TEST-FAIL* (1+ *MTO-TEST-FAIL*))
  (setq *MTO-TEST-LOG* (cons (strcat "TEST-FAIL: " name " -- " detail) *MTO-TEST-LOG*)))

;; assert: bieu thuc dung
(defun mto-assert-true (name expr)
  (if expr
    (mto-test-pass name)
    (mto-test-fail name "expected non-nil, got nil")))

;; assert: bang nhau
(defun mto-assert-equal (name expected actual)
  (if (equal expected actual)
    (mto-test-pass name)
    (mto-test-fail name
      (strcat "expected=" (mto-val->str expected)
              " actual="   (mto-val->str actual)))))

;; assert: so gan bang (dung sai)
(defun mto-assert-close (name expected actual tol)
  (if (and (numberp expected) (numberp actual)
           (<= (abs (- expected actual)) tol))
    (mto-test-pass name)
    (mto-test-fail name
      (strcat "expected=" (mto-val->str expected)
              " actual="   (mto-val->str actual)
              " tol="      (mto-val->str tol)))))

;; Ghi ket qua ra file
(defun mto-write-results (path / f)
  (setq f (open path "w"))
  (if f
    (progn
      (foreach line (reverse *MTO-TEST-LOG*)
        (write-line line f))
      (write-line
        (strcat "TESTS: " (itoa *MTO-TEST-PASS*) "/"
                (itoa (+ *MTO-TEST-PASS* *MTO-TEST-FAIL*))
                " PASSED")
        f)
      (if (= *MTO-TEST-FAIL* 0)
        (write-line "RESULT: ALL-PASS" f)
        (write-line "RESULT: HAS-FAIL" f))
      (close f)
      (princ (strcat "\nMTO-TEST-RESULTS-WRITTEN")))
    (princ (strcat "\nMTO-TEST-CANNOT-OPEN: " path)))
  (princ))

(princ "\nframework.lsp loaded.")
(princ)
