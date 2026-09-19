;;; ============================================================
;;; mto-floor.lsp -- MTO: Floor / Area / Zone (TASK-015)
;;;
;;; Muc tieu: du lieu MTO co the gan:
;;;     FLOOR  (tang, vd "T1", "T2", "HAM")
;;;     ZONE   (khu vuc, vd "Zone-A")
;;;     AREA   (dien tich / phong, vd "P101")
;;; va co kha nang LOC + SUBTOTAL theo cac truong nay.
;;;
;;; Cach gan:
;;;   1. Theo LAYER  (rules: ((pattern . floor) ...)) -- dung wcmatch
;;;   2. Theo HANDLE (khi nguoi dung chon vung -> gan cho item trong vung)
;;;   3. Thu cong theo STT
;;;
;;; Logic thuan (testable headless):
;;;   mto-floor-set                 -- gan floor/zone/area
;;;   mto-floor-of-item             -- doc
;;;   mto-floor-match-p             -- wcmatch layer voi pattern
;;;   mto-floor-assign-by-layer     -- gan hang loat theo layer
;;;   mto-floor-assign-by-handles   -- gan theo handle (vung chon)
;;;   mto-floor-list                -- danh sach floor co trong DB
;;;   mto-floor-filter              -- loc theo floor
;;;   mto-floor-subtotal            -- subtotal theo floor (dung mto-sub-group)
;;;
;;; Command: MTOFLOOR
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. GAN / DOC
;; ------------------------------------------------------------

