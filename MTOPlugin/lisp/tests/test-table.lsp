;;; ============================================================
;;; test-table.lsp -- Test cases cho mto-table.lsp (TASK-009)
;;; Tao bang GRID THAT (TEXT + LINE) roi dem entity de kiem
;;; ============================================================

(defun mto-t9-clean (layer / ss i n e)
  (setq ss (ssget "_X" (list (cons 8 layer))))
  (if ss
    (progn
      (setq i 0 n (sslength ss))
      (while (< i n)
        (setq e (ssname ss i))
        (if e (entdel e))
        (setq i (1+ i)))))
  (princ))

(defun mto-t9-count-type (layer ty / ss cnt)
  (setq ss (ssget "_X" (list (cons 8 layer) (cons 0 ty))))
  (if ss (sslength ss) 0))

(defun mto-run-tests (out-path / db it it2 rows hdr cells stats sub ent n nCols nRows pt)

  (mto-test-reset)

  ;; ---------- 1. dinh nghia cot ----------

  (mto-assert-equal "cols: co 9 cot"
    9 (length *MTO-TABLE-COLS*))

  (mto-assert-equal "cols: cot dau la STT"
    "STT" (car (car *MTO-TABLE-COLS*)))

  (mto-assert-equal "cols: 9 key"
    9 (length (mto-table-keys)))

  (mto-assert-close "cols: tong do rong = 146.0"
    146.0 (mto-table-total-width) 0.001)

  (mto-assert-close "cols: do rong cot 0 = 7.0"
    7.0 (mto-table-col-width 0) 0.001)

  (mto-assert-equal "cols: key cua cot 4 la QTY"
    "QTY" (nth 4 (mto-table-keys)))

  ;; ---------- 2. header cells ----------

  (setq hdr (mto-table-header-cells))
  (mto-assert-equal "header: 9 o"
    9 (length hdr))
  (mto-assert-equal "header: o dau = STT"
    "STT" (car hdr))
  (mto-assert-true "header: co NOTES"
    (member "NOTES" hdr))

  ;; ---------- 3. item cells ----------

  (setq it (mto-item-new "Electrical" "MCB" "MCB 20A"))
  (setq it (mto-item-set it 'UNIT "cai"))
  (setq it (mto-item-set it 'LAYER "EL-DB"))
  (setq it (mto-blk-apply-manual it 5))
  (setq it (mto-item-add-length it 42.5))
  (setq it (mto-item-recalc it))

  (setq cells (mto-table-item-cells it 1))
  (mto-assert-equal "item: 9 o"
    9 (length cells))
  (mto-assert-equal "item: o 0 = STT"
    "1" (nth 0 cells))
  (mto-assert-equal "item: o 1 = CATEGORY"
    "Electrical" (nth 1 cells))
  (mto-assert-equal "item: o 4 = QTY"
    "5" (nth 4 cells))
  (mto-assert-equal "item: o 5 = LENGTH"
    "42.5" (nth 5 cells))
  (mto-assert-equal "item: o 6 = UNIT"
    "cai" (nth 6 cells))
  (mto-assert-equal "item: o 7 = LAYER"
    "EL-DB" (nth 7 cells))

  ;; item khong co chieu dai -> o LENGTH de trong
  (setq it2 (mto-item-new "ELV" "CAM" "Camera"))
  (setq it2 (mto-item-set it2 'UNIT "cai"))
  (setq it2 (mto-blk-apply-manual it2 3))
  (setq cells (mto-table-item-cells it2 2))
  (mto-assert-equal "item: khong co chieu dai -> o rong"
    "" (nth 5 cells))

  ;; ---------- 4. subtotal ----------

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))    ; Electrical 5
  (setq db (mto-db-merge-item db it2))   ; ELV 3
  (setq it3 (mto-item-new "Electrical" "DB" "DB 100A"))
  (setq it3 (mto-item-set it3 'UNIT "cai"))
  (setq it3 (mto-blk-apply-manual it3 2)) ; Electrical 2
  (setq db (mto-db-merge-item db it3))

  (setq sub (mto-table-subtotal-by db 'CATEGORY))
  (mto-assert-equal "subtotal: 2 he"
    2 (length sub))
  (mto-assert-close "subtotal: Electrical = 7"
    7.0 (cdr (assoc "Electrical" sub)) 0.001)
  (mto-assert-close "subtotal: ELV = 3"
    3.0 (cdr (assoc "ELV" sub)) 0.001)

  ;; ---------- 5. build rows ----------

  (setq rows (mto-table-build-rows db))
  ;; header(1) + data(3) + subtotal(2) + grand total(1) = 7
  (mto-assert-equal "rows: 1 header + 3 data + 2 subtotal + 1 total = 7"
    7 (length rows))
  (mto-assert-equal "rows: dong dau la header (H)"
    "H" (car (car rows)))
  (mto-assert-equal "rows: dong cuoi la grand total (G)"
    "G" (car (last rows)))

  (setq n 0)
  (foreach r rows (if (= (car r) "D") (setq n (1+ n))))
  (mto-assert-equal "rows: co 3 dong du lieu (D)" 3 n)

  (setq n 0)
  (foreach r rows (if (= (car r) "S") (setq n (1+ n))))
  (mto-assert-equal "rows: co 2 dong subtotal (S)" 2 n)

  ;; dong grand total chua tong dung
  ;; LUU Y: (last rows) tra ve PHAN TU cuoi (mot row), khong phai list con
  (setq cells (cdr (last rows)))
  (mto-assert-equal "rows: grand total QTY = 10"
    "10" (nth 4 cells))

  ;; ---------- 6. vi tri o ----------

  (setq pt (list 0.0 0.0))
  (mto-assert-equal "cell-point: o [0][0] = goc"
    '(0.0 0.0) (mto-table-cell-point pt 0 0))
  (mto-assert-equal "cell-point: o [0][1] dich theo cot 0 (7.0)"
    '(7.0 0.0) (mto-table-cell-point pt 0 1))
  (mto-assert-equal "cell-point: o [1][0] xuong 1 dong (6.0)"
    '(0.0 -6.0) (mto-table-cell-point pt 1 0))

  ;; ---------- 6b. CHONG CHU: cat noi dung cho vua chieu rong cot ----------
  ;; Bug da gap: "Camera Cable" (12 ky tu) trong cot rong 14 -> tran sang cot ben
  (mto-assert-true "max-chars: cot TYPE (18.0) cho >= 12 ky tu"
    (>= (mto-table-max-chars 18.0) 12))
  (mto-assert-true "max-chars: cot STT (7.0) cho it ky tu hon cot TYPE"
    (< (mto-table-max-chars 7.0) (mto-table-max-chars 18.0)))

  (mto-assert-equal "fit: chuoi ngan giu nguyen"
    "Camera" (mto-table-fit "Camera" 18))
  (mto-assert-equal "fit: chuoi dai bi cat + them dau cham"
    "Camera Cab." (mto-table-fit "Camera Cable XYZ" 11))
  (mto-assert-equal "fit: nil -> chuoi rong" "" (mto-table-fit nil 10))
  (mto-assert-true "fit: ket qua KHONG DAI HON gioi han"
    (<= (strlen (mto-table-fit "Camera Cable XYZ 12345" 8)) 8))

  (mto-assert-true "cell-draw: o TYPE dai duoc cat vua cot"
    (<= (strlen (mto-table-cell-draw "Camera Cable Rat Dai XYZ" 2))
        (mto-table-max-chars (mto-table-col-width 2))))
  (mto-assert-equal "cell-draw: nil -> rong" "" (mto-table-cell-draw nil 0))

  ;; ---------- 7. mo ta so entity grid ----------

  (setq stats (mto-table-grid-entities rows))
  ;; TEXT = chi dem o CO NOI DUNG (o rong khong ve)
  (mto-assert-true "grid: mo ta TEXT > 0"
    (> (car stats) 0))
  (mto-assert-true "grid: mo ta TEXT < tong so o (63)"
    (< (car stats) 63))
  ;; LINE = (nRows+1) + (nCols+1) = 8 + 10 = 18
  (mto-assert-equal "grid: LINE = 18"
    18 (cdr stats))

  ;; ---------- 8. ve grid THAT + dem entity ----------

  (mto-t9-clean "MTO-T9")
  (setq n (mto-table-draw-grid rows (list 0.0 0.0) "MTO-T9"))
  ;; n = so TEXT thuc su duoc ve -> PHAI KHOP voi mo ta
  (mto-assert-equal "draw: so TEXT ve ra KHOP mo ta"
    (car stats) n)

  (setq nRows (mto-t9-count-type "MTO-T9" "LINE"))
  (mto-assert-equal "draw: 18 duong ke LINE"
    18 nRows)

  (setq nCols (mto-t9-count-type "MTO-T9" "TEXT"))
  (mto-assert-equal "draw: so TEXT tren ban ve khop mo ta"
    (car stats) nCols)

  ;; ---------- 9. ActiveX khong co -> tra nil, KHONG crash ----------

  (mto-assert-true "activex: accoreconsole KHONG co ActiveX"
    (not (mto-table-activex-available-p)))

  (mto-assert-equal "native: tra nil khi khong co ActiveX (khong crash)"
    nil (mto-table-add-native rows (list 0.0 0.0) "MTO-TABLE"))

  ;; ---------- 9b. chuan hoa o thanh chuoi (bug bang RONG) ----------

  (mto-assert-equal "cell->str: nil thanh chuoi rong" "" (mto-table-cell->str nil))
  (mto-assert-equal "cell->str: chuoi giu nguyen" "CAM" (mto-table-cell->str "CAM"))
  (mto-assert-equal "cell->str: so nguyen" "51" (mto-table-cell->str 51))
  (mto-assert-equal "cell->str: so thuc" "1286.9135" (mto-table-cell->str 1286.9135))

  (mto-assert-true "colwidth-array: tao duoc mang"
    (not (null (mto-table-colwidth-array))))
  ;; vlax-safearray-get-u-bound tra UPPER BOUND (0-based) => mang 9 phan tu = 8
  (mto-assert-equal "colwidth-array: co dung 9 phan tu (u-bound=8)"
    8 (vlax-safearray-get-u-bound (mto-table-colwidth-array) 1))

  ;; ---------- 10. bang rong ----------

  (setq rows (mto-table-build-rows '()))
  ;; header + grand total = 2
  (mto-assert-equal "rows rong: header + grand total = 2"
    2 (length rows))

  ;; don dep
  (mto-t9-clean "MTO-T9")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-table.lsp loaded.")
(princ)
