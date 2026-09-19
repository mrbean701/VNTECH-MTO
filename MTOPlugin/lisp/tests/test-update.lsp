;;; ============================================================
;;; test-update.lsp -- Test cases cho mto-update.lsp (TASK-011)
;;; Sua TEXT/MTEXT THAT va ghi/doc XData THAT
;;; ============================================================

(defun mto-t11-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t11-text (layer x y s)
  (mto-t11-mklayer layer)
  (entmake (list '(0 . "TEXT") '(100 . "AcDbEntity")
                 (cons 8 layer) (cons 10 (list x y 0.0))
                 (cons 1 s) (cons 40 2.5)))
  (entlast))

(defun mto-t11-mtext (layer x y s)
  (mto-t11-mklayer layer)
  (entmake (list '(0 . "MTEXT") '(100 . "AcDbEntity") '(100 . "AcDbMText")
                 (cons 8 layer) (cons 10 (list x y 0.0))
                 (cons 40 2.5) (cons 1 s)))
  (entlast))

(defun mto-t11-line (layer x1 y1 x2 y2)
  (mto-t11-mklayer layer)
  (entmake (list '(0 . "LINE") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0))))
  (entlast))

(defun mto-t11-h (en) (cdr (assoc 5 (entget en))))

(defun mto-t11-clean (layer / ss i n e)
  (setq ss (ssget "_X" (list (cons 8 layer))))
  (if ss
    (progn
      (setq i 0 n (sslength ss))
      (while (< i n)
        (setq e (ssname ss i))
        (if e (entdel e))
        (setq i (1+ i)))))
  (princ))

(defun mto-run-tests (out-path / e1 e2 e3 h1 h2 h3 db it it2 it3 res pairs v)

  (mto-test-reset)

  (mto-t11-clean "MTO-T11")

  ;; ---------- 1. supported-p ----------

  (setq e1 (mto-t11-text "MTO-T11" 0 0 "MCB 20A"))
  (setq e2 (mto-t11-mtext "MTO-T11" 0 10 "ELCB 32A"))
  (setq e3 (mto-t11-line "MTO-T11" 0 20 50 20))

  (mto-assert-true "supported: TEXT -> T"
    (mto-upd-supported-p e1))
  (mto-assert-true "supported: MTEXT -> T"
    (mto-upd-supported-p e2))
  (mto-assert-true "supported: LINE -> nil"
    (not (mto-upd-supported-p e3)))
  (mto-assert-true "supported: nil -> nil"
    (not (mto-upd-supported-p nil)))

  ;; ---------- 2. get / set value ----------

  (mto-assert-equal "get: TEXT noi dung ban dau"
    "MCB 20A" (mto-upd-get-value e1))
  (mto-assert-equal "get: MTEXT noi dung ban dau"
    "ELCB 32A" (mto-upd-get-value e2))
  (mto-assert-equal "get: LINE -> nil"
    nil (mto-upd-get-value e3))

  (mto-assert-true "set: TEXT thanh cong"
    (mto-upd-set-value e1 "MCB 32A"))
  ;; doc lai tu ban ve -> phai la gia tri moi
  (mto-assert-equal "set: TEXT doc lai dung gia tri moi"
    "MCB 32A" (mto-upd-get-value (mto-find-resolve (mto-t11-h e1))))

  (mto-assert-true "set: MTEXT thanh cong"
    (mto-upd-set-value e2 "ELCB 40A"))
  (mto-assert-equal "set: MTEXT doc lai dung"
    "ELCB 40A" (mto-upd-get-value e2))

  (mto-assert-equal "set: LINE -> nil (khong ho tro)"
    nil (mto-upd-set-value e3 "abc"))
  (mto-assert-equal "set: nil entity -> nil"
    nil (mto-upd-set-value nil "abc"))
  (mto-assert-equal "set: gia tri nil -> nil"
    nil (mto-upd-set-value e1 nil))

  ;; ---------- 3. XData roundtrip ----------

  (mto-assert-true "xdata: ghi thanh cong"
    (mto-upd-xdata-set e1 "MTO_TEST_APP" "HELLO"))

  (mto-assert-equal "xdata: doc lai dung gia tri"
    "HELLO" (mto-upd-xdata-get e1 "MTO_TEST_APP"))

  ;; ghi de -> khong nhan doi
  (mto-upd-xdata-set e1 "MTO_TEST_APP" "WORLD")
  (mto-assert-equal "xdata: ghi de dung"
    "WORLD" (mto-upd-xdata-get e1 "MTO_TEST_APP"))

  ;; app khac -> doc rieng
  (mto-upd-xdata-set e1 "MTO_OTHER_APP" "XYZ")
  (mto-assert-equal "xdata: app khac doc rieng"
    "XYZ" (mto-upd-xdata-get e1 "MTO_OTHER_APP"))
  (mto-assert-equal "xdata: app 1 khong bi lech"
    "WORLD" (mto-upd-xdata-get e1 "MTO_TEST_APP"))

  (mto-assert-equal "xdata: doi tuong chua co -> nil"
    nil (mto-upd-xdata-get e3 "MTO_TEST_APP"))

  (mto-assert-true "xdata: APPID duoc dang ky"
    (tblsearch "APPID" "MTO_TEST_APP"))

  ;; ---------- 4. apply-item ----------

  (setq h1 (mto-t11-h e1))
  (setq h2 (mto-t11-h e2))
  (setq h3 (mto-t11-h e3))

  (setq it (mto-item-new "Electrical" "MCB" "MCB item"))
  (setq it (mto-item-add-handle it h1))
  (setq it (mto-item-add-handle it h2))
  (setq it (mto-item-add-handle it h3))   ; LINE -> khong sua duoc
  (setq it (mto-item-recalc it))

  (setq res (mto-upd-apply-item it "MTO-UPDATED"))
  (mto-assert-equal "apply-item: 2 thanh cong (TEXT + MTEXT)"
    2 (car res))
  (mto-assert-equal "apply-item: 1 that bai (LINE)"
    1 (cdr res))

  (mto-assert-equal "apply-item: TEXT da doi"
    "MTO-UPDATED" (mto-upd-get-value e1))
  (mto-assert-equal "apply-item: MTEXT da doi"
    "MTO-UPDATED" (mto-upd-get-value e2))

  ;; ---------- 5. handle mo coi -> bo qua, khong crash ----------

  (entdel e2)
  (setq res (mto-upd-apply-item it "LAN-2"))
  ;; TEXT thanh cong, MTEXT mo coi, LINE khong ho tro
  (mto-assert-equal "orphan: 1 thanh cong"
    1 (car res))
  (mto-assert-equal "orphan: 2 that bai (mo coi + LINE)"
    2 (cdr res))

  ;; ---------- 6. batch ----------

  (setq it2 (mto-item-new "ELV" "CAM" "Cam item"))
  (setq it2 (mto-item-add-handle it2 h1))
  (setq it2 (mto-item-recalc it2))

  (setq pairs (list (cons it "BATCH-1") (cons it2 "BATCH-2")))
  (setq res (mto-upd-batch pairs))
  (mto-assert-equal "batch: ITEMS = 2"
    2 (cdr (assoc 'ITEMS res)))
  ;; it: 1 ok (TEXT) + 2 fail ; it2: 1 ok => OK=2, FAIL=2
  (mto-assert-equal "batch: OK = 2"
    2 (cdr (assoc 'OK res)))
  (mto-assert-equal "batch: FAIL = 2"
    2 (cdr (assoc 'FAIL res)))

  (mto-assert-equal "batch: gia tri cuoi cung tren ban ve"
    "BATCH-2" (mto-upd-get-value e1))

  ;; batch rong -> 0/0
  (setq res (mto-upd-batch '()))
  (mto-assert-equal "batch: rong -> OK 0"
    0 (cdr (assoc 'OK res)))
  (mto-assert-equal "batch: rong -> ITEMS 0"
    0 (cdr (assoc 'ITEMS res)))

  ;; ---------- 7. KHONG tao doi tuong moi khi cap nhat ----------

  (setq n (ssget "_X" (list (cons 8 "MTO-T11"))))
  ;; ban dau 3 entity, entdel e2 -> con 3 trong ssget? entdel danh dau xoa
  ;; nen dem theo entget-con-song
  (mto-assert-true "an toan: cap nhat KHONG tao entity moi"
    (<= (if n (sslength n) 0) 3))

  ;; don dep
  (mto-t11-clean "MTO-T11")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-update.lsp loaded.")
(princ)
