;;; ============================================================
;;; mto-geometry.lsp -- MTO: boc chieu dai hinh hoc (TASK-004)
;;;
;;; Muc tieu:
;;;   - Do chieu dai LINE / LWPOLYLINE / POLYLINE / ARC / CIRCLE
;;;   - Loc theo layer
;;;   - Tinh SumLength
;;;   - The hien RO DON VI (khong tu y gia dinh neu khong xac dinh duoc)
;;;
;;; Logic thuan (testable headless):
;;;   mto-geo-kind           -- loai hinh hoc
;;;   mto-geo-entity-p       -- co ho tro do dai?
;;;   mto-geo-length         -- chieu dai mot doi tuong
;;;   mto-geo-insunits       -- ma don vi ban ve
;;;   mto-geo-unit-text      -- ma -> chuoi don vi
;;;   mto-geo-scan-ss        -- quet SumLength vao db (gom theo layer)
;;;   mto-geo-total-length   -- tong chieu dai selection set
;;;
;;; Command: MTOGEO
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. BANG DON VI (theo AutoCAD INSUNITS)
;; ------------------------------------------------------------

(setq *MTO-INSUNITS-TABLE*
  '((0 . "?")      ; unitless - KHONG xac dinh duoc
    (1 . "in")
    (2 . "ft")
    (3 . "mi")
    (4 . "mm")
    (5 . "cm")
    (6 . "m")
    (7 . "km")
    (8 . "microin")
    (9 . "mil")
    (10 . "yd")
    (11 . "angstrom")
    (12 . "nm")
    (13 . "um")
    (14 . "dm")
    (15 . "dam")
    (16 . "hm")
    (17 . "gm")
    (18 . "au")
    (19 . "ly")
    (20 . "pc")))

;; ------------------------------------------------------------
;; 2. LOGIC THUAN
;; ------------------------------------------------------------

;; Loai hinh hoc do duoc chieu dai
(defun mto-geo-kind (en / ty)
  (if (null en) nil
    (progn
      (setq ty (mto-str-up (cdr (assoc 0 (entget en)))))
      (cond
        ((= ty "LINE")       "LINE")
        ((= ty "LWPOLYLINE") "LWPOLYLINE")
        ((= ty "POLYLINE")   "POLYLINE")
        ((= ty "ARC")        "ARC")
        ((= ty "CIRCLE")     "CIRCLE")
        ((= ty "SPLINE")     "SPLINE")
        ((= ty "ELLIPSE")    "ELLIPSE")
        (t nil)))))

(defun mto-geo-entity-p (en)
  (if (mto-geo-kind en) t nil))

;; Chieu dai mot doi tuong (dung vlax-curve cho moi loai curve)
(defun mto-geo-length (en / kind res)
  (if (null en) nil
    (progn
      (setq kind (mto-geo-kind en))
      (if (null kind) nil
        (progn
          (setq res
            (vl-catch-all-apply
              '(lambda ()
                 (vlax-curve-getDistAtParam
                   en
                   (vlax-curve-getEndParam en)))))
          (if (vl-catch-all-error-p res) nil res))))))

;; Ma don vi ban ve
(defun mto-geo-insunits ()
  (getvar "INSUNITS"))

;; Ma -> chuoi don vi ("?" neu khong xac dinh)
(defun mto-geo-unit-text (code / pair)
  (setq pair (assoc code *MTO-INSUNITS-TABLE*))
  (if pair (cdr pair) "?"))

;; Don vi cua ban ve hien tai
(defun mto-geo-current-unit ()
  (mto-geo-unit-text (mto-geo-insunits)))

