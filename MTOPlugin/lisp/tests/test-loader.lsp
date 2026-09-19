;;; ============================================================
;;; test-loader.lsp -- Test cases cho mto-loader.lsp
;;; ============================================================

(defun mto-run-tests (out-path / res base n)

  (mto-test-reset)

  ;; ---------- 1. danh sach module ----------

  (mto-assert-true "modules: *MTO-MODULES* ton tai"
    (listp *MTO-MODULES*))

  (mto-assert-equal "modules: co 17 module (PHASE 1+2+3+4 + UI)"
    17 (length *MTO-MODULES*))

  (mto-assert-true "modules: co mto-core.lsp"
    (member "mto-core.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-orphan.lsp"
    (member "mto-orphan.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-table.lsp (PHASE 2)"
    (member "mto-table.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-undo.lsp (PHASE 2)"
    (member "mto-undo.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-formula.lsp (PHASE 3)"
    (member "mto-formula.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-subtotal.lsp (PHASE 3)"
    (member "mto-subtotal.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-ui.lsp (hien thi ten lenh)"
    (member "mto-ui.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-floor.lsp (PHASE 4)"
    (member "mto-floor.lsp" *MTO-MODULES*))

  (mto-assert-true "modules: co mto-config.lsp (PHASE 4)"
    (member "mto-config.lsp" *MTO-MODULES*))

  (mto-assert-true "version: khai bao phien ban"
    (and *MTO-VERSION* (/= *MTO-VERSION* "")))

  ;; ---------- 2. load-modules voi thu muc THAT ----------

  ;; thu muc cua test nay: <lisp>/tests -> lisp la cha
  (setq base (vl-filename-directory out-path))
  ;; out = <lisp>/tests/out -> len 2 cap
  (setq base (vl-filename-directory base))          ; <lisp>/tests
  (setq base (vl-filename-directory base))          ; <lisp>

  (setq res (mto-load-modules base))
  (mto-assert-equal "load: OK = 17 file"
    17 (cdr (assoc 'OK res)))
  (mto-assert-equal "load: FAIL = 0"
    0 (cdr (assoc 'FAIL res)))
  (mto-assert-equal "load: khong thieu file nao"
    nil (cdr (assoc 'MISSING res)))

  ;; ---------- 3. load voi thu muc SAI -> bao thieu ----------

  (setq res (mto-load-modules "D:/khong-ton-tai-thu-muc-nay"))
  (mto-assert-equal "load sai: OK = 0"
    0 (cdr (assoc 'OK res)))
  (mto-assert-equal "load sai: FAIL = 17"
    17 (cdr (assoc 'FAIL res)))
  (mto-assert-equal "load sai: liet ke 17 file thieu"
    17 (length (cdr (assoc 'MISSING res))))

  ;; ---------- 4. cac ham command ton tai sau khi load ----------

  (mto-assert-true "command: MTOSEL dinh nghia"
    (not (null (vl-symbol-value 'c:MTOSEL))))
  (mto-assert-true "command: MTOTEXT dinh nghia"
    (not (null (vl-symbol-value 'c:MTOTEXT))))
  (mto-assert-true "command: MTOBLK dinh nghia"
    (not (null (vl-symbol-value 'c:MTOBLK))))
  (mto-assert-true "command: MTOGEO dinh nghia"
    (not (null (vl-symbol-value 'c:MTOGEO))))
  (mto-assert-true "command: MTOLIST dinh nghia"
    (not (null (vl-symbol-value 'c:MTOLIST))))
  (mto-assert-true "command: MTOCSV dinh nghia"
    (not (null (vl-symbol-value 'c:MTOCSV))))
  (mto-assert-true "command: MTOORPHAN dinh nghia"
    (not (null (vl-symbol-value 'c:MTOORPHAN))))
  (mto-assert-true "command: MTOTABLE dinh nghia (PHASE 2)"
    (not (null (vl-symbol-value 'c:MTOTABLE))))
  (mto-assert-true "command: MTOFIND dinh nghia (PHASE 2)"
    (not (null (vl-symbol-value 'c:MTOFIND))))
  (mto-assert-true "command: MTOUPDATE dinh nghia (PHASE 2)"
    (not (null (vl-symbol-value 'c:MTOUPDATE))))
  (mto-assert-true "command: MTOUNDO dinh nghia (PHASE 2)"
    (not (null (vl-symbol-value 'c:MTOUNDO))))
  (mto-assert-true "command: MTOSNAP dinh nghia (PHASE 2)"
    (not (null (vl-symbol-value 'c:MTOSNAP))))
  (mto-assert-true "command: MTOGOTO dinh nghia (PHASE 2)"
    (not (null (vl-symbol-value 'c:MTOGOTO))))
  (mto-assert-true "command: MTOFORMULA dinh nghia (PHASE 3)"
    (not (null (vl-symbol-value 'c:MTOFORMULA))))
  (mto-assert-true "command: MTOSUB dinh nghia (PHASE 3)"
    (not (null (vl-symbol-value 'c:MTOSUB))))
  (mto-assert-true "command: MTODED dinh nghia (PHASE 3)"
    (not (null (vl-symbol-value 'c:MTODED))))
  (mto-assert-true "command: MTOFLOOR dinh nghia (PHASE 4)"
    (not (null (vl-symbol-value 'c:MTOFLOOR))))
  (mto-assert-true "command: MTOTITLE dinh nghia"
    (not (null (vl-symbol-value 'c:MTOTITLE))))
  (mto-assert-true "command: MTOCFG dinh nghia (PHASE 4)"
    (not (null (vl-symbol-value 'c:MTOCFG))))
  (mto-assert-true "command: MTOHELP dinh nghia"
    (not (null (vl-symbol-value 'c:MTOHELP))))

  ;; ---------- 5. tich hop toan bo: chay 1 chuoi MTO ----------

  ;; (khong dung entity that: kiem tra ham loi ton tai va chay duoc)
  ;; LUU Y: DB rong CHINH LA nil trong AutoLISP (danh sach rong = nil)
  (mto-assert-true "tich hop: mto-db-new tra ve db rong (nil)"
    (null (mto-db-new)))
  (mto-assert-true "tich hop: mto-db-empty-p dung voi db moi"
    (mto-db-empty-p (mto-db-new)))
  (mto-assert-true "tich hop: mto-csv-header chay duoc"
    (> (strlen (mto-csv-header)) 0))
  (mto-assert-true "tich hop: mto-res-header chay duoc"
    (> (strlen (mto-res-header)) 0))
  (mto-assert-true "tich hop: mto-orphan-report chay duoc"
    (> (strlen (mto-orphan-report '())) 0))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-loader.lsp loaded.")
(princ)

