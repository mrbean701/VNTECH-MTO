;;; ============================================================
;;; test-orphan.lsp -- Test cases cho mto-orphan.lsp (TASK-008)
;;; Tao entity THAT roi XOA de tao orphan that
;;; ============================================================

(defun mto-t8-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t8-line (layer x1 y1 x2 y2)
  (mto-t8-mklayer layer)
  (entmake (list '(0 . "LINE") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0))))
  ;; KHONG dung gia tri tra ve cua entmake lam ename -> dung entlast
  (entlast))

(defun mto-t8-handle (en) (cdr (assoc 5 (entget en))))

(defun mto-t8-clean (layer / ss i n e)
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

(defun mto-run-tests (out-path / e1 e2 h1 h2 db it it2 stats res pruned)

  (mto-test-reset)

  (mto-t8-clean "MTO-T8")

  ;; ---------- 1. exists-p voi entity THAT ----------

  (setq e1 (mto-t8-line "MTO-T8" 0 0 100 0))
  (setq e2 (mto-t8-line "MTO-T8" 0 10 100 10))
  (setq h1 (mto-t8-handle e1))
  (setq h2 (mto-t8-handle e2))

  (mto-assert-true "exists: handle khac rong" (and h1 (/= h1 "")))
  (mto-assert-true "exists: entity con song -> T"
    (mto-orphan-exists-p h1))

  (mto-assert-true "exists: nil -> nil"
    (not (mto-orphan-exists-p nil)))
  (mto-assert-true "exists: chuoi rong -> nil"
    (not (mto-orphan-exists-p "")))
  (mto-assert-true "exists: handle khong ton tai -> nil"
    (not (mto-orphan-exists-p "ZZZZZZZZ")))

  ;; ---------- 2. xoa that -> thanh orphan ----------

  (entdel e2)
  (mto-assert-true "exists: sau khi xoa -> nil (orphan)"
    (not (mto-orphan-exists-p h2)))
  (mto-assert-true "exists: entity khong bi xoa van song"
    (mto-orphan-exists-p h1))

  ;; ---------- 3. orphan cua mot item ----------

  (setq it (mto-item-new "Electrical" "Wire" "Wire run"))
  (setq it (mto-item-add-handle it h1))
  (setq it (mto-item-add-handle it h2))
  (mto-assert-equal "item: co 2 handle"
    2 (length (mto-item-get it 'HANDLES)))
  (mto-assert-equal "item: 1 handle mo coi"
    1 (length (mto-orphan-of-item it)))
  (mto-assert-equal "item: handle mo coi dung la h2"
    h2 (car (mto-orphan-of-item it)))

  ;; item toan handle song -> 0 orphan
  (setq it2 (mto-item-new "Electrical" "Wire" "Wire run 2"))
  (setq it2 (mto-item-add-handle it2 h1))
  (mto-assert-equal "item: khong co orphan -> 0"
    0 (length (mto-orphan-of-item it2)))

  ;; ---------- 4. thong ke DB ----------

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))
  (setq db (mto-db-merge-item db it2))

  (setq stats (mto-orphan-check-db db))
  (mto-assert-equal "stats: TOTAL handle = 3"
    3 (cdr (assoc 'TOTAL stats)))
  (mto-assert-equal "stats: ALIVE = 2"
    2 (cdr (assoc 'ALIVE stats)))
  (mto-assert-equal "stats: ORPHAN = 1"
    1 (cdr (assoc 'ORPHAN stats)))
  (mto-assert-equal "stats: so dong bi anh huong = 1"
    1 (cdr (assoc 'ITEMS-ORPHAN stats)))

  ;; ---------- 5. prune item ----------

  (setq res (mto-orphan-prune-item it))
  (mto-assert-equal "prune-item: bo 1 handle"
    1 (cadr res))
  (mto-assert-equal "prune-item: con 1 handle"
    1 (length (mto-item-get (car res) 'HANDLES)))
  (mto-assert-true "prune-item: handle con lai la h1"
    (equal (mto-item-get (car res) 'HANDLES) (list h1)))

  ;; ---------- 6. prune DB ----------

  (setq pruned (mto-orphan-prune-db db))
  (mto-assert-equal "prune-db: bo tong 1 handle"
    1 (cadr pruned))
  (mto-assert-equal "prune-db: DB van 2 dong"
    2 (mto-db-count (car pruned)))

  ;; sau khi prune -> khong con orphan
  (setq stats (mto-orphan-check-db (car pruned)))
  (mto-assert-equal "prune-db: ORPHAN = 0 sau khi prune"
    0 (cdr (assoc 'ORPHAN stats)))
  (mto-assert-equal "prune-db: ALIVE = 2"
    2 (cdr (assoc 'ALIVE stats)))

  ;; ---------- 7. report chuoi ----------

  (setq s (mto-orphan-report db))
  (mto-assert-true "report: co 'Tong handle'"
    (vl-string-search "Tong handle" s))
  (mto-assert-true "report: co 'Mo coi'"
    (vl-string-search "Mo coi" s))

  ;; ---------- 8. KHONG xoa doi tuong DWG ----------

  ;; h1 van song sau khi prune (prune chi xoa du lieu MTO)
  (mto-assert-true "an toan: prune KHONG xoa doi tuong trong DWG"
    (mto-orphan-exists-p h1))

  ;; ---------- 9. DB rong ----------

  (setq stats (mto-orphan-check-db '()))
  (mto-assert-equal "stats: DB rong -> TOTAL = 0"
    0 (cdr (assoc 'TOTAL stats)))
  (mto-assert-equal "stats: DB rong -> ORPHAN = 0"
    0 (cdr (assoc 'ORPHAN stats)))

  ;; don dep
  (mto-t8-clean "MTO-T8")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-orphan.lsp loaded.")
(princ)