(defun mto-floor-set (it fl zn ar)
  (mto-item-set (mto-item-set (mto-item-set it 'FLOOR (if fl fl ""))
                              'ZONE  (if zn zn ""))
                'AREA  (if ar ar "")))

(defun mto-floor-of-item (it)       (mto-item-get it 'FLOOR))
(defun mto-zone-of-item (it)        (mto-item-get it 'ZONE))
(defun mto-area-of-item (it)        (mto-item-get it 'AREA))

;; Gan hang loat ca DB (dat tat ca ve cung 1 tang/khu)
(defun mto-floor-set-all (db fl zn ar / out)
  (setq out '())
  (foreach it db
    (setq out (append out (list (mto-floor-set it fl zn ar)))))
  out)

;; ------------------------------------------------------------
;; 2. GAN THEO LAYER (wcmatch)
;; ------------------------------------------------------------

;; Khop layer voi pattern (wildcard *, ?, [..]) -- dung wcmatch cua AutoLISP
(defun mto-floor-match-p (layer pattern)
  (if (or (null layer) (null pattern)) nil
    (if (wcmatch (mto-str-up layer) (mto-str-up pattern)) t nil)))

;; rules: alist ((LAYER-PATTERN . FLOOR) ...). Pattern dau tien khop se thang.
(defun mto-floor-find-rule (layer rules / res)
  (setq res nil)
  (foreach r rules
    (if (and (null res) (mto-floor-match-p layer (car r)))
      (setq res (cdr r))))
  res)

;; Gan floor theo layer rules. Tra ve (DB-MOI . ASSIGNED)
(defun mto-floor-assign-by-layer (db rules zone area / out assigned fl)
  (setq out '() assigned 0)
  (foreach it db
    (setq fl (mto-floor-find-rule (mto-item-get it 'LAYER) rules))
    (if fl
      (progn
        (setq out (append out (list (mto-floor-set it fl zone area))))
        (setq assigned (1+ assigned)))
      (setq out (append out (list it)))))
  (cons out assigned))

;; ------------------------------------------------------------
;; 3. GAN THEO HANDLE (vung chon)
;; ------------------------------------------------------------

;; Gan floor cho item co BAT KY handle nao nam trong danh sach `handles`
(defun mto-floor-item-touches (it handles / hit)
  (setq hit nil)
  (foreach h (mto-item-get it 'HANDLES)
    (if (member h handles) (setq hit t)))
  (if hit t nil))

;; Tra ve (DB-MOI . ASSIGNED)
(defun mto-floor-assign-by-handles (db handles fl zn ar / out assigned)
  (setq out '() assigned 0)
  (foreach it db
    (if (mto-floor-item-touches it handles)
      (progn
        (setq out (append out (list (mto-floor-set it fl zn ar))))
        (setq assigned (1+ assigned)))
      (setq out (append out (list it)))))
  (cons out assigned))

;; ------------------------------------------------------------
;; 4. LOC / SUBTOTAL
;; ------------------------------------------------------------

;; Danh sach floor co trong DB (khac rong), da sap xep
;; LUU Y: phai dung '< (symbol ham), KHONG dung '( < ) -- '( < ) la mot LIST
;; co 1 phan tu, vl-sort se goi (<) voi 0 tham so => "too few arguments".
(defun mto-floor-list (db / out v)
  (setq out '())
  (foreach it db
    (setq v (mto-item-get it 'FLOOR))
    (if (and v (/= v "") (not (member v out)))
      (setq out (append out (list v)))))
  (vl-sort out '<))

;; Loc theo floor
(defun mto-floor-filter (db fl / out)
  (setq out '())
  (foreach it db
    (if (equal (mto-item-get it 'FLOOR) fl)
      (setq out (append out (list it)))))
  out)

;; Dem item chua gan floor
(defun mto-floor-unassigned (db / n v)
  (setq n 0)
  (foreach it db
    (setq v (mto-item-get it 'FLOOR))
    (if (or (null v) (= v "")) (setq n (1+ n))))
  n)

;; Subtotal theo FLOOR (dung ha tang mto-sub-group cua TASK-014)
(defun mto-floor-subtotal (db)
  (mto-sub-group db 'FLOOR))

;; ------------------------------------------------------------
;; 5. COMMAND
;; ------------------------------------------------------------

(defun mto-floor-print (db)
  (princ "\n--- SUBTOTAL theo FLOOR ---")
  (foreach g (mto-floor-subtotal db)
    (princ (strcat "\n" (if (= (car g) "") "(chua gan)" (car g))
                   " | NET=" (mto-num->str (mto-sub-net-of g))
                   " | LEN=" (mto-num->str (mto-sub-total-of g 'LEN))
                   " | dong=" (itoa (fix (mto-sub-total-of g 'COUNT))))))
  (princ (strcat "\nChua gan floor: " (itoa (mto-floor-unassigned db)) " dong."))
  (princ (strcat "\nDanh sach floor: "
                 (if (mto-floor-list db)
                   (mto-str-join (mto-floor-list db) ", ")
                   "(trong)"))))

(defun c:MTOFLOOR ( / db fl zn ar layerPtns assigned res mode)
  (mto-ui-start "MTOFLOOR" "Gan tang / khu vuc / dien tich")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (mto-floor-print db)
      (princ "\n\n--- GAN FLOOR ---")
      (princ "\n1 = Gan theo LAYER (pattern)")
      (princ "\n2 = Gan theo HANDLE (vung vua chon bang MTOSEL)")
      (princ "\n3 = Gan TAT CA")
      (setq mode (getstring T "\nChon cach gan [1/2/3] <1>: "))
      (if (= mode "") (setq mode "1"))

      (cond
        ;; --- theo layer ---
        ((= mode "1")
         (setq layerPtns (mto-str-trim (getstring T "\nPattern layer (vd EL-*), Enter = huy: ")))
         (if (/= layerPtns "")
           (progn
             (setq fl (mto-str-trim (getstring T "\nFLOOR (vd T1): ")))
             (setq zn (mto-str-trim (getstring T "\nZONE (Enter = bo qua): ")))
             (setq ar (mto-str-trim (getstring T "\nAREA (Enter = bo qua): ")))
             (setq res (mto-floor-assign-by-layer db
                         (list (cons layerPtns fl)) zn ar))
             (mto-db-save (car res))
             (princ (strcat "\nDa gan floor cho " (itoa (cdr res)) " dong."))
             (mto-floor-print (car res)))))

        ;; --- theo handle (vung da chon) ---
        ((= mode "2")
         (if (null *MTO-LAST-SELECTION*)
           (princ "\nChua co vung chon nao. Hay chay MTOSEL truoc.")
           (progn
             (princ (strcat "\nDung " (itoa (length *MTO-LAST-SELECTION*))
                            " handle tu *MTO-LAST-SELECTION*."))
             (setq fl (mto-str-trim (getstring T "\nFLOOR: ")))
             (setq zn (mto-str-trim (getstring T "\nZONE: ")))
             (setq ar (mto-str-trim (getstring T "\nAREA: ")))
             (setq res (mto-floor-assign-by-handles db *MTO-LAST-SELECTION* fl zn ar))
             (mto-db-save (car res))
             (princ (strcat "\nDa gan floor cho " (itoa (cdr res)) " dong."))
             (mto-floor-print (car res)))))

        ;; --- tat ca ---
        ((= mode "3")
         (setq fl (mto-str-trim (getstring T "\nFLOOR cho TAT CA: ")))
         (setq zn (mto-str-trim (getstring T "\nZONE: ")))
         (setq ar (mto-str-trim (getstring T "\nAREA: ")))
         (mto-db-save (mto-floor-set-all db fl zn ar))
         (princ "\nDa gan cho tat ca cac dong.")
         (mto-floor-print (mto-db-load)))

        (t (princ "\nLua chon khong hop le.")))))
  (princ))

(princ "\nmto-floor.lsp loaded.")
(princ)
