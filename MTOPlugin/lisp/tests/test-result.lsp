;;; ============================================================
;;; test-result.lsp -- Test cases cho mto-result.lsp (TASK-006)
;;; ============================================================

(defun mto-run-tests (out-path / db it hdr row tbl stats lines)

  (mto-test-reset)

  ;; ---------- 1. spaces / pad ----------

  (mto-assert-equal "spaces: 3 khoang trang"
    "   " (mto-res-spaces 3))

  (mto-assert-equal "spaces: 0 -> rong"
    "" (mto-res-spaces 0))

  (mto-assert-equal "pad: ngan hon -> them khoang trang"
    "AB   " (mto-res-pad "AB" 5))

  (mto-assert-equal "pad: dung bang -> giu nguyen"
    "ABCDE" (mto-res-pad "ABCDE" 5))

  (mto-assert-equal "pad: dai hon -> CAT bot"
    "ABCDE" (mto-res-pad "ABCDEFGH" 5))

  (mto-assert-equal "pad: nil -> toan khoang trang"
    "     " (mto-res-pad nil 5))

  (mto-assert-equal "pad: tu trim truoc khi can"
    "AB   " (mto-res-pad "  AB  " 5))

  ;; ---------- 2. header ----------

  (setq hdr (mto-res-header))
  (mto-assert-true "header: co CATEGORY" (vl-string-search "CATEGORY" hdr))
  (mto-assert-true "header: co TYPE"     (vl-string-search "TYPE" hdr))
  (mto-assert-true "header: co NAME"     (vl-string-search "NAME" hdr))
  (mto-assert-true "header: co QTY"      (vl-string-search "QTY" hdr))
  (mto-assert-true "header: co LENGTH"   (vl-string-search "LENGTH" hdr))
  (mto-assert-true "header: co UNIT"     (vl-string-search "UNIT" hdr))

  ;; ---------- 3. row ----------

  (setq it (mto-item-new "Electrical" "MCB" "MCB 20A"))
  (setq it (mto-item-set it 'UNIT "cai"))
  (setq it (mto-blk-apply-manual it 2))   ; AUTOQTY=0, MANQTY=2 -> QTY=2
  (setq row (mto-res-row it))

  (mto-assert-true "row: chua CATEGORY" (vl-string-search "Electrical" row))
  (mto-assert-true "row: chua TYPE"     (vl-string-search "MCB" row))
  (mto-assert-true "row: chua NAME"     (vl-string-search "MCB 20A" row))
  (mto-assert-true "row: chua QTY=2"    (vl-string-search "2" row))
  (mto-assert-true "row: chua UNIT"     (vl-string-search "cai" row))

  ;; do dai dong = tong do rong cot (14+14+32+10+12+8 = 90) + 5 khoang cach = 95
  (mto-assert-equal "row: do dai dung bang do rong cot"
    95 (strlen row))

  ;; ---------- 4. bang ----------

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db
             (mto-item-recalc (mto-item-add-auto
               (mto-item-new "Electrical" "MCB" "MCB 20A") 5))))
  (setq db (mto-db-merge-item db
             (mto-item-recalc (mto-item-add-auto
               (mto-item-new "Plumbing" "Pipe" "Pipe DN25") 3))))

  (setq tbl (mto-res-table db))
  (mto-assert-equal "table: 2 dong du lieu + header + sep = 4"
    4 (length tbl))

  (mto-assert-equal "table: dong dau la header"
    (mto-res-header) (car tbl))

  ;; sap xep: Electrical truoc Plumbing
  (mto-assert-true "table: dong 3 la Electrical (sap xep)"
    (vl-string-search "Electrical" (nth 2 tbl)))

  ;; ---------- 5. stats ----------

  (setq stats (mto-res-stats db))
  (mto-assert-equal "stats: ROWS = 2"
    2 (cdr (assoc 'ROWS stats)))
  (mto-assert-close "stats: QTY = 8"
    8.0 (cdr (assoc 'QTY stats)) 0.0001)
  (mto-assert-equal "stats: CATS = 2"
    2 (cdr (assoc 'CATS stats)))

  ;; ---------- 6. bang rong ----------

  (mto-assert-equal "table: db rong -> chi header + sep"
    2 (length (mto-res-table '())))

  (setq stats (mto-res-stats '()))
  (mto-assert-equal "stats: db rong -> ROWS = 0"
    0 (cdr (assoc 'ROWS stats)))
  (mto-assert-equal "stats: db rong -> CATS = 0"
    0 (cdr (assoc 'CATS stats)))

  ;; ---------- 7. loc theo category ----------

  (setq lines (mto-db-filter db 'CATEGORY "Electrical"))
  (mto-assert-equal "filter: Electrical -> 1 dong"
    1 (length lines))

  ;; ---------- 8. length hien thi ----------

  (setq it (mto-item-new "Electrical" "Tray" "Cable tray"))
  (setq it (mto-item-add-length it 123.5))
  (setq it (mto-item-set it 'UNIT "m"))
  (setq it (mto-item-recalc it))
  (setq row (mto-res-row it))
  (mto-assert-true "row: hien thi chieu dai 123.5"
    (vl-string-search "123.5" row))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-result.lsp loaded.")
(princ)
