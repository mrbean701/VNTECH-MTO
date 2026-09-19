;;; ============================================================
;;; mto-core.lsp -- MTO LISP toolset: data model + utilities
;;; De tai: R&D-CAD-QTO-01
;;; Kien truc: LISP-first
;;;
;;; Quy uoc:
;;;  - Item  = association list (alist) voi cac khoa symbol.
;;;  - DB    = danh sach cac item (list of alists).
;;;  - Key gom nhom = CATEGORY|TYPE|NAME|SPEC|UNIT
;;;  - Khong dung tieng Viet co dau trong code (tranh loi encoding).
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. HANG SO NGHIEP VU
;; ------------------------------------------------------------

(setq *MTO-CAT-ELEC*  "Electrical")
(setq *MTO-CAT-PLUMB* "Plumbing")
(setq *MTO-CAT-ELV*   "ELV")
(setq *MTO-CAT-OTHER* "Other")

;; SourceType
(setq *MTO-SRC-BLOCK* "BLOCK")
(setq *MTO-SRC-TEXT*  "TEXT")
(setq *MTO-SRC-GEOM*  "GEOMETRY")
(setq *MTO-SRC-MAN*   "MANUAL")

;; Don vi mac dinh
(setq *MTO-UNIT-PCS* "cai")
(setq *MTO-UNIT-M*   "m")

;; ------------------------------------------------------------
;; 2. TIEN ICH CHUOI
;; ------------------------------------------------------------

;; Cat khoang trang dau/cuoi
(defun mto-str-trim (s)
  (if (null s) ""
    (vl-string-trim " \t\r\n" s)))

;; In hoa (khong doi dau tieng Viet)
;; LUU Y: (strcase s T) = LOWERCASE trong AutoLISP; bo tham so = UPPERCASE.
(defun mto-str-up (s)
  (if (null s) "" (strcase (mto-str-trim s))))

;; Lay n ky tu dau
(defun mto-str-left (s n)
  (if (or (null s) (< n 1)) ""
    (substr s 1 (if (> n (strlen s)) (strlen s) n))))

;; Token dau tien (tach theo khoang trang)
(defun mto-str-first-token (s / p t2)
  (setq t2 (mto-str-trim s))
  (if (= t2 "") ""
    (progn
      (setq p (vl-string-search " " t2))
      (if p (substr t2 1 p) t2))))

