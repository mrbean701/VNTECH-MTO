;;; ============================================================
;;; mto-subtotal.lsp -- MTO: subtotal / grouping / deduction (TASK-014)
;;;
;;; Muc tieu: ho tro
;;;   - subtotal  : tong theo nhom (Category / Type / Floor / Layer ...)
;;;   - grouping  : gom nhom du lieu
;;;   - deduction : khau tru (vi du: tru doan khong thi cong)
;;;
;;; Cong thuc:
;;;   NETQTY  = QTY - DEDUCTION        (da co o item)
;;;   Subtotal(nhom) = SUM(NETQTY) va SUM(LENGTH)
;;;   GrandTotal     = SUM tat ca
;;;
;;; Thiet ke GENERIC: dung cho Electrical / Plumbing / ELV deu duoc
;;; (khoa gom nhom la THAM SO, khong hard-code).
;;;
;;; Logic thuan (testable headless):
;;;   mto-sub-set-deduction     -- dat deduction cho item
;;;   mto-sub-add-deduction     -- cong don deduction
;;;   mto-sub-group             -- gom nhom theo khoa -> alist
;;;   mto-sub-summary           -- bao cao subtotal + grand total
;;;   mto-sub-total-of          -- tong cua mot nhom
;;;   mto-sub-deduction-of      -- tong deduction cua nhom
;;;
;;; Command: MTOSUB, MTODED
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. DEDUCTION
;; ------------------------------------------------------------

