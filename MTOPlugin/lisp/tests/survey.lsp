;;; ============================================================
;;; survey.lsp -- Khao sat ban ve THAT (khong sua ban ve)
;;;
;;; Ghi ra file: thong tin DWG, layers, blocks, text, geometry.
;;; Dung cho buoc dau khi test tren ban ve thuc te.
;;;
;;; Goi: (mto-survey "duong-dan-output.txt")
;;; ============================================================

(defun mto-survey (out / f lay n ss i e ty nm txt cnt pair lst)

  (setq f (open out "w"))
  (if (null f) (progn (princ "\nKhong mo duoc file output") nil)
    (progn

      ;; ---------- 1. THONG TIN BAN VE ----------
      (write-line "===== 1. THONG TIN BAN VE =====" f)
      (write-line (strcat "DWGNAME   = " (getvar "DWGNAME")) f)
      (write-line (strcat "DWGPREFIX = " (getvar "DWGPREFIX")) f)
      (write-line (strcat "INSUNITS  = " (itoa (getvar "INSUNITS"))) f)
      (write-line (strcat "ACADVER   = " (getvar "ACADVER")) f)
      (write-line (strcat "LTSCALE   = " (rtos (getvar "LTSCALE") 2 2)) f)
      (write-line (strcat "CLAYER    = " (getvar "CLAYER")) f)

      ;; ---------- 2. LAYERS ----------
      (write-line "" f)
      (write-line "===== 2. LAYERS =====" f)
      (setq lay (tblnext "LAYER" T) n 0)
      (while lay
        (setq n (1+ n))
        (write-line (strcat "LAYER|" (cdr (assoc 2 lay))
                            "|color=" (itoa (cdr (assoc 62 lay)))
                            "|flags=" (itoa (cdr (assoc 70 lay)))) f)
        (setq lay (tblnext "LAYER")))
      (write-line (strcat "TOTAL-LAYERS = " (itoa n)) f)

      ;; ---------- 3. BLOCK DEFINITIONS ----------
      (write-line "" f)
      (write-line "===== 3. BLOCK DEFINITIONS =====" f)
      (setq lay (tblnext "BLOCK" T) n 0)
      (while lay
        (setq nm (cdr (assoc 2 lay)))
        (if (/= (substr nm 1 1) "*")
          (progn
            (setq n (1+ n))
            (write-line (strcat "BLKDEF|" nm) f)))
        (setq lay (tblnext "BLOCK")))
      (write-line (strcat "TOTAL-BLKDEF (khong ke an danh) = " (itoa n)) f)

      ;; ---------- 4. BLOCK INSERT (dem theo ten) ----------
      (write-line "" f)
      (write-line "===== 4. BLOCK INSERT (dem theo ten) =====" f)
      (setq lst '())
      (setq ss (ssget "_X" '((0 . "INSERT"))))
      (setq i 0 n (if ss (sslength ss) 0))
      (while (< i n)
        (setq e (ssname ss i))
        (if e
          (progn
            (setq nm (cdr (assoc 2 (entget e))))
            (if (and nm (/= (substr nm 1 1) "*"))
              (progn
                (setq pair (assoc nm lst))
                (if pair
                  (setq lst (subst (cons nm (1+ (cdr pair))) pair lst))
                  (setq lst (append lst (list (cons nm 1)))))))))
        (setq i (1+ i)))
      (setq lst (vl-sort lst '(lambda (a b) (> (cdr a) (cdr b)))))
      (foreach p lst
        (write-line (strcat "BLK|" (car p) "|x" (itoa (cdr p))) f))
      (write-line (strcat "TOTAL-INSERT (khong ke an danh) = " (itoa (length lst)) " loai") f)

      ;; ---------- 5. TEXT / MTEXT ----------
      (write-line "" f)
      (write-line "===== 5. TEXT / MTEXT =====" f)
      (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
      (setq i 0 n (if ss (sslength ss) 0))
      (write-line (strcat "TOTAL-TEXT = " (itoa n)) f)
      ;; dem theo layer
      (setq lst '())
      (setq i 0)
      (while (< i n)
        (setq e (ssname ss i))
        (if e
          (progn
            (setq lay (cdr (assoc 8 (entget e))))
            (setq pair (assoc lay lst))
            (if pair
              (setq lst (subst (cons lay (1+ (cdr pair))) pair lst))
              (setq lst (append lst (list (cons lay 1)))))))
        (setq i (1+ i)))
      (setq lst (vl-sort lst '(lambda (a b) (> (cdr a) (cdr b)))))
      (foreach p lst
        (write-line (strcat "TEXT-LAYER|" (car p) "|x" (itoa (cdr p))) f))
      ;; mau noi dung (30 dau)
      (write-line "--- Mau noi dung (30 dau, da loc trung) ---" f)
      (setq lst '())
      (setq i 0)
      (while (and (< i n) (< (length lst) 30))
        (setq e (ssname ss i))
        (if e
          (progn
            (setq txt (cdr (assoc 1 (entget e))))
            (if (and txt (/= (mto-str-trim txt) "") (not (member txt lst)))
              (setq lst (append lst (list txt))))))
        (setq i (1+ i)))
      (foreach tx lst (write-line (strcat "TXT|" tx) f))

      ;; ---------- 6. GEOMETRY ----------
      (write-line "" f)
      (write-line "===== 6. HINH HOC (LINE/LWPOLYLINE/ARC/CIRCLE) =====" f)
      (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,ARC,CIRCLE"))))
      (setq i 0 n (if ss (sslength ss) 0))
      (write-line (strcat "TOTAL-GEOMETRY = " (itoa n)) f)
      (setq lst '())
      (setq i 0)
      (while (< i n)
        (setq e (ssname ss i))
        (if e
          (progn
            (setq lay (cdr (assoc 8 (entget e))))
            (setq pair (assoc lay lst))
            (if pair
              (setq lst (subst (cons lay (1+ (cdr pair))) pair lst))
              (setq lst (append lst (list (cons lay 1)))))))
        (setq i (1+ i)))
      (setq lst (vl-sort lst '(lambda (a b) (> (cdr a) (cdr b)))))
      (foreach p lst
        (write-line (strcat "GEO-LAYER|" (car p) "|x" (itoa (cdr p))) f))
      ;; do dai theo layer (top 10)
      (write-line "--- Tong chieu dai theo layer (top 15) ---" f)
      (setq lst '())
      (setq i 0)
      (while (< i n)
        (setq e (ssname ss i))
        (if e
          (progn
            (setq lay (cdr (assoc 8 (entget e))))
            (setq len (mto-geo-length e))
            (if len
              (progn
                (setq pair (assoc lay lst))
                (if pair
                  (setq lst (subst (cons lay (+ (cdr pair) len)) pair lst))
                  (setq lst (append lst (list (cons lay len)))))))))
        (setq i (1+ i)))
      (setq lst (vl-sort lst '(lambda (a b) (> (cdr a) (cdr b)))))
      (setq i 0)
      (foreach p lst
        (if (< i 15)
          (progn
            (write-line (strcat "GEO-LEN|" (car p) "|" (mto-num->str (cdr p))) f)
            (setq i (1+ i)))))

      ;; ---------- 7. LAYOUTS ----------
      (write-line "" f)
      (write-line "===== 7. LAYOUTS =====" f)
      (setq lay (tblnext "LAYOUT" T))
      (while lay
        (write-line (strcat "LAYOUT|" (cdr (assoc 1 lay))) f)
        (setq lay (tblnext "LAYOUT")))

      (close f)
      (princ (strcat "\nSURVEY-XONG -> " out))
      t)))
