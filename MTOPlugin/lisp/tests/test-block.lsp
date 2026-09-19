;;; ============================================================
;;; test-block.lsp -- Test cases cho mto-block.lsp (TASK-003)
;;; Tao BLOCK THAT (block definition + INSERT) de test dem
;;; ============================================================

(defun mto-t3-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

;; Tao block definition voi 1 LINE ben trong
(defun mto-t3-mkdef (name)
  (if (not (tblsearch "BLOCK" name))
    (progn
      (entmake (list '(0 . "BLOCK")
                     '(100 . "AcDbEntity")
                     '(100 . "AcDbBlockBegin")
                     '(70 . 0)
                     (cons 2 name)
                     '(10 0.0 0.0 0.0)))
      (entmake '((0 . "LINE") (10 0.0 0.0 0.0) (11 1.0 0.0 0.0)))
      (entmake '((0 . "ENDBLK") (100 . "AcDbEntity") (100 . "AcDbBlockEnd")))))
  name)

;; Tao INSERT (block reference)
(defun mto-t3-mkinsert (name layer x y)
  (mto-t3-mklayer layer)
  (entmake (list '(0 . "INSERT")
                 '(100 . "AcDbEntity")
                 '(100 . "AcDbBlockReference")
                 (cons 8 layer)
                 (cons 2 name)
                 (cons 10 (list x y 0.0)))))

(defun mto-t3-clean (layer / ss i n e)
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

(defun mto-run-tests (out-path / it db res cnt hs pairs)

  (mto-test-reset)

  ;; ---------- 1. anonymous ----------

  (mto-assert-true "anonymous: '*U1' la an danh"
    (mto-blk-anonymous-p "*U1"))
  (mto-assert-true "anonymous: '*D3' la an danh"
    (mto-blk-anonymous-p "*D3"))
  (mto-assert-true "anonymous: 'DEN' KHONG an danh"
    (not (mto-blk-anonymous-p "DEN")))
  (mto-assert-true "anonymous: nil KHONG an danh"
    (not (mto-blk-anonymous-p nil)))

  ;; ---------- 2. build-filter ----------

  (mto-assert-equal "filter: co DXF 0 = INSERT"
    "INSERT" (cdr (assoc 0 (mto-blk-build-filter "DEN" nil))))
  (mto-assert-equal "filter: DXF 2 = ten block"
    "DEN" (cdr (assoc 2 (mto-blk-build-filter "DEN" nil))))
  (mto-assert-equal "filter: khong co layer khi nil"
    nil (assoc 8 (mto-blk-build-filter "DEN" nil)))
  (mto-assert-equal "filter: co layer khi chi dinh"
    "EL-*" (cdr (assoc 8 (mto-blk-build-filter "DEN" "EL-*"))))

  ;; ---------- 3. dem block THAT ----------

  (mto-t3-clean "MTO-T3-EL")
  (mto-t3-clean "MTO-T3-ELV")

  (mto-t3-mkdef "MTO-DEN-DL")
  (mto-t3-mkdef "MTO-CAM-DOME")
  (mto-t3-mkdef "*U99")   ; block an danh

  (mto-t3-mkinsert "MTO-DEN-DL"  "MTO-T3-EL" 0 0)
  (mto-t3-mkinsert "MTO-DEN-DL"  "MTO-T3-EL" 10 0)
  (mto-t3-mkinsert "MTO-DEN-DL"  "MTO-T3-EL" 20 0)
  (mto-t3-mkinsert "MTO-DEN-DL"  "MTO-T3-EL" 30 0)
  (mto-t3-mkinsert "MTO-CAM-DOME" "MTO-T3-ELV" 0 0)
  (mto-t3-mkinsert "MTO-CAM-DOME" "MTO-T3-ELV" 10 0)
  (mto-t3-mkinsert "*U99"        "MTO-T3-EL" 40 0)

  (mto-assert-equal "count: MTO-DEN-DL = 4"
    4 (mto-blk-count "MTO-DEN-DL" nil))

  (mto-assert-equal "count: MTO-CAM-DOME = 2"
    2 (mto-blk-count "MTO-CAM-DOME" nil))

  (mto-assert-equal "count: loc layer MTO-T3-EL -> 4"
    4 (mto-blk-count "MTO-DEN-DL" "MTO-T3-EL"))

  (mto-assert-equal "count: layer khong khop -> 0"
    0 (mto-blk-count "MTO-DEN-DL" "MTO-T3-ELV"))

  (mto-assert-equal "count: ten khong ton tai -> 0"
    0 (mto-blk-count "KHONG-CO-BLOCK-NAY" nil))

  (mto-assert-equal "count: nil -> 0"
    0 (mto-blk-count nil nil))

  ;; ---------- 4. handles ----------

  (setq hs (mto-blk-handles "MTO-DEN-DL" nil))
  (mto-assert-equal "handles: MTO-DEN-DL co 4 handle"
    4 (length hs))

  (mto-assert-equal "handles: ten khong ton tai -> nil"
    nil (mto-blk-handles "KHONG-CO" nil))

  ;; ---------- 5. layers cua block ----------

  (mto-assert-equal "layers: MTO-DEN-DL tren MTO-T3-EL = 4"
    4 (cdr (assoc "MTO-T3-EL" (mto-blk-layers "MTO-DEN-DL"))))

  ;; ---------- 6. classify ----------

  (setq it (mto-blk-classify "MTO-DEN-DL" 4))
  (mto-assert-equal "classify: SOURCETYPE = BLOCK"
    "BLOCK" (mto-item-get it 'SOURCETYPE))
  (mto-assert-equal "classify: NAME = ten block"
    "MTO-DEN-DL" (mto-item-get it 'NAME))
  (mto-assert-close "classify: AUTOQTY = 4"
    4.0 (mto-item-get it 'AUTOQTY) 0.0001)
  (mto-assert-close "classify: MANQTY khoi tao = 0"
    0.0 (mto-item-get it 'MANQTY) 0.0001)
  (mto-assert-close "classify: QTY = 4"
    4.0 (mto-item-get it 'QTY) 0.0001)
  (mto-assert-equal "classify: UNIT = cai"
    "cai" (mto-item-get it 'UNIT))
  (mto-assert-equal "classify: LAYER lay tu ban ve"
    "MTO-T3-EL" (mto-item-get it 'LAYER))

  ;; category nhan tu prefix (MTO-DEN-DL -> prefix? token dau "MTO-DEN-DL")
  (mto-assert-true "classify: co CATEGORY"
    (mto-item-get it 'CATEGORY))

  ;; ---------- 7. MANUAL ADJUSTMENT (diem cot loi) ----------

  (setq it (mto-blk-apply-manual it 2))
  (mto-assert-close "manual: MANQTY = 2"
    2.0 (mto-item-get it 'MANQTY) 0.0001)
  (mto-assert-close "manual: QTY = AUTO + MANUAL = 6"
    6.0 (mto-item-get it 'QTY) 0.0001)
  (mto-assert-close "manual: NETQTY = QTY = 6"
    6.0 (mto-item-get it 'NETQTY) 0.0001)

  (setq it (mto-blk-add-manual it 3))
  (mto-assert-close "manual-add: MANQTY = 5"
    5.0 (mto-item-get it 'MANQTY) 0.0001)
  (mto-assert-close "manual-add: QTY = 9"
    9.0 (mto-item-get it 'QTY) 0.0001)

  (setq it (mto-blk-apply-manual it -1))
  (mto-assert-close "manual: cho phep am (khau tru) -> QTY = 3"
    3.0 (mto-item-get it 'QTY) 0.0001)

  ;; ---------- 8. scan vao DB ----------

  (setq db (mto-db-new))
  (setq db (mto-blk-scan "MTO-DEN-DL" db nil))
  (mto-assert-equal "scan: them 1 dong"
    1 (mto-db-count db))
  (mto-assert-close "scan: AUTOQTY = 4"
    4.0 (mto-item-get (car db) 'AUTOQTY) 0.0001)
  (mto-assert-equal "scan: gan 4 handle"
    4 (length (mto-item-get (car db) 'HANDLES)))

  ;; gop khi scan lai cung block
  (setq db (mto-blk-scan "MTO-DEN-DL" db nil))
  (mto-assert-equal "scan lai: van 1 dong (gop)"
    1 (mto-db-count db))
  (mto-assert-close "scan lai: AUTOQTY = 8 (4+4)"
    8.0 (mto-item-get (car db) 'AUTOQTY) 0.0001)

  ;; ---------- 9. count-all (bo qua an danh) ----------

  (setq pairs (mto-blk-count-all))
  (mto-assert-true "count-all: co MTO-DEN-DL"
    (assoc "MTO-DEN-DL" pairs))
  (mto-assert-equal "count-all: MTO-DEN-DL = 4"
    4 (cdr (assoc "MTO-DEN-DL" pairs)))
  (mto-assert-true "count-all: BO QUA block an danh *U99"
    (not (assoc "*U99" pairs)))

  ;; ---------- 10. scan-all ----------

  (setq db (mto-blk-scan-all '()))
  (mto-assert-true "scan-all: DB co dong MTO-CAM-DOME"
    (mto-db-find-by-handle db (car (mto-blk-handles "MTO-CAM-DOME" nil))))
  (mto-assert-true "scan-all: khong co dong an danh"
    (null (mto-db-filter db 'NAME "*U99")))

  ;; don dep
  (mto-t3-clean "MTO-T3-EL")
  (mto-t3-clean "MTO-T3-ELV")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-block.lsp loaded.")
(princ)
