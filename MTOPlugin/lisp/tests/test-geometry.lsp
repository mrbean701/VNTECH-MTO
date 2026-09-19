;;; ============================================================
;;; test-geometry.lsp -- Test cases cho mto-geometry.lsp (TASK-004)
;;; Tao LINE/LWPOLYLINE/ARC/CIRCLE THAT de do chieu dai
;;; ============================================================

(defun mto-t4-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t4-line (layer x1 y1 x2 y2)
  (mto-t4-mklayer layer)
  (entmake (list '(0 . "LINE") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0)))))

(defun mto-t4-lwpoly (layer pts)
  (mto-t4-mklayer layer)
  (entmake (append
             (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
                   (cons 8 layer) (cons 90 (length pts)) '(70 . 0))
             (mapcar '(lambda (p) (cons 10 p)) pts))))

(defun mto-t4-arc (layer cx cy r a1 a2)
  (mto-t4-mklayer layer)
  (entmake (list '(0 . "ARC") '(100 . "AcDbEntity") '(100 . "AcDbCircle")
                 (cons 8 layer)
                 (cons 10 (list cx cy 0.0)) (cons 40 r)
                 '(100 . "AcDbArc")
                 (cons 50 a1) (cons 51 a2))))

(defun mto-t4-circle (layer cx cy r)
  (mto-t4-mklayer layer)
  (entmake (list '(0 . "CIRCLE") '(100 . "AcDbEntity") '(100 . "AcDbCircle")
                 (cons 8 layer)
                 (cons 10 (list cx cy 0.0)) (cons 40 r))))

(defun mto-t4-text (layer x y s)
  (mto-t4-mklayer layer)
  (entmake (list '(0 . "TEXT") '(100 . "AcDbEntity")
                 (cons 8 layer) (cons 10 (list x y 0.0))
                 (cons 1 s) (cons 40 2.5))))

(defun mto-t4-clean (layer / ss i n e)
  (setq ss (ssget "_X" (list (cons 8 layer))))
  (if ss
    (progn
      (setq i 0 n (sslength ss))
      (while (< i n)
        (setq e (ssname ss i))
        (if e (entdel e))
        (setq i (1+ i)))))
  (princ))

;; Tim entity theo loai trong selection set
(defun mto-t4-find (ss ty / i n e found)
  (setq i 0 n (sslength ss) found nil ty (mto-str-up ty))
  (while (and (< i n) (null found))
    (setq e (ssname ss i))
    (if (and e (= (mto-str-up (cdr (assoc 0 (entget e)))) ty))
      (setq found e))
    (setq i (1+ i)))
  found)

;; ============================================================

(defun mto-run-tests (out-path / ss len res db e it oldUnits)

  (mto-test-reset)

  ;; ---------- 1. kind / entity-p ----------

  (mto-t4-clean "MTO-T4")
  (mto-t4-line "MTO-T4" 0 0 100 0)
  (mto-t4-lwpoly "MTO-T4" '((0 0) (100 0) (100 50)))
  (mto-t4-arc "MTO-T4" 0 0 50.0 0.0 pi)
  (mto-t4-circle "MTO-T4" 200 200 10.0)
  (mto-t4-text "MTO-T4" 0 100 "KHONG-PHAI-GEOMETRY")

  (setq ss (ssget "_X" (list (cons 8 "MTO-T4"))))
  (mto-assert-equal "tao duoc 5 doi tuong"
    5 (if ss (sslength ss) 0))

  (setq e (mto-t4-find ss "LINE"))
  (mto-assert-equal "kind: LINE"
    "LINE" (mto-geo-kind e))
  (mto-assert-true "entity-p: LINE duoc ho tro"
    (mto-geo-entity-p e))

  (setq e (mto-t4-find ss "LWPOLYLINE"))
  (mto-assert-equal "kind: LWPOLYLINE"
    "LWPOLYLINE" (mto-geo-kind e))

  (setq e (mto-t4-find ss "ARC"))
  (mto-assert-equal "kind: ARC"
    "ARC" (mto-geo-kind e))

  (setq e (mto-t4-find ss "CIRCLE"))
  (mto-assert-equal "kind: CIRCLE"
    "CIRCLE" (mto-geo-kind e))

  (setq e (mto-t4-find ss "TEXT"))
  (mto-assert-equal "kind: TEXT -> nil (khong do dai)"
    nil (mto-geo-kind e))
  (mto-assert-true "entity-p: TEXT khong duoc ho tro"
    (not (mto-geo-entity-p e)))

  ;; ---------- 2. do chieu dai ----------

  (setq e (mto-t4-find ss "LINE"))
  (setq len (mto-geo-length e))
  (mto-assert-close "length: LINE 100 don vi"
    100.0 len 0.001)

  (setq e (mto-t4-find ss "LWPOLYLINE"))
  (setq len (mto-geo-length e))
  ;; (0,0)->(100,0)=100 ; (100,0)->(100,50)=50 => 150
  (mto-assert-close "length: LWPOLYLINE = 150"
    150.0 len 0.001)

  (setq e (mto-t4-find ss "ARC"))
  (setq len (mto-geo-length e))
  ;; nua duong tron r=50 : pi*50 = 157.0796
  (mto-assert-close "length: ARC nua duong tron r=50"
    (* pi 50.0) len 0.01)

  (setq e (mto-t4-find ss "CIRCLE"))
  (setq len (mto-geo-length e))
  ;; chu vi 2*pi*10 = 62.8319
  (mto-assert-close "length: CIRCLE r=10 (chu vi)"
    (* 2.0 pi 10.0) len 0.01)

  (mto-assert-equal "length: TEXT -> nil"
    nil (mto-geo-length (mto-t4-find ss "TEXT")))

  (mto-assert-equal "length: nil -> nil"
    nil (mto-geo-length nil))

  ;; ---------- 3. don vi ----------

  (mto-assert-equal "unit: ma 4 -> mm"
    "mm" (mto-geo-unit-text 4))
  (mto-assert-equal "unit: ma 6 -> m"
    "m" (mto-geo-unit-text 6))
  (mto-assert-equal "unit: ma 1 -> in"
    "in" (mto-geo-unit-text 1))
  (mto-assert-equal "unit: ma 0 -> ? (khong xac dinh)"
    "?" (mto-geo-unit-text 0))
  (mto-assert-equal "unit: ma la -> ?"
    "?" (mto-geo-unit-text 999))

  ;; dat INSUNITS = 4 (mm) de test that
  (setq oldUnits (getvar "INSUNITS"))
  (setvar "INSUNITS" 4)
  (mto-assert-equal "unit: doc tu ban ve = mm"
    "mm" (mto-geo-current-unit))
  (setvar "INSUNITS" 0)
  (mto-assert-equal "unit: INSUNITS=0 -> ?"
    "?" (mto-geo-current-unit))
  (setvar "INSUNITS" oldUnits)

  ;; ---------- 4. tong chieu dai selection set ----------

  ;; tao selection set chi gom geometry (khong co TEXT)
  (setq ss (ssget "_X" (list (cons 8 "MTO-T4")
                             (cons 0 "LINE,LWPOLYLINE,ARC,CIRCLE"))))
  (setq res (mto-geo-total-length ss))
  (mto-assert-equal "total: khong bo qua doi tuong nao"
    0 (cdr (assoc 'SKIPPED res)))
  (mto-assert-close "total: 100 + 150 + 157.08 + 62.83"
    (+ 100.0 150.0 (* pi 50.0) (* 2.0 pi 10.0))
    (cdr (assoc 'TOTAL res)) 0.05)

  ;; ---------- 5. scan vao DB ----------

  (setq res (mto-geo-scan-ss ss '()))
  (setq db (cdr (assoc 'DB res)))
  (mto-assert-equal "scan: xu ly 4 doi tuong"
    4 (cdr (assoc 'ADDED res)))

  ;; gom theo layer -> 1 dong (tat ca cung layer MTO-T4)
  (mto-assert-equal "scan: gom theo layer -> 1 dong"
    1 (mto-db-count db))

  (setq it (car db))
  (mto-assert-equal "scan: SOURCETYPE = GEOMETRY"
    "GEOMETRY" (mto-item-get it 'SOURCETYPE))
  (mto-assert-equal "scan: LAYER = MTO-T4"
    "MTO-T4" (mto-item-get it 'LAYER))
  (mto-assert-close "scan: LENGTH = tong chieu dai"
    (+ 100.0 150.0 (* pi 50.0) (* 2.0 pi 10.0))
    (mto-item-get it 'LENGTH) 0.05)
  (mto-assert-equal "scan: gop 4 handle"
    4 (length (mto-item-get it 'HANDLES)))

  ;; ---------- 6. tach nhom theo layer khac nhau ----------

  (mto-t4-clean "MTO-T4B")
  (mto-t4-line "MTO-T4B" 0 0 200 0)
  (setq ss (ssget "_X" (list (cons 8 "MTO-T4B"))))
  (setq res (mto-geo-scan-ss ss db))
  (setq db (cdr (assoc 'DB res)))
  (mto-assert-equal "scan: layer khac -> 2 dong"
    2 (mto-db-count db))

  ;; ---------- 7. loc theo loai ----------

  (setq ss (ssget "_X" (list (cons 8 "MTO-T4") (cons 0 "LINE"))))
  (mto-assert-equal "loc: chi LINE -> 1 doi tuong"
    1 (if ss (sslength ss) 0))

  ;; don dep
  (mto-t4-clean "MTO-T4")
  (mto-t4-clean "MTO-T4B")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-geometry.lsp loaded.")
(princ)
