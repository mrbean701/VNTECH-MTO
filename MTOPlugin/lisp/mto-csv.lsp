;;; ============================================================
;;; mto-csv.lsp -- MTO: xuat CSV bang AutoLISP (TASK-007)
;;;
;;; Muc tieu: xuat ket qua ra CSV bang (open ...) / (write-line ...) / (close ...)
;;; KHONG phu thuoc Excel.
;;;
;;; Logic thuan (testable headless):
;;;   mto-csv-escape        -- escape dau phay / ngoac kep
;;;   mto-csv-header        -- dong tieu de
;;;   mto-csv-row           -- mot dong du lieu
;;;   mto-csv-lines         -- header + tat ca dong
;;;   mto-csv-write         -- ghi file
;;;   mto-csv-default-name  -- ten file mac dinh
;;;
;;; Command: MTOCSV
;;; ============================================================

(vl-load-com)

(setq *MTO-CSV-COLUMNS*
  '("Category" "Type" "Name" "Spec" "Description" "Layer"
    "AutoQty" "ManualQty" "FinalQty" "Length" "Unit"
    "Prefix" "SourceType" "Handles" "Notes"))

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

;; Escape theo RFC4180: boc trong "" va nhan doi " ben trong
(defun mto-csv-escape (s / out)
  (setq out (if s (vl-princ-to-string s) ""))
  ;; bo ky tu xuong dong (CSV 1 dong)
  ;; LUU Y: literal "\n" trong AutoLISP sinh CR+LF => phai xu ly ca cap CRLF
  (setq out (vl-string-subst " " "\r\n" out))
  (setq out (vl-string-translate "\r\n" "  " out))
  (if (or (vl-string-search "," out)
          (vl-string-search "\"" out)
          (vl-string-search ";" out))
    (strcat "\"" (vl-string-subst "\"\"" "\"" out) "\"")
    out))

(defun mto-csv-header ()
  (mto-str-join *MTO-CSV-COLUMNS* ","))

(defun mto-csv-row (it / cells)
  (setq cells
    (list
      (mto-csv-escape (mto-item-get it 'CATEGORY))
      (mto-csv-escape (mto-item-get it 'TYPE))
      (mto-csv-escape (mto-item-get it 'NAME))
      (mto-csv-escape (mto-item-get it 'SPEC))
      (mto-csv-escape (mto-item-get it 'DESCRIPTION))
      (mto-csv-escape (mto-item-get it 'LAYER))
      (mto-num->str (mto-item-get it 'AUTOQTY))
      (mto-num->str (mto-item-get it 'MANQTY))
      (mto-num->str (mto-item-get it 'NETQTY))
      (mto-num->str (mto-item-get it 'LENGTH))
      (mto-csv-escape (mto-item-get it 'UNIT))
      (mto-csv-escape (mto-item-get it 'PREFIX))
      (mto-csv-escape (mto-item-get it 'SOURCETYPE))
      (mto-csv-escape
        (mto-str-join (mto-item-get it 'HANDLES) "|"))
      (mto-csv-escape (mto-item-get it 'NOTES))))
  (mto-str-join cells ","))

(defun mto-csv-lines (db / out)
  (setq out (list (mto-csv-header)))
  (foreach it (mto-db-sort db)
    (setq out (append out (list (mto-csv-row it)))))
  out)

;; Ghi file CSV. Tra ve T neu thanh cong.
(defun mto-csv-write (db path / f lines)
  (setq f (open path "w"))
  (if (null f)
    (progn (princ (strcat "\nKhong mo duoc file: " path)) nil)
    (progn
      (foreach line (mto-csv-lines db)
        (write-line line f))
      (close f)
      t)))

;; Ten file mac dinh: <DWGNAME>_MTO_<YYYYMMDD_HHMMSS>.csv
(defun mto-csv-default-name ( / dwg cd datePart timePart stamp n)
  (setq dwg (getvar "DWGNAME"))
  (if (or (null dwg) (= dwg "")) (setq dwg "drawing"))
  ;; bo duoi .dwg
  ;; LUU Y: (strcase s) tra ve CHU HOA, nen phai so sanh khong phan biet
  ;; hoa/thuong -- dung (strcase s T) de ha ve chu thuong.
  (setq n (strlen dwg))
  (if (and (> n 4)
           (= (strcase (substr dwg (- n 3))) (strcase ".dwg")))
    (setq dwg (substr dwg 1 (- n 4))))
  ;; thay ky tu khong hop le (src va dst PHAI cung do dai)
  (setq dwg (vl-string-translate " /\\:*?\"<>|" "__________" dwg))

  (setq cd (getvar "CDATE"))              ; vd 20260918.153045
  (setq datePart (itoa (fix cd)))
  (setq timePart (itoa (fix (* (- cd (fix cd)) 1000000.0))))
  ;; dam bao 6 chu so
  (while (< (strlen timePart) 6) (setq timePart (strcat "0" timePart)))
  (setq stamp (strcat datePart "_" timePart))

  (strcat dwg "_MTO_" stamp ".csv"))

;; ------------------------------------------------------------
;; 2. COMMAND
;; ------------------------------------------------------------

(defun c:MTOCSV ( / db path all defName)
  (mto-ui-start "MTOCSV" "Xuat ket qua ra file CSV")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq defName (mto-csv-default-name))
      (setq all (getstring T (strcat "\nXuat tat ca? [Y/N] <Y>: ")))
      (if (or (null all) (= all "") (= (mto-str-up all) "Y"))
        (setq path (getstring T (strcat "\nDuong dan file CSV <" defName ">: ")))
        (setq path (getstring T "\nDuong dan file CSV: ")))
      (if (or (null path) (= path ""))
        (setq path defName))

      (if (mto-csv-write db path)
        (progn
          (princ (strcat "\nDa xuat " (itoa (mto-db-count db)) " dong ra:"))
          (princ (strcat "\n  " path)))
        (princ "\nXuat that bai."))))
  (princ))

(princ "\nmto-csv.lsp loaded.")
(princ)
