;;; ============================================================
;;; tableoverlap.lsp -- KIEM CHUNG BANG KHONG BI CHONG CHU
;;;
;;; Ve bang GRID voi du lieu CO NOI DUNG DAI, roi doc lai TUNG o text
;;; va kiem tra: chieu rong thuc cua chu co vuot khoi cot khong.
;;;
;;; Goi: (mto-tableoverlap "log.txt")
;;; ============================================================

(defun to-log (f s) (write-line s f) (princ (strcat "\n  " s)))

;; Chieu rong uoc tinh cua chuoi khi ve voi chieu cao h
(defun to-text-width (s h)
  (* (strlen s) h 0.62))

(defun mto-tableoverlap (out / f db rows pt layer n ss i e ed txt tx ty w h colx colw over total checked)
  (setq f (open out "w"))
  (if (null f) (progn (princ "\nKhong mo duoc log") nil)
    (progn
      (to-log f "======================================================")
      (to-log f "KIEM CHUNG BANG KHONG CHONG CHU")
      (to-log f (strcat "DWG: " (getvar "DWGNAME")))
      (to-log f "======================================================")

      (to-log f "")
      (to-log f "--- Thong so bang ---")
      (to-log f (strcat "So cot            = " (itoa (length *MTO-TABLE-COLS*))))
      (to-log f (strcat "Tong chieu rong   = " (mto-num->str (mto-table-total-width))))
      (to-log f (strcat "Chieu cao dong    = " (mto-num->str *MTO-TABLE-ROW-H*)))
      (to-log f (strcat "Chieu cao chu     = " (mto-num->str *MTO-TABLE-TXT-H*)))
      (to-log f (strcat "Le ngang trong o  = " (mto-num->str *MTO-TABLE-PAD-X*)))
      (to-log f "")
      (to-log f "Chieu rong tung cot + so ky tu toi da:")
      (setq i 0)
      (foreach c *MTO-TABLE-COLS*
        (to-log f (strcat "  [" (itoa i) "] " (car c)
                          " rong=" (mto-num->str (cdr c))
                          " -> toi da " (itoa (mto-table-max-chars (cdr c))) " ky tu"))
        (setq i (1+ i)))

      ;; ---- Tao du lieu CO NOI DUNG DAI (tinh huong gay chong chu) ----
      (to-log f "")
      (to-log f "--- Du lieu test (co noi dung DAI de thu) ---")
      (setq db (list
        (mto-item-new "Electrical" "Camera Cable" "SE.DOME CAMERA LOAI RAT DAI TEN THIET BI")
        (mto-item-new "ELV" "Cable Tray" "Camera Cable")
        (mto-item-new "Other" "Type Ten Rat Dai" "Camera Cable Rat Dai XYZ 12345")))
      (setq db (mapcar '(lambda (it) (mto-item-set it 'NETQTY 51.0)) db))
      (setq db (mapcar '(lambda (it) (mto-item-set it 'LAYER "Camera Cable Layer Dai")) db))
      (setq rows (mto-table-build-rows db))
      (to-log f (strcat "So dong bang = " (itoa (length rows))))

      ;; ---- Ve bang ----
      (setq layer "MTO-OVERLAP-TEST")
      (setq pt (list 0.0 0.0))
      (setq n (mto-table-draw-grid rows pt layer))
      (to-log f (strcat "Da ve " (itoa n) " o text"))

      ;; ---- Doc lai tung o text va kiem tra ----
      (to-log f "")
      (to-log f "--- Kiem tra tung o text ---")
      (setq ss (ssget "_X" (list '(0 . "TEXT") (cons 8 layer))))
      (setq total (if ss (sslength ss) 0))
      (to-log f (strcat "Tong so TEXT tim thay = " (itoa total)))

      (setq checked 0 over 0 i 0)
      (while (< i total)
        (setq e (ssname ss i))
        (if e
          (progn
            (setq ed (entget e))
            (setq txt (cdr (assoc 1 ed)))
            (setq tx  (car (cdr (assoc 10 ed))))
            (setq ty  (cadr (cdr (assoc 10 ed))))
            (setq h   (cdr (assoc 40 ed)))
            (setq w   (to-text-width txt h))

            ;; Tim cot chua text nay (theo ranh gioi cot)
            (setq colx 0.0 colw 0.0)
            (setq colw (mto-table-col-for-x tx))
            (setq checked (1+ checked))

            ;; Kiem tra tran: x + width > ranh gioi phai cua cot
            (if colw
              (progn
                (setq colx (car colw))
                (if (> (+ tx w) (+ colx (cdr colw)))
                  (progn
                    (setq over (1+ over))
                    (to-log f (strcat "  TRAN: \"" txt "\""
                                      " x=" (mto-num->str tx)
                                      " rong=" (mto-num->str w)
                                      " -> ket thuc " (mto-num->str (+ tx w))
                                      " > cot phai " (mto-num->str (+ colx (cdr colw)))))))
                (if (>= over 8) (setq i total))))))
        (setq i (1+ i)))

      (to-log f "")
      (to-log f "======================================================")
      (to-log f (strcat "Tong so o kiem tra = " (itoa checked)))
      (to-log f (strcat "So o TRAN ra ngoai = " (itoa over)))
      (if (= over 0)
        (to-log f "KET LUAN: KHONG CO O NAO TRAN -> chu KHONG chong nhau")
        (to-log f "KET LUAN: CON O TRAN -> can tang chieu rong cot"))
      (to-log f "======================================================")
      (close f)
      (princ "\nOVERLAP-TEST-XONG")
      t)))

;; Tim cot chua toa do x. Tra ve (X-BAT-DAU . CHIEU-RONG) hoac nil
(defun mto-table-col-for-x (x / i cx w)
  (setq i 0)
  (setq cx 0.0)
  (while (< i (length *MTO-TABLE-COLS*))
    (setq w (mto-table-col-width i))
    (if (and (>= x cx) (< x (+ cx w)))
      (setq i (length *MTO-TABLE-COLS*))   ; tim thay -> dung
      (progn (setq cx (+ cx w)) (setq i (1+ i)))))
  (if (< cx (mto-table-total-width))
    (cons cx w)
    nil))
