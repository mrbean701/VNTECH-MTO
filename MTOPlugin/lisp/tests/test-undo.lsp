;;; ============================================================
;;; test-undo.lsp -- Test cases cho mto-undo.lsp (TASK-012)
;;; Sua THAT roi khoi phuc THAT, doc lai ban ve de kiem
;;; ============================================================

(defun mto-t12-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t12-text (layer x y s)
  (mto-t12-mklayer layer)
  (entmake (list '(0 . "TEXT") '(100 . "AcDbEntity")
                 (cons 8 layer) (cons 10 (list x y 0.0))
                 (cons 1 s) (cons 40 2.5)))
  (entlast))

(defun mto-t12-line (layer x1 y1 x2 y2)
  (mto-t12-mklayer layer)
  (entmake (list '(0 . "LINE") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0))))
  (entlast))

(defun mto-t12-h (en) (cdr (assoc 5 (entget en))))

(defun mto-t12-clean (layer / ss i n e)
  (setq ss (ssget "_X" (list (cons 8 layer))))
  (if ss
    (progn
      (setq i 0 n (sslength ss))
      (while (< i n)
        (setq e (ssname ss i))
        (if e (entdel e))
        (setq i (1+ i)))))
  (princ))

(defun mto-run-tests (out-path / e1 e2 e3 h1 h2 h3 db it it2 snap c res pairs)

  (mto-test-reset)

  (mto-t12-clean "MTO-T12")

  ;; ---------- 1. capture-entity ----------

  (setq e1 (mto-t12-text "MTO-T12" 0 0 "GOC-1"))
  (setq e2 (mto-t12-text "MTO-T12" 0 10 "GOC-2"))
  (setq e3 (mto-t12-line "MTO-T12" 0 20 50 20))
  (setq h1 (mto-t12-h e1))
  (setq h2 (mto-t12-h e2))
  (setq h3 (mto-t12-h e3))

  (setq c (mto-undo-capture-entity h1))
  (mto-assert-equal "capture: handle dung"
    h1 (car c))
  (mto-assert-equal "capture: gia tri dung"
    "GOC-1" (cdr c))

  (mto-assert-equal "capture: LINE -> nil (khong phai TEXT)"
    nil (mto-undo-capture-entity h3))
  (mto-assert-equal "capture: handle chet -> nil"
    nil (mto-undo-capture-entity "ZZZZZZZZ"))

  ;; ---------- 2. snapshot ----------

  (setq it (mto-item-new "Electrical" "MCB" "MCB item"))
  (setq it (mto-item-add-handle it h1))
  (setq it (mto-item-add-handle it h2))
  (setq it (mto-item-add-handle it h3))   ; LINE -> khong chup
  (setq it (mto-item-recalc it))

  (setq snap (mto-undo-snapshot it))
  (mto-assert-equal "snapshot: 2 entry (bo LINE)"
    2 (mto-undo-count snap))
  (mto-assert-equal "snapshot: entry 1 la h1"
    h1 (car (car snap)))
  (mto-assert-equal "snapshot: entry 1 gia tri GOC-1"
    "GOC-1" (cdr (car snap)))

  ;; ---------- 3. snapshot-many ----------

  (setq it2 (mto-item-new "ELV" "CAM" "Cam item"))
  (setq it2 (mto-item-add-handle it2 h1))
  (setq it2 (mto-item-recalc it2))

  (setq snap (mto-undo-snapshot-many (list it it2)))
  ;; it: h1,h2 ; it2: h1  => 3 entry
  (mto-assert-equal "snapshot-many: 3 entry"
    3 (mto-undo-count snap))

  (mto-assert-equal "snapshot-many: rong -> nil"
    nil (mto-undo-snapshot-many '()))

  ;; ---------- 4. sua roi khoi phuc ----------

  (setq snap (mto-undo-snapshot it))
  (mto-undo-save snap)
  (mto-assert-equal "save: luu 2 entry"
    2 (mto-undo-count (mto-undo-load)))

  ;; sua ca 2
  (mto-upd-set-value e1 "DA-SUA-1")
  (mto-upd-set-value e2 "DA-SUA-2")
  (mto-assert-equal "sua: e1 da doi"
    "DA-SUA-1" (mto-upd-get-value e1))
  (mto-assert-equal "sua: e2 da doi"
    "DA-SUA-2" (mto-upd-get-value e2))

  ;; khoi phuc
  (setq res (mto-undo-restore))
  (mto-assert-equal "restore: 2 thanh cong"
    2 (car res))
  (mto-assert-equal "restore: 0 that bai"
    0 (cdr res))

  ;; doc LAI tu ban ve -> phai ve gia tri goc
  (mto-assert-equal "restore: e1 ve gia tri goc"
    "GOC-1" (mto-upd-get-value (mto-find-resolve h1)))
  (mto-assert-equal "restore: e2 ve gia tri goc"
    "GOC-2" (mto-upd-get-value (mto-find-resolve h2)))

  ;; ---------- 5. restore voi handle chet -> dem that bai ----------

  (setq snap (list (cons h1 "X1") (cons "ZZZZZZZZ" "X2")))
  (setq res (mto-undo-restore-list snap))
  (mto-assert-equal "restore-list: 1 thanh cong"
    1 (car res))
  (mto-assert-equal "restore-list: 1 that bai (handle chet)"
    1 (cdr res))
  (mto-assert-equal "restore-list: e1 thanh X1"
    "X1" (mto-upd-get-value e1))

  ;; ---------- 6. clear ----------

  (mto-assert-equal "clear: tra ve 0"
    0 (mto-undo-clear))
  (mto-assert-equal "clear: snapshot rong"
    nil (mto-undo-load))

  ;; ---------- 7. batch-safe (chup truoc khi sua) ----------

  (mto-upd-set-value e1 "TRUOC-SAFE")
  (mto-upd-set-value e2 "TRUOC-SAFE-2")

  (setq pairs (list (cons it "SAU-SAFE")))
  (setq res (mto-upd-batch-safe pairs))
  (mto-assert-equal "batch-safe: OK = 2"
    2 (cdr (assoc 'OK res)))
  (mto-assert-equal "batch-safe: SNAP-COUNT = 2"
    2 (cdr (assoc 'SNAP-COUNT res)))
  (mto-assert-equal "batch-safe: ban ve da doi"
    "SAU-SAFE" (mto-upd-get-value e1))

  ;; khoi phuc bang MTOUNDO logic
  (setq res (mto-undo-restore))
  (mto-assert-equal "batch-safe: khoi phuc ve TRUOC-SAFE"
    "TRUOC-SAFE" (mto-upd-get-value (mto-find-resolve h1)))

  ;; ---------- 8. describe ----------

  (setq snap (list (cons h1 "A") (cons h2 "B")))
  (mto-assert-true "describe: co so luong"
    (vl-string-search "2" (mto-undo-describe snap)))

  ;; ---------- 9. snapshot rong -> restore 0/0 ----------

  (setq res (mto-undo-restore-list '()))
  (mto-assert-equal "restore rong: OK 0"
    0 (car res))
  (mto-assert-equal "restore rong: FAIL 0"
    0 (cdr res))

  ;; don dep
  (mto-t12-clean "MTO-T12")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-undo.lsp loaded.")
(princ)
