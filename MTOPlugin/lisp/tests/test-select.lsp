;;; ============================================================
;;; test-select.lsp -- Test cases cho mto-select.lsp (TASK-001)
;;; Tao entity THAT trong drawing de test ssget + filter
;;; ============================================================

;; ---------- Helpers tao entity test ----------

(defun mto-t-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t-mkline (layer x1 y1 x2 y2)
  (mto-t-mklayer layer)
  (entmake (list '(0 . "LINE") (cons 8 layer)
                 (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0)))))

(defun mto-t-mktext (layer x y s)
  (mto-t-mklayer layer)
  (entmake (list '(0 . "TEXT") (cons 8 layer)
                 (cons 10 (list x y 0.0)) (cons 1 s) (cons 40 2.5))))

(defun mto-t-mkcircle (layer x y r)
  (mto-t-mklayer layer)
  (entmake (list '(0 . "CIRCLE") (cons 8 layer)
                 (cons 10 (list x y 0.0)) (cons 40 r))))

(defun mto-t-del-layer-ents (layer / ss i n e)
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

(defun mto-run-tests (out-path / f ss hs sum types layers n)

  (mto-test-reset)

  ;; ---------- 1. normalize-list (logic thuan) ----------

  (mto-assert-equal "normalize: 'TEXT, MTEXT ; INSERT'"
    '("TEXT" "MTEXT" "INSERT")
    (mto-sel-normalize-list "TEXT, MTEXT ; INSERT"))

  (mto-assert-equal "normalize: chuoi rong -> nil"
    nil (mto-sel-normalize-list ""))

  (mto-assert-equal "normalize: nil -> nil"
    nil (mto-sel-normalize-list nil))

  (mto-assert-equal "normalize: ha chu thuong -> in hoa"
    '("LINE") (mto-sel-normalize-list "line"))

  (mto-assert-equal "normalize: bo phan tu rong"
    '("A" "B") (mto-sel-normalize-list "A,,B,"))

  ;; ---------- 2. valid-mode-p ----------

  (mto-assert-true "mode: 'W' hop le" (mto-sel-valid-mode-p "W"))
  (mto-assert-true "mode: 'w' hop le (khong phan biet hoa thuong)"
    (mto-sel-valid-mode-p "w"))
  (mto-assert-true "mode: 'WP' hop le" (mto-sel-valid-mode-p "WP"))
  (mto-assert-true "mode: 'CP' hop le" (mto-sel-valid-mode-p "CP"))
  (mto-assert-true "mode: 'Z' KHONG hop le"
    (not (mto-sel-valid-mode-p "Z")))
  (mto-assert-true "mode: nil KHONG hop le"
    (not (mto-sel-valid-mode-p nil)))

  ;; ---------- 3. build-filter ----------

  (setq f (mto-sel-build-filter '("TEXT" "MTEXT") '("EL-*")))
  (mto-assert-equal "filter: co 2 phan tu"
    2 (length f))
  (mto-assert-equal "filter: DXF 0 = TEXT,MTEXT"
    "TEXT,MTEXT" (cdr (assoc 0 f)))
  (mto-assert-equal "filter: DXF 8 = EL-*"
    "EL-*" (cdr (assoc 8 f)))

  (setq f (mto-sel-build-filter '("LINE") nil))
  (mto-assert-equal "filter: chi types -> 1 phan tu"
    1 (length f))
  (mto-assert-equal "filter: khong co layer"
    nil (assoc 8 f))

  (mto-assert-equal "filter: rong -> nil"
    nil (mto-sel-build-filter nil nil))

  ;; ---------- 4. ssget tren entity THAT ----------

  (mto-t-del-layer-ents "MTO-T-LINE")
  (mto-t-del-layer-ents "MTO-T-TEXT")

  (mto-t-mkline "MTO-T-LINE" 0 0 100 0)
  (mto-t-mkline "MTO-T-LINE" 0 10 100 10)
  (mto-t-mkline "MTO-T-LINE" 0 20 100 20)
  (mto-t-mktext "MTO-T-TEXT" 0 30 "MCB 20A")
  (mto-t-mktext "MTO-T-TEXT" 0 40 "MCB 32A")

  ;; loc theo loai LINE + layer
  (setq ss (ssget "_X" (list (cons 0 "LINE") (cons 8 "MTO-T-LINE"))))
  (mto-assert-equal "ssget: 3 LINE tren layer MTO-T-LINE"
    3 (if ss (sslength ss) 0))

  ;; loc theo loai TEXT
  (setq ss (ssget "_X" (list (cons 0 "TEXT") (cons 8 "MTO-T-TEXT"))))
  (mto-assert-equal "ssget: 2 TEXT tren layer MTO-T-TEXT"
    2 (if ss (sslength ss) 0))

  ;; filter wildcard layer
  (setq ss (ssget "_X" (list (cons 8 "MTO-T-*"))))
  (mto-assert-equal "ssget: wildcard MTO-T-* -> 5 doi tuong"
    5 (if ss (sslength ss) 0))

  ;; ---------- 5. ss -> handles ----------

  (setq ss (ssget "_X" (list (cons 8 "MTO-T-LINE"))))
  (setq hs (mto-sel-ss->handles ss))
  (mto-assert-equal "ss->handles: 3 handle"
    3 (length hs))
  (mto-assert-true "ss->handles: handle la chuoi khac rong"
    (and (car hs) (/= (car hs) "")))

  ;; ---------- 6. ss -> types ----------

  (setq ss (ssget "_X" (list (cons 8 "MTO-T-*"))))
  (setq types (mto-sel-ss->types ss))
  (mto-assert-equal "ss->types: ('LINE' . 3)"
    3 (cdr (assoc "LINE" types)))
  (mto-assert-equal "ss->types: ('TEXT' . 2)"
    2 (cdr (assoc "TEXT" types)))

  ;; ---------- 7. ss -> layers ----------

  (setq layers (mto-sel-ss->layers ss))
  (mto-assert-equal "ss->layers: MTO-T-LINE = 3"
    3 (cdr (assoc "MTO-T-LINE" layers)))
  (mto-assert-equal "ss->layers: MTO-T-TEXT = 2"
    2 (cdr (assoc "MTO-T-TEXT" layers)))

  ;; ---------- 8. summary ----------

  (setq sum (mto-sel-ss-summary ss))
  (mto-assert-equal "summary: TOTAL = 5"
    5 (cdr (assoc 'TOTAL sum)))
  (mto-assert-true "summary: co TYPES"
    (assoc 'TYPES sum))
  (mto-assert-true "summary: co LAYERS"
    (assoc 'LAYERS sum))

  ;; ---------- 9. all-handles (tich hop TASK-005) ----------

  (setq hs (mto-sel-all-handles '("LINE") '("MTO-T-LINE")))
  (mto-assert-equal "all-handles: LINE/MTO-T-LINE -> 3"
    3 (length hs))

  ;; ---------- 10. tich hop data model: nap handle vao item ----------

  (setq it (mto-item-new "Electrical" "Wire" "Wire run"))
  (foreach h hs (setq it (mto-item-add-handle it h)))
  (setq it (mto-item-add-auto it (float (length hs))))
  (setq it (mto-item-recalc it))
  (mto-assert-equal "tich hop: item nhan 3 handle"
    3 (length (mto-item-get it 'HANDLES)))
  (mto-assert-close "tich hop: QTY = 3"
    3.0 (mto-item-get it 'QTY) 0.0001)

  ;; don dep
  (mto-t-del-layer-ents "MTO-T-LINE")
  (mto-t-del-layer-ents "MTO-T-TEXT")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-select.lsp loaded.")
(princ)
