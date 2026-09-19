;;; ============================================================
;;; mto-result.lsp -- MTO: danh sach ket qua dang BANG (TASK-006)
;;;
;;; Muc tieu: hien thi danh sach ket qua (khong chi mot dong tong ket),
;;; lam input cho AutoCAD Table (TASK-009) va CSV (TASK-007).
;;;
;;; Cot: CATEGORY | TYPE | NAME | QTY | LENGTH | UNIT
;;;
;;; Logic thuan (testable headless):
;;;   mto-res-spaces   -- chuoi n khoang trang
;;;   mto-res-pad      -- can cot (cat neu dai hon)
;;;   mto-res-header   -- dong tieu de
;;;   mto-res-row      -- mot dong du lieu tu item
;;;   mto-res-table    -- header + tat ca dong
;;;   mto-res-stats    -- thong ke tong
;;;
;;; Command: MTOLIST
;;; ============================================================

(vl-load-com)

;; Do rong cot
(setq *MTO-RES-WIDTHS* '(14 14 32 10 12 8))

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

(defun mto-res-spaces (n / s i)
  (setq s "" i 0)
  (while (< i n) (setq s (strcat s " ")) (setq i (1+ i)))
  s)

;; Can trai, cat neu dai hon
(defun mto-res-pad (val w / s)
  (setq s (if val (mto-str-trim (vl-princ-to-string val)) ""))
  (if (> (strlen s) w)
    (substr s 1 w)
    (strcat s (mto-res-spaces (- w (strlen s))))))

(defun mto-res-header (/ ws)
  (setq ws *MTO-RES-WIDTHS*)
  (strcat
    (mto-res-pad "CATEGORY" (nth 0 ws)) " "
    (mto-res-pad "TYPE"     (nth 1 ws)) " "
    (mto-res-pad "NAME"     (nth 2 ws)) " "
    (mto-res-pad "QTY"      (nth 3 ws)) " "
    (mto-res-pad "LENGTH"   (nth 4 ws)) " "
    (mto-res-pad "UNIT"     (nth 5 ws))))

(defun mto-res-sep (/ n s i)
  (setq n 0)
  (foreach w *MTO-RES-WIDTHS* (setq n (+ n w 1)))
  (setq s "" i 0)
  (while (< i n) (setq s (strcat s "-")) (setq i (1+ i)))
  s)

(defun mto-res-row (it / ws)
  (setq ws *MTO-RES-WIDTHS*)
  (strcat
    (mto-res-pad (mto-item-get it 'CATEGORY) (nth 0 ws)) " "
    (mto-res-pad (mto-item-get it 'TYPE)     (nth 1 ws)) " "
    (mto-res-pad (mto-item-get it 'NAME)     (nth 2 ws)) " "
    (mto-res-pad (mto-num->str (mto-item-get it 'NETQTY))  (nth 3 ws)) " "
    (mto-res-pad (mto-num->str (mto-item-get it 'LENGTH))  (nth 4 ws)) " "
    (mto-res-pad (mto-item-get it 'UNIT)     (nth 5 ws))))

;; header + separator + cac dong du lieu
(defun mto-res-table (db / out)
  (setq out (list (mto-res-header) (mto-res-sep)))
  (foreach it (mto-db-sort db)
    (setq out (append out (list (mto-res-row it)))))
  out)

;; Thong ke tong
(defun mto-res-stats (db / ncats types)
  (setq types '())
  (foreach it db
    (if (not (member (mto-item-get it 'CATEGORY) types))
      (setq types (append types (list (mto-item-get it 'CATEGORY))))))
  (list
    (cons 'ROWS   (mto-db-count db))
    (cons 'QTY    (mto-db-total-net db))
    (cons 'LENGTH (mto-db-total-length db))
    (cons 'CATS   (length types))))

;; ------------------------------------------------------------
;; 2. COMMAND
;; ------------------------------------------------------------

(defun mto-res-print (db / stats)
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (foreach line (mto-res-table db)
        (princ (strcat "\n" line)))
      (setq stats (mto-res-stats db))
      (princ (strcat "\n\nTong dong      : " (itoa (cdr (assoc 'ROWS stats)))))
      (princ (strcat "\nTong khoi luong: " (mto-num->str (cdr (assoc 'QTY stats)))))
      (princ (strcat "\nTong chieu dai : " (mto-num->str (cdr (assoc 'LENGTH stats)))))
      (princ (strcat "\nSo he          : " (itoa (cdr (assoc 'CATS stats)))))))
  (princ))

(defun c:MTOLIST ( / db cat filt)
  (mto-ui-start "MTOLIST" "Bang ket qua khoi luong")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq cat (mto-str-trim (getstring T "\nLoc theo CATEGORY (Enter = tat ca): ")))
      (if (/= cat "")
        (setq filt (mto-db-filter db 'CATEGORY cat))
        (setq filt db))
      (if (null filt)
        (princ (strcat "\nKhong co dong nao thuoc he '" cat "'."))
        (mto-res-print filt))))
  (princ))

(princ "\nmto-result.lsp loaded.")
(princ)