;; ------------------------------------------------------------
;; 2b. TU PHAT HIEN DON VI THAT CUA BAN VE
;;
;; VAN DE THUC TE da gap: ban ve VN ve bang MM nhung INSUNITS khai bao
;; 1 (INCH) do di san tu ban ve nuoc ngoai. Hau qua: moi chieu dai sai
;; 25.4 lan (1 inch = 25.4 mm).
;;
;; Cach phat hien: doc cac DIMENSION co san trong ban ve (DXF 42).
;;   - Cua di lai nguoi VN rong 800-900mm; cua 1 canh 700-900;
;;     cua doi 1200-1800; tuong/tim ~200-300
;;   => neu phan lon gia tri trong khoang 100..5000 thi gan nhu chac chan la MM
;;   - Ban ve dung MET: gia tri thuong 0.8..20
;;   - Ban ve dung INCH: gia tri thuong 24..80 (cua ~32-36 inch)
;;
;; Tra ve: (DETECTED . "mm"|"m"|"in"|"?") (SAMPLES . n) (MISMATCH . T/nil)
;; ------------------------------------------------------------
(defun mto-geo-detect-unit ( / ss i n e m vals nm nn nin samples)
  (setq ss (ssget "_X" '((0 . "DIMENSION"))))
  (setq n (if ss (sslength ss) 0))
  (setq vals '())
  (setq i 0)
  (while (and (< i n) (< (length vals) 60))
    (setq e (ssname ss i))
    (if e
      (progn
        (setq m (cdr (assoc 42 (entget e))))       ; measurement
        (if (and m (> m 0)) (setq vals (append vals (list m))))))
    (setq i (1+ i)))
  (setq samples (length vals))
  (setq nm 0 nn 0 nin 0)
  (foreach v vals
    (cond
      ((and (>= v 50.0) (<= v 20000.0)) (setq nm (1+ nm)))     ; mm
      ((and (> v 0.0) (< v 50.0))       (setq nn (1+ nn)))      ; m
      (t (setq nin (1+ nin)))))
  (list
    (cons 'SAMPLES samples)
    (cons 'MM nm)
    (cons 'M nn)
    (cons 'OTHER nin)
    (cons 'DETECTED
      (cond
        ((and (> samples 0) (>= nm (* 0.6 samples))) "mm")
        ((and (> samples 0) (>= nn (* 0.6 samples))) "m")
        (t "?")))))

;; Canh bao neu INSUNITS mau thuan voi don vi thuc do duoc.
;; In ra man hinh + tra ve chuoi canh bao (nil neu khong co van de).
(defun mto-geo-warn-unit ( / ins det w)
  (setq ins (mto-geo-current-unit))
  (setq det (mto-geo-detect-unit))
  (setq w nil)
  (if (> (cdr (assoc 'SAMPLES det)) 0)
    (progn
      (princ (strcat "\n[Kiem tra don vi] Doc " (itoa (cdr (assoc 'SAMPLES det)))
                     " kich thuoc: mm=" (itoa (cdr (assoc 'MM det)))
                     " m=" (itoa (cdr (assoc 'M det)))
                     " khac=" (itoa (cdr (assoc 'OTHER det)))))
      (cond
        ;; INSUNITS noi inch/foot nhung thuc te la mm
        ((and (member ins '("in" "ft"))
              (= (cdr (assoc 'DETECTED det)) "mm"))
         (setq w (strcat "CANH BAO DON VI: INSUNITS khai bao '" ins
                         "' nhung kich thuoc trong ban ve la MILIMET."
                         "\n  => MOI chieu dai se SAI 25.4 lan neu khong sua."
                         "\n  => CACH SUA: go lenh INSUNITS, dat = 4 (mm), roi chay lai MTOGEO."
                         "\n  => Hoac: OPTIONS > Drawing Settings > Units > Milimeters.")))
        ((and (member ins '("in" "ft"))
              (= (cdr (assoc 'DETECTED det)) "m"))
         (setq w (strcat "CANH BAO DON VI: INSUNITS khai bao '" ins
                         "' nhung kich thuoc la MET."
                         "\n  => CACH SUA: go INSUNITS, dat = 6 (m).")))
        ;; INSUNITS noi mm nhung thuc te la m
        ((and (= ins "mm") (= (cdr (assoc 'DETECTED det)) "m"))
         (setq w (strcat "CANH BAO DON VI: INSUNITS khai bao 'mm'"
                         " nhung kich thuoc la MET."
                         "\n  => CACH SUA: go INSUNITS, dat = 6 (m).")))
        ;; INSUNITS khong khai bao
        ((= ins "?")
         (setq w (strcat "CANH BAO: ban ve khong khai bao don vi (INSUNITS=0)."
                         "\n  => Don vi suy doan tu kich thuoc: "
                         (cdr (assoc 'DETECTED det))
                         "\n  => Nen dat INSUNITS cho dung (4=mm, 6=m).")))))
    (if (member ins '("in" "ft"))
      (setq w (strcat "CANH BAO: INSUNITS = '" ins "' (khong phai don vi do luong VN)."
                      "\n  => Kiem tra lai: ban ve co the ve bang mm du khai bao inch."
                      "\n  => Go INSUNITS de doi thanh 4 (mm)."))))
  (if w (progn (princ "\n") (princ w) (princ "\n")))
  (list (cons 'WARN w) (cons 'DETECT det) (cons 'INSUNIT ins)))

;; ------------------------------------------------------------
;; 3. QUET
;; ------------------------------------------------------------

;; Tong chieu dai mot selection set
(defun mto-geo-total-length (ss / i n e len total skipped)
  (setq i 0 n (if ss (sslength ss) 0) total 0.0 skipped 0)
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (progn
        (setq len (mto-geo-length e))
        (if len
          (setq total (+ total len))
          (setq skipped (1+ skipped)))))
    (setq i (1+ i)))
  (list (cons 'TOTAL total) (cons 'SKIPPED skipped)))

;; Quet geometry -> db, gom nhom theo LAYER
(defun mto-geo-scan-ss (ss db / i n e kind len layer unit it added)
  (setq i 0 n (if ss (sslength ss) 0) added 0)
  (setq unit (mto-geo-current-unit))
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (progn
        (setq kind (mto-geo-kind e))
        (setq len  (mto-geo-length e))
        (if (and kind len)
          (progn
            (setq layer (cdr (assoc 8 (entget e))))
            ;; Gom theo layer: TYPE = layer, NAME = layer
            (setq it (mto-item-new *MTO-CAT-OTHER* layer layer))
            (setq it (mto-item-set it 'LAYER layer))
            (setq it (mto-item-set it 'PREFIX (mto-text-recognize-prefix layer)))
            (setq it (mto-item-set it 'CATEGORY
                       (mto-text-category-for-prefix
                         (mto-item-get it 'PREFIX))))
            (setq it (mto-item-set it 'SOURCETYPE *MTO-SRC-GEOM*))
            (setq it (mto-item-set it 'SOURCEOBJECT kind))
            (setq it (mto-item-set it 'UNIT unit))
            (setq it (mto-item-set it 'DESCRIPTION (strcat kind " tren layer " layer)))
            (setq it (mto-item-add-length it len))
            (setq it (mto-item-set it 'AUTOQTY 1.0))
            (setq it (mto-item-add-handle it (cdr (assoc 5 (entget e)))))
            (setq it (mto-item-recalc it))
            (setq db (mto-db-merge-item db it))
            (setq added (1+ added)))
          nil)))
    (setq i (1+ i)))
  (list (cons 'DB db) (cons 'ADDED added) (cons 'UNIT unit)))

;; Quet theo loai + layer (tien ich)
(defun mto-geo-handles (kinds layers / filter ss)
  (setq filter (mto-sel-build-filter kinds layers))
  (setq ss (if filter (ssget "_X" filter) (ssget "_X")))
  (mto-sel-ss->handles ss))

;; ------------------------------------------------------------
;; 4. COMMAND
;; ------------------------------------------------------------

(defun c:MTOGEO ( / kinds layers filter ss res db unit uw)
  (mto-ui-start "MTOGEO" "Do chieu dai cap / ong / tray")

  (setq unit (mto-geo-current-unit))
  (if (= unit "?")
    (princ "\nCANH BAO: ban ve khong khai bao don vi (INSUNITS=0).")
    (princ (strcat "\nDon vi ban ve (INSUNITS): " unit)))

  ;; TU PHAT HIEN DON VI THAT + CANH BAO neu mau thuan (tranh sai 25.4 lan)
  (setq uw (mto-geo-warn-unit))

  (setq kinds (mto-sel-normalize-list
                (getstring T "\nLoai [LINE,LWPOLYLINE,POLYLINE,ARC,CIRCLE] <LINE,LWPOLYLINE>: ")))
  (if (null kinds) (setq kinds '("LINE" "LWPOLYLINE")))

  (setq layers (mto-sel-normalize-list
                 (getstring T "\nLayer (wildcard *, Enter = tat ca): ")))

  (setq filter (mto-sel-build-filter kinds layers))
  (setq ss (if filter (ssget filter) (ssget)))

  (if (null ss)
    (princ "\nKhong chon duoc doi tuong nao.")
    (progn
      (setq res (mto-geo-scan-ss ss (mto-db-load)))
      (setq db  (cdr (assoc 'DB res)))
      (mto-db-save db)
      (princ (strcat "\nDa xu ly " (itoa (cdr (assoc 'ADDED res))) " doi tuong."))
      (princ (strcat "\nDon vi ghi vao ket qua: " (cdr (assoc 'UNIT res))))
      (princ (strcat "\nTong chieu dai: "
                     (mto-num->str (mto-db-total-length db)) " "
                     (cdr (assoc 'UNIT res))))
      (princ (strcat "\nDB co " (itoa (mto-db-count db)) " dong."))
      ;; Nhac lai canh bao don vi sau khi do (neu co) - de nguoi dung khong bo qua
      (if (cdr (assoc 'WARN uw))
        (princ "\n>>> XEM CANH BAO DON VI o dau ket qua truoc khi dung so lieu!"))))
  (princ))

(princ "\nmto-geometry.lsp loaded.")
(princ)
