;;; ============================================================
;;; mto-formula.lsp -- MTO: cong thuc tinh tuy chinh (TASK-013)
;;;
;;; Muc tieu: cho phep nguoi dung dinh nghia calculation don gian:
;;;     SL x he so        (so luong nhan he so)
;;;     LEN x he so       (chieu dai nhan he so)
;;;     QTY x PRICE       (khoi luong nhan don gia)
;;;     QTY + 5 / LEN - 2 (cong/tru)
;;;
;;; AN TOAN: KHONG dung eval/read tren chuoi nguoi dung.
;;; Chi chap nhan DUNG dang: <toan-hang> <phep-toan> <toan-hang>.
;;;
;;; Phai luu: Formula / Input / Result / Explanation
;;; Vi du:  "Length x Factor" | 120 x 1.05 | = 126
;;;
;;; Logic thuan (testable headless):
;;;   mto-formula-op-normalize      -- 'x'/'X'/* -> "*" ; ':' -> "/"
;;;   mto-formula-parse             -- chuoi -> (a op b) hoac nil
;;;   mto-formula-lookup            -- token -> so (literal hoac bien)
;;;   mto-formula-eval              -- (a op b) + vars -> so hoac nil
;;;   mto-formula-run               -- chuoi + vars -> (RESULT . EXPLANATION)
;;;   mto-formula-vars-of-item      -- item -> ((SL . n) (LEN . n) (QTY . n) (PRICE . n))
;;;   mto-formula-apply-item        -- tinh va luu vao item
;;;
;;; Command: MTOFORMULA
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. PHEP TOAN
;; ------------------------------------------------------------

;; Chuan hoa ky hieu phep toan
(defun mto-formula-op-normalize (tok / t2)
  (setq t2 (mto-str-up tok))
  (cond
    ((member t2 '("X" "*" "×")) "*")
    ((member t2 '(":" "/" "÷")) "/")
    ((= t2 "+") "+")
    ((= t2 "-") "-")
    (t nil)))

(defun mto-formula-op-p (tok)
  (if (mto-formula-op-normalize tok) t nil))

;; ------------------------------------------------------------
;; 2. PARSE (khong dung eval)
;; ------------------------------------------------------------

;; "LEN * 1.05" -> ("LEN" "*" 1.05)
;; "SL x 2"     -> ("SL" "*" 2)
;; Tra ve list 3 phan tu, hoac nil neu sai dinh dang.
(defun mto-formula-parse (s / toks n i op opIdx out a b opn)
  (setq toks (mto-str-split (mto-str-trim (if s s "")) " "))
  ;; loai token rong
  (setq out '())
  (foreach tk toks
    (if (/= (mto-str-trim tk) "") (setq out (append out (list (mto-str-trim tk))))))
  (setq toks out)
  (setq n (length toks))

  (if (/= n 3) nil
    (progn
      (setq a (nth 0 toks))
      (setq op (nth 1 toks))
      (setq b (nth 2 toks))
      (setq opn (mto-formula-op-normalize op))
      (if (null opn) nil
        (if (or (= a "") (= b "")) nil
          (list a opn b))))))

;; ------------------------------------------------------------
;; 3. TRA GIA TRI
;; ------------------------------------------------------------

;; Token -> so. Uu tien so literal; neu khong thi tra trong vars (alist).
;; LUU Y: AutoLISP KHONG co `let` (loi "no function definition") -> dung setq.
(defun mto-formula-lookup (tok vars / num pair key val)
  (setq num (mto-str->num tok nil))
  (if num num
    (progn
      (setq key (mto-str-up tok))
      (setq pair (assoc key vars))
      (if pair
        (progn
          (setq val (cdr pair))
          (if (= (type val) 'STR) (mto-str->num val nil) val))
        nil))))

;; ------------------------------------------------------------
;; 4. TINH
;; ------------------------------------------------------------

;; (a op b) + vars -> so hoac nil
(defun mto-formula-eval (parsed vars / a op b va vb res)
  (if (null parsed) nil
    (progn
      (setq a  (nth 0 parsed))
      (setq op (nth 1 parsed))
      (setq b  (nth 2 parsed))
      (setq va (mto-formula-lookup a vars))
      (setq vb (mto-formula-lookup b vars))
      (if (or (null va) (null vb)) nil
        (progn
          (setq res
            (cond
              ((= op "*") (* (float va) (float vb)))
              ((= op "+") (+ (float va) (float vb)))
              ((= op "-") (- (float va) (float vb)))
              ((= op "/")
               (if (= (float vb) 0.0) nil (/ (float va) (float vb))))
              (t nil)))
          res)))))

;; Chuoi cong thuc + vars -> (RESULT . EXPLANATION) hoac nil
(defun mto-formula-run (expr vars / parsed res expl)
  (setq parsed (mto-formula-parse expr))
  (if (null parsed) nil
    (progn
      (setq res (mto-formula-eval parsed vars))
      (if (null res) nil
        (progn
          (setq expl (strcat (nth 0 parsed) " " (nth 1 parsed) " " (nth 2 parsed)
                             " = " (mto-num->str res)))
          (cons res expl))))))

;; ------------------------------------------------------------
;; 5. GAN VOI ITEM
;; ------------------------------------------------------------

;; Bien cua mot item
(defun mto-formula-vars-of-item (it)
  (list
    (cons "SL"    (mto-item-get it 'QTY))
    (cons "QTY"   (mto-item-get it 'QTY))
    (cons "NETQTY" (mto-item-get it 'NETQTY))
    (cons "LEN"   (mto-item-get it 'LENGTH))
    (cons "DED"   (mto-item-get it 'DEDUCTION))
    (cons "PRICE" 0.0)))

;; Tinh cong thuc cho item va luu FORMULA / FORMULA-VALUE / FORMULA-EXPLAIN.
;; Neu apply-net = T thi ghi ket qua vao NETQTY.
;; Tra ve (item . result) hoac nil
(defun mto-formula-apply-item (it expr apply-net / vars run res expl it2)
  (setq vars (mto-formula-vars-of-item it))
  (setq run (mto-formula-run expr vars))
  (if (null run) nil
    (progn
      (setq res  (car run))
      (setq expl (cdr run))
      (setq it2 (mto-item-set it 'FORMULA expr))
      (setq it2 (mto-item-set it2 'FORMULA-VALUE res))
      (setq it2 (mto-item-set it2 'FORMULA-EXPLAIN expl))
      (if apply-net
        (setq it2 (mto-item-set it2 'NETQTY res)))
      (cons it2 res))))

;; Ap dung cho ca DB. `rules` = alist ((TYPE . expr) ...) hoac ((NAME . expr) ...)
;; Tra ve (DB . APPLIED-COUNT . FAILED-COUNT)
(defun mto-formula-apply-db (db rules apply-net / applied failed it expr key hit res)
  (setq applied 0 failed 0)
  (foreach it db
    (setq expr nil)
    ;; uu tien NAME, roi TYPE
    (setq key (mto-item-get it 'NAME))
    (setq hit (assoc key rules))
    (if (null hit)
      (progn
        (setq key (mto-item-get it 'TYPE))
        (setq hit (assoc key rules))))
    (if hit
      (progn
        (setq expr (cdr hit))
        (setq res (mto-formula-apply-item it expr apply-net))
        (if res
          (setq applied (1+ applied))
          (setq failed (1+ failed))))))
  (list (cons 'DB db) (cons 'APPLIED applied) (cons 'FAILED failed)))

;; ------------------------------------------------------------
;; 6. COMMAND
;; ------------------------------------------------------------

(defun c:MTOFORMULA ( / db n pick it expr run res)
  (mto-ui-start "MTOFORMULA" "Cong thuc tinh tuy chinh")
  (princ "\nCu phap: <toan-hang> <phep-toan> <toan-hang>")
  (princ "\nVi du  : LEN * 1.05   |   SL x 2   |   QTY + 5   |   LEN / 2")
  (princ "\nBien   : SL, QTY, NETQTY, LEN (chieu dai), DED, PRICE")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq n (getint "\nChon STT dong can ap dung cong thuc: "))
      (if n
        (progn
          (setq it (mto-find-by-index db n))
          (if (null it)
            (princ "\nSTT khong hop le.")
            (progn
              (princ (strcat "\nDong: " (mto-item-get it 'NAME)
                             " | QTY=" (mto-num->str (mto-item-get it 'QTY))
                             " | LEN=" (mto-num->str (mto-item-get it 'LENGTH))))
              (setq expr (getstring T "\nCong thuc: "))
              (if (or (null expr) (= (mto-str-trim expr) ""))
                (princ "\nDa huy.")
                (progn
                  (setq run (mto-formula-run expr (mto-formula-vars-of-item it)))
                  (if (null run)
                    (princ "\nCong thuc SAI dinh dang hoac thieu bien. (dung: <a> <op> <b>)")
                    (progn
                      (setq res (car run))
                      (princ (strcat "\nGiai thich: " (cdr run)))
                      (setq it (mto-formula-apply-item it expr nil))
                      (setq db (mto-db-merge-replace db (car it)))
                      (mto-db-save db)
                      (princ (strcat "\nDa luu cong thuc. Ket qua = " (mto-num->str res))))))))))
        (princ "\nDa huy."))))
  (princ))

(princ "\nmto-formula.lsp loaded.")
(princ)
