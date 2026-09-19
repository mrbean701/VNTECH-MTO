;;; ============================================================
;;; test-text.lsp -- Test cases cho mto-text.lsp (TASK-002)
;;; Tao TEXT/MTEXT THAT de test nhan dang prefix
;;; ============================================================

(defun mto-t2-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t2-mktext (layer x y s)
  (mto-t2-mklayer layer)
  (entmake (list '(0 . "TEXT") (cons 8 layer)
                 (cons 10 (list x y 0.0)) (cons 1 s) (cons 40 2.5))))

(defun mto-t2-mkmtext (layer x y s)
  (mto-t2-mklayer layer)
  (entmake (list '(0 . "MTEXT")
                 '(100 . "AcDbEntity")
                 '(100 . "AcDbMText")
                 (cons 8 layer)
                 (cons 10 (list x y 0.0))
                 (cons 40 2.5)
                 (cons 1 s))))

(defun mto-t2-find-by-type (ss ty / i n e found)
  (setq i 0 n (sslength ss) found nil ty (mto-str-up ty))
  (while (and (< i n) (null found))
    (setq e (ssname ss i))
    (if (and e (= (mto-str-up (cdr (assoc 0 (entget e)))) ty))
      (setq found e))
    (setq i (1+ i)))
  found)

(defun mto-t2-clean (layer / ss i n e)
  (setq ss (ssget "_X" (list (cons 8 layer))))
  (if ss
    (progn
      (setq i 0 n (sslength ss))
      (while (< i n)
        (setq e (ssname ss i))
        (if e (entdel e))
        (setq i (1+ i)))))
  (princ))

;; ============================================================