;; Dat deduction (khau tru) cho item, tra ve item da tinh lai
(defun mto-sub-set-deduction (it val)
  (mto-item-recalc (mto-item-set it 'DEDUCTION (float val))))

;; Cong don deduction
(defun mto-sub-add-deduction (it delta)
  (mto-item-recalc
    (mto-item-set it 'DEDUCTION (+ (mto-item-get it 'DEDUCTION) (float delta)))))

;; Deduction khong duoc am va khong vuot qua QTY (khong de NETQTY < 0)
(defun mto-sub-clamp-deduction (it / qty ded)
  (setq qty (mto-item-get it 'QTY))
  (setq ded (mto-item-get it 'DEDUCTION))
  (if (< ded 0.0) (setq ded 0.0))
  (if (> ded qty) (setq ded qty))
  (mto-item-recalc (mto-item-set it 'DEDUCTION ded)))

;; ------------------------------------------------------------
;; 2. GROUPING / SUBTOTAL (generic theo khoa)
;; ------------------------------------------------------------

;; Gom nhom theo `key`. Tra ve alist:
;;   ((value (QTY . n) (LEN . n) (DED . n) (NET . n) (COUNT . n)) ...)
(defun mto-sub-group (db key / out entry grp v)
  (setq out '())
  (foreach it db
    (setq v (mto-item-get it key))
    (setq entry (assoc v out))
    (if entry
      (progn
        (setq grp (cdr entry))
        (setq grp (subst (cons 'QTY (+ (cdr (assoc 'QTY grp)) (mto-item-get it 'QTY))) (assoc 'QTY grp) grp))
        (setq grp (subst (cons 'LEN (+ (cdr (assoc 'LEN grp)) (mto-item-get it 'LENGTH))) (assoc 'LEN grp) grp))
        (setq grp (subst (cons 'DED (+ (cdr (assoc 'DED grp)) (mto-item-get it 'DEDUCTION))) (assoc 'DED grp) grp))
        (setq grp (subst (cons 'NET (+ (cdr (assoc 'NET grp)) (mto-item-get it 'NETQTY))) (assoc 'NET grp) grp))
        (setq grp (subst (cons 'COUNT (1+ (cdr (assoc 'COUNT grp)))) (assoc 'COUNT grp) grp))
        (setq out (subst (cons v grp) entry out)))
      (setq out (append out (list
        (cons v (list (cons 'QTY (mto-item-get it 'QTY))
                      (cons 'LEN (mto-item-get it 'LENGTH))
                      (cons 'DED (mto-item-get it 'DEDUCTION))
                      (cons 'NET (mto-item-get it 'NETQTY))
                      (cons 'COUNT 1))))))))
  out)

;; Tong cua mot nhom theo truong (QTY/LEN/DED/NET)
(defun mto-sub-total-of (grp field)
  (cdr (assoc field (cdr grp))))

;; Tong deduction cua nhom
(defun mto-sub-deduction-of (grp)
  (cdr (assoc 'DED (cdr grp))))

;; Tong NETQTY cua nhom
(defun mto-sub-net-of (grp)
  (cdr (assoc 'NET (cdr grp))))

;; Bao cao subtotal theo khoa + grand total
;; Tra ve: (GROUPS . (GRAND . alist))
(defun mto-sub-summary (db key / groups grand)
  (setq groups (mto-sub-group db key))
  (setq grand (list (cons 'QTY (mto-db-total-net db))
                    (cons 'LEN (mto-db-total-length db))
                    (cons 'COUNT (mto-db-count db))))
  (cons groups grand))

;; ------------------------------------------------------------
;; 3. AP DUNG DEDUCTION HANG LOAT
;; ------------------------------------------------------------

;; Ap dung deduction theo rules: alist ((KEY-VALUE . amount) ...)
;; Tra ve (DB-MOI . APPLIED)
;; LUU Y: item la immutable (moi thao tac tra ve item MOI) nen phai GAN LAI
;; ket qua vao db, khong the sua tai cho.
(defun mto-sub-apply-deductions (db key rules / applied it hit v newit out)
  (setq applied 0 out '())
  (foreach it db
    (setq v (mto-item-get it key))
    (setq hit (assoc v rules))
    (if hit
      (progn
        (setq newit (mto-sub-add-deduction it (cdr hit)))
        (setq newit (mto-sub-clamp-deduction newit))
        (setq out (append out (list newit)))
        (setq applied (1+ applied)))
      (setq out (append out (list it)))))
  (cons out applied))

;; ------------------------------------------------------------
;; 4. COMMAND
;; ------------------------------------------------------------

(defun c:MTOSUB ( / db key groups summary g)
  (mto-ui-start "MTOSUB" "Subtotal / gom nhom theo khoa")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq key (mto-str-up (mto-str-trim
                 (getstring T "\nGom nhom theo [CATEGORY/TYPE/LAYER/FLOOR] <CATEGORY>: "))))
      (if (= key "") (setq key "CATEGORY"))

      (setq groups (mto-sub-group db key))
      (princ (strcat "\n--- SUBTOTAL theo " key " ---"))
      (princ "\nNHOM | SL | KHAU TRU | NET | DAI")
      (foreach g groups
        (princ (strcat "\n" (car g)
                       " | QTY=" (mto-num->str (mto-sub-total-of g 'QTY))
                       " | DED=" (mto-num->str (mto-sub-deduction-of g))
                       " | NET=" (mto-num->str (mto-sub-net-of g))
                       " | LEN=" (mto-num->str (mto-sub-total-of g 'LEN)))))
      (princ (strcat "\n\nGRAND TOTAL: NET=" (mto-num->str (mto-db-total-net db))
                     " | LEN=" (mto-num->str (mto-db-total-length db))
                     " | dong=" (itoa (mto-db-count db))))))
  (princ))

(defun c:MTODED ( / db n it amount pick)
  (mto-ui-start "MTODED" "Khau tru khoi luong")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong.")
    (progn
      (princ "\nCac dong:")
      (foreach p (mto-find-build-index db)
        (princ (strcat "\n  " (itoa (car p)) ". "
                       (mto-item-get (cdr p) 'NAME)
                       " | QTY=" (mto-num->str (mto-item-get (cdr p) 'QTY))
                       " | DED=" (mto-num->str (mto-item-get (cdr p) 'DEDUCTION))
                       " | NET=" (mto-num->str (mto-item-get (cdr p) 'NETQTY)))))
      (setq n (getint "\nChon STT can khau tru: "))
      (if n
        (progn
          (setq it (mto-find-by-index db n))
          (if (null it)
            (princ "\nSTT khong hop le.")
            (progn
              (setq amount (getreal "\nSo luong khau tru (co the am de hoan lai): "))
              (if amount
                (progn
                  (setq it (mto-sub-add-deduction it amount))
                  (setq it (mto-sub-clamp-deduction it))
                  (setq db (mto-db-merge-replace db it))
                  (mto-db-save db)
                  (princ (strcat "\nDa cap nhat: QTY=" (mto-num->str (mto-item-get it 'QTY))
                                 " DED=" (mto-num->str (mto-item-get it 'DEDUCTION))
                                 " NET=" (mto-num->str (mto-item-get it 'NETQTY)))))
                (princ "\nDa huy.")))))
        (princ "\nDa huy."))))
  (princ))

(princ "\nmto-subtotal.lsp loaded.")
(princ)
