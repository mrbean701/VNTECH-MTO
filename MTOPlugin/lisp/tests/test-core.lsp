;;; ============================================================
;;; test-core.lsp -- Test cases cho mto-core.lsp (TASK-005)
;;; ============================================================

(defun mto-run-tests (out-path / db it it2 db2 found)

  (mto-test-reset)

  ;; ---------- 1. String utils ----------

  (mto-assert-equal "str-trim: khoang trang"
    "EL-CABLE" (mto-str-trim "  EL-CABLE  "))

  (mto-assert-equal "str-trim: nil -> rong"
    "" (mto-str-trim nil))

  (mto-assert-equal "str-up: in hoa"
    "MCB 20A" (mto-str-up "  mcb 20a "))

  (mto-assert-equal "str-left: lay 3 ky tu"
    "MCB" (mto-str-left "MCB 20A" 3))

  (mto-assert-equal "str-left: n lon hon do dai"
    "MCB" (mto-str-left "MCB" 10))

  (mto-assert-equal "str-first-token: cat tai khoang trang"
    "MCB" (mto-str-first-token "MCB 20A"))

  (mto-assert-equal "str-first-token: khong co khoang trang"
    "ELCB" (mto-str-first-token "ELCB"))

  (mto-assert-equal "str-split: tach bang ';'"
    '("A" "B" "C") (mto-str-split "A;B;C" ";"))

  (mto-assert-equal "str-split: chuoi rong -> nil"
    nil (mto-str-split "" ";"))

  (mto-assert-equal "str-join: noi bang ','"
    "A,B,C" (mto-str-join '("A" "B" "C") ","))

  ;; ---------- 2. Number utils ----------

  (mto-assert-equal "num->str: 0.0 -> '0'"
    "0" (mto-num->str 0.0))

  (mto-assert-equal "num->str: 1000.0 -> '1000'"
    "1000" (mto-num->str 1000.0))

  (mto-assert-equal "num->str: 12.5 -> '12.5'"
    "12.5" (mto-num->str 12.5))

  (mto-assert-equal "num->str: int giu nguyen"
    "42" (mto-num->str 42))

  (mto-assert-close "str->num: '12.5' -> 12.5"
    12.5 (mto-str->num "12.5" nil) 0.0001)

  (mto-assert-equal "str->num: chuoi rac -> def"
    -1 (mto-str->num "abc" -1))

  ;; ---------- 3. Item model ----------

  (setq it (mto-item-new *MTO-CAT-ELEC* "MCB" "MCB 20A"))

  (mto-assert-equal "item-new: CATEGORY"
    "Electrical" (mto-item-get it 'CATEGORY))

  (mto-assert-equal "item-new: TYPE"
    "MCB" (mto-item-get it 'TYPE))

  (mto-assert-equal "item-new: QTY khoi tao = 0"
    0.0 (mto-item-get it 'QTY))

  (mto-assert-true "item-new: co khoa HANDLES"
    (assoc 'HANDLES it))

  (mto-assert-true "item-new: co khoa NETQTY"
    (assoc 'NETQTY it))

  (setq it2 (mto-item-set it 'SPEC "20A"))
  (mto-assert-equal "item-set: dat SPEC"
    "20A" (mto-item-get it2 'SPEC))

  (mto-assert-equal "item-set: khong lam mat khoa cu"
    "MCB" (mto-item-get it2 'TYPE))

  (setq it2 (mto-item-set it2 'LABEL9 "moi"))
  (mto-assert-equal "item-set: them khoa moi"
    "moi" (mto-item-get it2 'LABEL9))

  ;; ---------- 4. Handle ----------

  (setq it2 (mto-item-add-handle it "1A2B"))
  (setq it2 (mto-item-add-handle it2 "3C4D"))
  (mto-assert-equal "add-handle: them 2 handle"
    2 (length (mto-item-get it2 'HANDLES)))

  (setq it2 (mto-item-add-handle it2 "1A2B"))
  (mto-assert-equal "add-handle: khong them trung"
    2 (length (mto-item-get it2 'HANDLES)))

  ;; ---------- 5. Recalc ----------

  (setq it (mto-item-add-auto (mto-item-new "Electrical" "MCB" "MCB 20A") 10))
  (setq it (mto-item-set it 'MANQTY 3.0))
  (setq it (mto-item-set it 'DEDUCTION 2.0))
  (setq it (mto-item-recalc it))

  (mto-assert-close "recalc: QTY = AUTO + MAN"
    13.0 (mto-item-get it 'QTY) 0.0001)

  (mto-assert-close "recalc: NETQTY = QTY - DEDUCTION"
    11.0 (mto-item-get it 'NETQTY) 0.0001)

  (setq it (mto-item-add-length it 120.5))
  (mto-assert-close "add-length: cong don chieu dai"
    120.5 (mto-item-get it 'LENGTH) 0.0001)

  ;; ---------- 6. Key + DB ----------

  (mto-assert-equal "item-key: dung dinh dang"
    "Electrical|MCB|MCB 20A||" (mto-item-key it))

  (setq db (mto-db-new))
  (mto-assert-equal "db-new: rong"
    0 (mto-db-count db))

  (mto-assert-true "db-empty-p: true voi db rong"
    (mto-db-empty-p db))

  ;; them item A
  (setq db (mto-db-merge-item db (mto-item-add-auto
            (mto-item-new "Electrical" "MCB" "MCB 20A") 5)))
  (mto-assert-equal "db-merge: them item moi"
    1 (mto-db-count db))

  ;; them item A lan nua -> phai GOP
  (setq db (mto-db-merge-item db (mto-item-add-auto
            (mto-item-new "Electrical" "MCB" "MCB 20A") 7)))
  (mto-assert-equal "db-merge: cung key -> gop, khong them dong"
    1 (mto-db-count db))

  (mto-assert-close "db-merge: cong don AUTOQTY"
    12.0 (mto-item-get (car db) 'AUTOQTY) 0.0001)

  ;; them item B (khac NAME)
  (setq db (mto-db-merge-item db (mto-item-add-auto
            (mto-item-new "Electrical" "MCB" "MCB 32A") 3)))
  (mto-assert-equal "db-merge: khac key -> them dong moi"
    2 (mto-db-count db))

  ;; them item C he khac
  (setq db (mto-db-merge-item db (mto-item-add-auto
            (mto-item-new "Plumbing" "Pipe" "Pipe DN25") 4)))
  (mto-assert-equal "db-merge: khac CATEGORY -> them dong"
    3 (mto-db-count db))

  ;; ---------- 7. Sort / filter / total ----------

  (setq db2 (mto-db-sort db))
  (mto-assert-equal "db-sort: dong dau la Electrical"
    "Electrical" (mto-item-get (car db2) 'CATEGORY))

  (mto-assert-close "db-total-net: tong NETQTY (12+3+4)"
    19.0 (mto-db-total-net db) 0.0001)

  (setq found (mto-db-filter db 'CATEGORY "Electrical"))
  (mto-assert-equal "db-filter: loc Electrical -> 2 dong"
    2 (length found))

  (setq found (mto-db-filter db 'CATEGORY "ELV"))
  (mto-assert-equal "db-filter: loc ELV -> 0 dong"
    0 (length found))

  ;; ---------- 8. Handle lookup ----------

  (setq db (mto-db-merge-item db (mto-item-add-handle
            (mto-item-new "ELV" "Camera" "Cam Dome") "AA11")))
  (mto-assert-true "db-find-by-handle: tim thay"
    (mto-db-find-by-handle db "AA11"))

  (mto-assert-true "db-find-by-handle: khong thay -> nil"
    (null (mto-db-find-by-handle db "ZZZZ")))

  ;; ---------- 9. Session state ----------

  (mto-db-save db)
  (mto-assert-equal "db-save/load: giu du so dong"
    (mto-db-count db) (mto-db-count (mto-db-load)))

  (mto-db-clear)
  (mto-assert-equal "db-clear: xoa het"
    0 (mto-db-count (mto-db-load)))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-core.lsp loaded.")
(princ)