(defun mto-run-tests (out-path / ss res db it it2 prefixL entM)

  (mto-test-reset)

  ;; ---------- 1. MTEXT strip ----------

  (mto-assert-equal "strip: bo {\f...;} giu noi dung"
    "MCB 20A" (mto-text-strip-mtext "{\\fArial|b0;MCB 20A}"))

  (mto-assert-equal "strip: \\A1; bi bo"
    "MCB 20A" (mto-text-strip-mtext "\\A1;MCB 20A"))

  (mto-assert-equal "strip: \\P -> khoang trang"
    "MCB 20A ELCB 32A" (mto-text-strip-mtext "MCB 20A\\PELCB 32A"))

  (mto-assert-equal "strip: bo ngoac nhon"
    "DB 100A" (mto-text-strip-mtext "{DB} 100A"))

  (mto-assert-equal "strip: chuoi rong"
    "" (mto-text-strip-mtext ""))

  (mto-assert-equal "strip: nil"
    "" (mto-text-strip-mtext nil))

  (mto-assert-equal "strip: text thuong giu nguyen"
    "PUMP P-01" (mto-text-strip-mtext "PUMP P-01"))

  ;; ---------- 2. extract-prefix ----------

  (mto-assert-equal "prefix: 'MCB 20A' -> MCB"
    "MCB" (mto-text-extract-prefix "MCB 20A"))

  (mto-assert-equal "prefix: 'MCB-20A' -> MCB"
    "MCB" (mto-text-extract-prefix "MCB-20A"))

  (mto-assert-equal "prefix: 'ELCB_32A' -> ELCB"
    "ELCB" (mto-text-extract-prefix "ELCB_32A"))

  (mto-assert-equal "prefix: 'mcb 20a' -> MCB (in hoa)"
    "MCB" (mto-text-extract-prefix "mcb 20a"))

  (mto-assert-equal "prefix: chuoi rong"
    "" (mto-text-extract-prefix ""))

  ;; ---------- 3. match-known-prefix (uu tien dai nhat) ----------

  (setq prefixL (mto-text-prefix-list))

  (mto-assert-equal "known: 'ELCB 32A' -> ELCB (khong phai E)"
    "ELCB" (mto-text-match-known-prefix "ELCB 32A" prefixL))

  (mto-assert-equal "known: 'MCB 20A' -> MCB"
    "MCB" (mto-text-match-known-prefix "MCB 20A" prefixL))

  (mto-assert-equal "known: 'MCCB 100A' -> MCCB (khong phai MCB)"
    "MCCB" (mto-text-match-known-prefix "MCCB 100A" prefixL))

  (mto-assert-equal "known: 'CCTV camera' -> CCTV"
    "CCTV" (mto-text-match-known-prefix "CCTV camera" prefixL))

  (mto-assert-equal "known: 'DB 100A' -> DB"
    "DB" (mto-text-match-known-prefix "DB 100A" prefixL))

  (mto-assert-equal "known: 'DBX 100' KHONG khop DB (ranh gioi)"
    nil (mto-text-match-known-prefix "DBX 100" prefixL))

  (mto-assert-equal "known: chuoi la -> nil"
    nil (mto-text-match-known-prefix "XYZ 123" prefixL))

  ;; ---------- 4. recognize-prefix (bang + fallback) ----------

  (mto-assert-equal "recognize: 'MCB 20A' -> MCB"
    "MCB" (mto-text-recognize-prefix "MCB 20A"))

  (mto-assert-equal "recognize: 'ZZZ 9' -> fallback token dau"
    "ZZZ" (mto-text-recognize-prefix "ZZZ 9"))

  ;; ---------- 5. category mapping ----------

  (mto-assert-equal "category: MCB -> Electrical"
    "Electrical" (mto-text-category-for-prefix "MCB"))

  (mto-assert-equal "category: CCTV -> ELV"
    "ELV" (mto-text-category-for-prefix "CCTV"))

  (mto-assert-equal "category: PUMP -> Plumbing"
    "Plumbing" (mto-text-category-for-prefix "PUMP"))

  (mto-assert-equal "category: khong biet -> Other"
    "Other" (mto-text-category-for-prefix "ZZZ"))

  (mto-assert-equal "category: nil -> Other"
    "Other" (mto-text-category-for-prefix nil))

  ;; ---------- 6. entity text that ----------

  (mto-t2-clean "MTO-T2")
  (mto-t2-mktext "MTO-T2" 0 0 "MCB 20A")
  (mto-t2-mktext "MTO-T2" 0 10 "MCB 32A")
  (mto-t2-mktext "MTO-T2" 0 20 "MCB 40A")
  (mto-t2-mktext "MTO-T2" 0 30 "ELCB 32A")
  (mto-t2-mktext "MTO-T2" 0 40 "DB 100A")
  (mto-t2-mkmtext "MTO-T2" 0 50 "{\\fArial|b0;CCTV camera 4MP}")

  (setq ss (ssget "_X" (list (cons 8 "MTO-T2"))))
  (mto-assert-equal "entity: tao duoc 6 text"
    6 (if ss (sslength ss) 0))

  ;; lay content tu entity that
  ;; LUU Y: thu tu ssget KHONG dam bao = thu tu tao -> phai tim theo loai
  (setq entM (mto-t2-find-by-type ss "MTEXT"))
  (mto-assert-true "entity: tim thay MTEXT trong selection set" entM)

  (setq it (mto-text-classify entM))
  (mto-assert-equal "entity: MTEXT strip ra noi dung sach"
    "CCTV camera 4MP" (mto-item-get it 'DESCRIPTION))

  (mto-assert-equal "entity: MTEXT nhan dung prefix"
    "CCTV" (mto-item-get it 'PREFIX))

  (mto-assert-equal "entity: MTEXT xep dung category"
    "ELV" (mto-item-get it 'CATEGORY))

  (mto-assert-equal "entity: SOURCETYPE = TEXT"
    "TEXT" (mto-item-get it 'SOURCETYPE))

  (mto-assert-equal "entity: AUTOQTY = 1"
    1.0 (mto-item-get it 'AUTOQTY))

  (mto-assert-equal "entity: co 1 handle"
    1 (length (mto-item-get it 'HANDLES)))

  ;; ---------- 7. scan-ss + gom nhom ----------

  (setq res (mto-text-scan-ss ss '()))
  (setq db (cdr (assoc 'DB res)))
  (mto-assert-equal "scan: xu ly 6 text"
    6 (cdr (assoc 'ADDED res)))

  ;; MCB 20A/32A/40A khac NAME -> 3 dong rieng; ELCB 1; DB 1; CCTV 1 => 6 dong
  (mto-assert-equal "scan: MCB khac NAME -> dong rieng (6 dong)"
    6 (mto-db-count db))

  ;; nhung cung PREFIX MCB -> loc theo TYPE
  (mto-assert-equal "scan: loc TYPE=MCB -> 3 dong"
    3 (length (mto-db-filter db 'TYPE "MCB")))

  ;; ---------- 8. gom theo TYPE khi cung NAME ----------

  (mto-t2-clean "MTO-T3")
  (mto-t2-mktext "MTO-T3" 0 0 "MCB 20A")
  (mto-t2-mktext "MTO-T3" 0 10 "MCB 20A")
  (setq ss (ssget "_X" (list (cons 8 "MTO-T3"))))
  (setq res (mto-text-scan-ss ss '()))
  (setq db (cdr (assoc 'DB res)))
  (mto-assert-equal "gom nhom: 2 text giong nhau -> 1 dong"
    1 (mto-db-count db))
  (mto-assert-close "gom nhom: AUTOQTY = 2"
    2.0 (mto-item-get (car db) 'AUTOQTY) 0.0001)
  (mto-assert-equal "gom nhom: gop duoc 2 handle"
    2 (length (mto-item-get (car db) 'HANDLES)))

  ;; don dep
  (mto-t2-clean "MTO-T2")
  (mto-t2-clean "MTO-T3")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-text.lsp loaded.")
(princ)
