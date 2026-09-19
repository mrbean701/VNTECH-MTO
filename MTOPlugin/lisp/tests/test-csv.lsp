;;; ============================================================
;;; test-csv.lsp -- Test cases cho mto-csv.lsp (TASK-007)
;;; Ghi file CSV THAT roi doc lai kiem tra
;;; ============================================================

;; Doc toan bo file thanh list chuoi
(defun mto-t7-read-lines (path / f lines line)
  (setq lines '())
  (setq f (open path "r"))
  (if f
    (progn
      (while (setq line (read-line f))
        (setq lines (append lines (list line))))
      (close f)))
  lines)

(defun mto-run-tests (out-path / db it lines esc path reread base)

  (mto-test-reset)

  ;; ---------- 1. escape ----------

  (mto-assert-equal "escape: chuoi thuong giu nguyen"
    "MCB 20A" (mto-csv-escape "MCB 20A"))

  (mto-assert-equal "escape: co dau phay -> boc ngoac kep"
    "\"A,B\"" (mto-csv-escape "A,B"))

  (mto-assert-equal "escape: co ngoac kep -> nhan doi + boc"
    "\"A\"\"B\"" (mto-csv-escape "A\"B"))

  (mto-assert-equal "escape: co dau cham phay -> boc"
    "\"A;B\"" (mto-csv-escape "A;B"))

  (mto-assert-equal "escape: nil -> rong"
    "" (mto-csv-escape nil))

  (mto-assert-equal "escape: bo xuong dong"
    "A B" (mto-csv-escape "A\nB"))

  ;; ---------- 2. header ----------

  (setq lines (mto-csv-header))
  (mto-assert-true "header: co Category" (vl-string-search "Category" lines))
  (mto-assert-true "header: co AutoQty"  (vl-string-search "AutoQty" lines))
  (mto-assert-true "header: co Handles"  (vl-string-search "Handles" lines))

  ;; ---------- 3. row ----------

  (setq it (mto-item-new "Electrical" "MCB" "MCB 20A"))
  (setq it (mto-item-set it 'UNIT "cai"))
  (setq it (mto-item-set it 'AUTOQTY 5.0))
  (setq it (mto-blk-apply-manual it 2))    ; QTY = 7
  (setq it (mto-item-add-length it 123.5))
  (setq it (mto-item-add-handle it "A1"))
  (setq it (mto-item-add-handle it "B2"))
  (setq it (mto-item-recalc it))

  (setq lines (mto-csv-row it))
  (mto-assert-true "row: co Category"  (vl-string-search "Electrical" lines))
  (mto-assert-true "row: co AutoQty 5" (vl-string-search "5" lines))
  (mto-assert-true "row: co Length 123.5" (vl-string-search "123.5" lines))
  (mto-assert-true "row: handle noi bang |" (vl-string-search "A1|B2" lines))

  ;; ---------- 4. lines ----------

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))
  (setq db (mto-db-merge-item db
             (mto-item-recalc (mto-item-add-auto
               (mto-item-new "Plumbing" "Pipe" "Pipe DN25") 3))))

  (setq lines (mto-csv-lines db))
  (mto-assert-equal "lines: header + 2 dong = 3"
    3 (length lines))
  (mto-assert-equal "lines: dong dau la header"
    (mto-csv-header) (car lines))

  ;; ---------- 5. ten file mac dinh ----------

  (setq base (mto-csv-default-name))
  (mto-assert-true "name: co duoi .csv"
    (= ".csv" (substr base (- (strlen base) 3))))
  (mto-assert-true "name: co _MTO_"
    (vl-string-search "_MTO_" base))
  (mto-assert-true "name: khong chua .dwg"
    (not (vl-string-search ".dwg" base)))

  ;; ---------- 6. ghi file THAT + doc lai ----------

  (setq path (strcat (vl-filename-directory out-path) "/mto_test_out.csv"))
  (setq ok (mto-csv-write db path))
  (mto-assert-true "write: tra ve T khi thanh cong" ok)
  (mto-assert-true "write: file ton tai" (findfile path))

  (setq reread (mto-t7-read-lines path))
  (mto-assert-equal "write: file co 3 dong"
    3 (length reread))
  (mto-assert-true "write: dong 2 co Electrical"
    (vl-string-search "Electrical" (nth 1 reread)))
  (mto-assert-true "write: dong 3 co Plumbing"
    (vl-string-search "Plumbing" (nth 2 reread)))
  (mto-assert-true "write: gia tri 123.5 duoc ghi"
    (vl-string-search "123.5" (nth 1 reread)))

  ;; ---------- 7. ghi voi db rong (chi header) ----------

  (setq path2 (strcat (vl-filename-directory out-path) "/mto_test_empty.csv"))
  (mto-assert-true "write: db rong van ghi duoc"
    (mto-csv-write '() path2))
  (setq reread (mto-t7-read-lines path2))
  (mto-assert-equal "write: db rong -> chi 1 dong header"
    1 (length reread))

  ;; don file
  (if (findfile path)  (vl-file-delete path))
  (if (findfile path2) (vl-file-delete path2))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-csv.lsp loaded.")
(princ)