;; Tach chuoi theo delimiter -> list
(defun mto-str-split (str delim / pos lst start dlen)
  (if (or (null str) (= str "") (null delim) (= delim "")) '()
    (progn
      (setq lst '() start 0 dlen (strlen delim))
      (while (setq pos (vl-string-search delim str start))
        (setq lst (cons (substr str (1+ start) (- pos start)) lst))
        (setq start (+ pos dlen)))
      (setq lst (cons (substr str (1+ start)) lst))
      (reverse lst))))

;; Noi list chuoi bang delimiter
(defun mto-str-join (lst delim / out first)
  (setq out "" first t)
  (foreach s lst
    (setq out (strcat out (if first "" delim) (if s s "")))
    (setq first nil))
  out)

;; So -> chuoi gon (bo trailing zero)
(defun mto-num->str (x / s)
  (if (null x) (setq x 0.0))
  (if (= (type x) 'INT)
    (itoa x)
    (progn
      (setq s (rtos (float x) 2 4))
      ;; Cat cac ky tu '0' vo nghia o cuoi (ke ca truong hop "0.0000")
      (while (and (> (strlen s) 0)
                  (= (substr s (strlen s) 1) "0"))
        (setq s (substr s 1 (1- (strlen s)))))
      ;; Neu con lai dau '.' o cuoi thi cat luon
      (if (and (> (strlen s) 0)
               (= (substr s (strlen s) 1) "."))
        (setq s (substr s 1 (1- (strlen s)))))
      (if (= s "") "0" s))))

;; Chuoi -> so (an toan, tra ve def neu loi)
(defun mto-str->num (s def / v)
  (if (null s) def
    (progn
      (setq s (mto-str-trim s))
      (if (= s "") def
        (progn
          (setq v (distof s 2))
          (if v v def))))))

;; ------------------------------------------------------------
;; 3. DATA MODEL -- ITEM
;; ------------------------------------------------------------
;; Khoa bat buoc cua mot item:
;;   CATEGORY TYPE NAME SPEC DESCRIPTION LAYER
;;   QTY AUTOQTY MANQTY DEDUCTION NETQTY
;;   LENGTH UNIT PREFIX HANDLES SOURCETYPE SOURCEOBJECT NOTES
;;   FLOOR AREA ZONE FORMULA LABEL1..LABEL3
;; ------------------------------------------------------------

(defun mto-item-new (category type name / it)
  (setq it (list
    (cons 'CATEGORY      (if category category ""))
    (cons 'TYPE          (if type type ""))
    (cons 'NAME          (if name name ""))
    (cons 'SPEC          "")
    (cons 'DESCRIPTION   "")
    (cons 'LAYER         "")
    (cons 'QTY           0.0)
    (cons 'AUTOQTY       0.0)
    (cons 'MANQTY        0.0)
    (cons 'DEDUCTION     0.0)
    (cons 'NETQTY        0.0)
    (cons 'LENGTH        0.0)
    (cons 'UNIT          "")
    (cons 'PREFIX        "")
    (cons 'HANDLES       '())
    (cons 'SOURCETYPE    "")
    (cons 'SOURCEOBJECT  "")
    (cons 'NOTES         "")
    (cons 'FLOOR         "")
    (cons 'AREA          "")
    (cons 'ZONE          "")
    (cons 'FORMULA       "")
    (cons 'LABEL1        "")
    (cons 'LABEL2        "")
    (cons 'LABEL3        "")))
  it)

;; Lay gia tri theo khoa
(defun mto-item-get (it key)
  (cdr (assoc key it)))

;; Dat gia tri theo khoa (tao moi neu chua co)
(defun mto-item-set (it key val / pair)
  (setq pair (assoc key it))
  (if pair
    (subst (cons key val) pair it)
    (append it (list (cons key val)))))

;; Them handle (khong trung)
(defun mto-item-add-handle (it h / hs)
  (if (or (null h) (= h "")) it
    (progn
      (setq hs (mto-item-get it 'HANDLES))
      (if (member h hs) it
        (mto-item-set it 'HANDLES (append hs (list h)))))))

;; Cong so luong tu dong
(defun mto-item-add-auto (it q)
  (mto-item-set it 'AUTOQTY (+ (mto-item-get it 'AUTOQTY) (float q))))

;; Cong chieu dai
(defun mto-item-add-length (it len)
  (mto-item-set it 'LENGTH (+ (mto-item-get it 'LENGTH) (float len))))

;; Tinh QTY = AUTOQTY + MANQTY sau dieu chinh
(defun mto-item-recalc (it / auto man ded)
  (setq auto (mto-item-get it 'AUTOQTY))
  (setq man  (mto-item-get it 'MANQTY))
  (setq ded  (mto-item-get it 'DEDUCTION))
  (setq it (mto-item-set it 'QTY (+ auto man)))
  (mto-item-set it 'NETQTY (- (+ auto man) ded)))

;; Key gom nhom
(defun mto-item-key (it)
  (strcat (mto-item-get it 'CATEGORY) "|"
          (mto-item-get it 'TYPE)     "|"
          (mto-item-get it 'NAME)     "|"
          (mto-item-get it 'SPEC)     "|"
          (mto-item-get it 'UNIT)))

;; ------------------------------------------------------------
;; 4. DATA MODEL -- DATABASE (list of items)
;; ------------------------------------------------------------

(defun mto-db-new () '())

(defun mto-db-count (db) (length db))

(defun mto-db-empty-p (db) (null db))

;; Gop mot item vao db theo key (cong don so lieu + handle)
(defun mto-db-merge-item (db it / key found out x)
  (setq key (mto-item-key it))
  (setq found nil out '())
  (foreach x db
    (if (and (not found) (= (mto-item-key x) key))
      (progn
        (setq x (mto-item-set x 'AUTOQTY (+ (mto-item-get x 'AUTOQTY) (mto-item-get it 'AUTOQTY))))
        (setq x (mto-item-set x 'MANQTY  (+ (mto-item-get x 'MANQTY)  (mto-item-get it 'MANQTY))))
        (setq x (mto-item-set x 'LENGTH  (+ (mto-item-get x 'LENGTH)  (mto-item-get it 'LENGTH))))
        (setq x (mto-item-set x 'DEDUCTION (+ (mto-item-get x 'DEDUCTION) (mto-item-get it 'DEDUCTION))))
        (setq x (mto-item-set x 'HANDLES (append (mto-item-get x 'HANDLES)
                                                 (mto-item-get it 'HANDLES))))
        (setq x (mto-item-recalc x))
        (setq found t))
      nil)
    (setq out (append out (list x))))
  (if found out
    (append out (list (mto-item-recalc it)))))

;; Sap xep theo CATEGORY -> TYPE -> NAME
;; LUU Y: so sanh KHONG phan biet hoa/thuong (strcase) de thu tu tu nhien:
;; neu so sanh ASCII thuan, "ELV" (L hoa = 76) se dung TRUOC "Electrical"
;; (l thuong = 108) -- gay kho doc tren bang/bao cao.
(defun mto-db-sort (db)
  (vl-sort db
    '(lambda (a b / ca cb ta tb na nb)
       (setq ca (mto-str-up (mto-item-get a 'CATEGORY))
             cb (mto-str-up (mto-item-get b 'CATEGORY)))
       (if (= ca cb)
         (progn
           (setq ta (mto-str-up (mto-item-get a 'TYPE))
                 tb (mto-str-up (mto-item-get b 'TYPE)))
           (if (= ta tb)
             (progn
               (setq na (mto-str-up (mto-item-get a 'NAME))
                     nb (mto-str-up (mto-item-get b 'NAME)))
               (< na nb))
             (< ta tb)))
         (< ca cb)))))

;; Tong so luong (NETQTY)
(defun mto-db-total-net (db / s)
  (setq s 0.0)
  (foreach it db (setq s (+ s (mto-item-get it 'NETQTY))))
  s)

;; Tong chieu dai
(defun mto-db-total-length (db / s)
  (setq s 0.0)
  (foreach it db (setq s (+ s (mto-item-get it 'LENGTH))))
  s)

;; Loc theo mot khoa = gia tri
(defun mto-db-filter (db key val / out)
  (setq out '())
  (foreach it db
    (if (equal (mto-item-get it key) val)
      (setq out (append out (list it)))))
  out)

;; Tim item chua handle
(defun mto-db-find-by-handle (db h / res)
  (setq res nil)
  (foreach it db
    (if (and (null res) (member h (mto-item-get it 'HANDLES)))
      (setq res it)))
  res)

;; ------------------------------------------------------------
;; 5. PHIEN LAM VIEC (global state)
;; ------------------------------------------------------------

(if (null *MTO-DATA*) (setq *MTO-DATA* '()))
(if (null *MTO-DB*)   (setq *MTO-DB* '()))

(defun mto-db-save (db) (setq *MTO-DB* db) db)
(defun mto-db-load () (if *MTO-DB* *MTO-DB* '()))
(defun mto-db-clear () (setq *MTO-DB* '()) '())

;; ------------------------------------------------------------
;; 6. KHOI TAO
;; ------------------------------------------------------------

;; ------------------------------------------------------------
;; 5b. TIEN ICH BO SUNG (dung cho module cap nhat + module khac)
;; ------------------------------------------------------------

;; Chuoi -> chu THUONG. (strcase s T): tham so 2 la downcase-p.
(defun mto-str-down (s) (if s (strcase s T) ""))

;; Chuoi chi gom CHU SO? (dung cho parse semver)
(defun mto-str-num-p (s / i ch ok)
  (if (or (null s) (= s "")) nil
    (progn
      (setq ok t) (setq i 1)
      (while (and ok (<= i (strlen s)))
        (setq ch (ascii (substr s i 1)))
        (if (or (< ch 48) (> ch 57)) (setq ok nil))
        (setq i (1+ i)))
      ok)))

;; Chuoi s bat dau bang prefix? (khong phan biet hoa/thuong)
(defun mto-str-prefix-p (s prefix)
  (if (or (null s) (null prefix)) nil
    (= (mto-str-down (substr s 1 (strlen prefix))) (mto-str-down prefix))))

;; Tim chuoi con (khong phan biet hoa/thuong). Tra vi tri 0-based hoac nil.
(defun mto-str-search (s sub)
  (if (or (null s) (null sub)) nil
    (vl-string-search (mto-str-down sub) (mto-str-down s))))

;; Thay phan tu thu n (0-based) trong list bang val -> tra list MOI
(defun mto-subst-nth (n val lst / i out)
  (setq i 0)
  (setq out '())
  (foreach x lst
    (if (= i n)
      (setq out (append out (list val)))
      (setq out (append out (list x))))
    (setq i (1+ i)))
  out)

(princ "\nmto-core.lsp loaded.")
(princ)
