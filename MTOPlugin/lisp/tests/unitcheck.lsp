;;; ============================================================
;;; unitcheck.lsp -- KIEM CHUNG DON VI THAT cua ban ve
;;;
;;; Doc cac DIMENSION co san trong ban ve va in gia tri do (DXF 42),
;;; tu do suy ra ban ve ve bang don vi gi (mm / m / inch).
;;;
;;; Goi: (mto-unitcheck "log.txt")
;;; ============================================================

(defun mto-unitcheck (out / f ss i n e ed txt m val vals sorted)
  (setq f (open out "w"))
  (if (null f) (progn (princ "\nKhong mo duoc log") nil)
    (progn
      (write-line "======================================================" f)
      (write-line "KIEM CHUNG DON VI BAN VE" f)
      (write-line (strcat "DWG      : " (getvar "DWGNAME")) f)
      (write-line (strcat "INSUNITS : " (itoa (getvar "INSUNITS"))
                        "  (1=inch 4=mm 6=m)") f)
      (write-line "======================================================" f)

      ;; ---- 1. Doc DIMENSION co san ----
      (write-line "" f)
      (write-line "--- 1. Gia tri do cua cac DIMENSION co san (DXF 42) ---" f)
      (setq ss (ssget "_X" '((0 . "DIMENSION"))))
      (setq n (if ss (sslength ss) 0))
      (write-line (strcat "Tong so DIMENSION = " (itoa n)) f)
      (setq vals '())
      (setq i 0)
      (while (and (< i n) (< (length vals) 40))
        (setq e (ssname ss i))
        (if e
          (progn
            (setq ed (entget e))
            (setq m (cdr (assoc 42 ed)))     ; measurement
            (if m
              (setq vals (append vals (list m))))))
        (setq i (1+ i)))
      (if vals
        (progn
          (setq sorted (vl-sort vals '<))
          (write-line (strcat "So gia tri doc duoc = " (itoa (length sorted))) f)
          (write-line (strcat "Nho nhat = " (mto-num->str (car sorted))) f)
          (write-line (strcat "Lon nhat = " (mto-num->str (car (reverse sorted)))) f)
          (write-line "Mau 20 gia tri tang dan:" f)
          (setq i 0)
          (foreach v sorted
            (if (< i 20)
              (progn (write-line (strcat "  DIM|" (mto-num->str v)) f)
                     (setq i (1+ i)))))
          ;; Phan tich
          (write-line "" f)
          (write-line "--- PHAN TICH ---" f)
          (setq i 0)
          (setq n2 0)
          (foreach v sorted
            (if (< v 1000) (setq n2 (1+ n2))))
          (write-line (strcat "So DIM nho hon 1000 = " (itoa n2)
                              " / " (itoa (length sorted))) f)
          (write-line "" f)
          (write-line "SUY LUAN:" f)
          (write-line "  - Neu phan lon DIM ~ 800-1200 => ban ve ve bang mm" f)
          (write-line "    (vi do rong cua/cua nguoi ~ 800-900 mm)" f)
          (write-line "  - Neu phan lon DIM ~ 0.8-1.2  => ban ve ve bang m" f)
          (write-line "  - Neu phan lon DIM ~ 30-40    => ban ve ve bang inch" f))
        (write-line "Khong doc duoc DIMENSION nao." f))

      ;; ---- 2. Kich thuoc bao (extents) ----
      (write-line "" f)
      (write-line "--- 2. Kich thuoc bao toa do (EXTMIN/EXTMAX) ---" f)
      (setq vals (getvar "EXTMIN"))
      (if vals
        (write-line (strcat "EXTMIN = " (mto-num->str (car vals)) ", "
                            (mto-num->str (cadr vals))) f))
      (setq vals (getvar "EXTMAX"))
      (if vals
        (write-line (strcat "EXTMAX = " (mto-num->str (car vals)) ", "
                            (mto-num->str (cadr vals))) f))
      (if (and (getvar "EXTMIN") (getvar "EXTMAX"))
        (write-line (strcat "Chieu rong ban ve = "
                            (mto-num->str (- (car (getvar "EXTMAX")) (car (getvar "EXTMIN"))))
                            " don vi") f))

      ;; ---- 3. Chieu cao chu TEXT (thuong 2-3 mm hoac 0.1-0.2 inch) ----
      (write-line "" f)
      (write-line "--- 3. Chieu cao chu TEXT (DXF 40) ---" f)
      (setq ss (ssget "_X" '((0 . "TEXT"))))
      (setq n (if ss (sslength ss) 0))
      (setq vals '())
      (setq i 0)
      (while (and (< i n) (< (length vals) 50))
        (setq e (ssname ss i))
        (if e
          (progn
            (setq m (cdr (assoc 40 (entget e))))
            (if (and m (> m 0)) (setq vals (append vals (list m))))))
        (setq i (1+ i)))
      (if vals
        (progn
          (setq sorted (vl-sort vals '<))
          (write-line (strcat "Chieu cao chu nho nhat = " (mto-num->str (car sorted))) f)
          (write-line (strcat "Chieu cao chu lon nhat = " (mto-num->str (car (reverse sorted)))) f)
          (write-line "SUY LUAN: chu CAD chuan VN cao 2.0-3.5 (mm) hoac 0.1-0.2 (inch)" f))
        (write-line "Khong co TEXT." f))

      (write-line "" f)
      (write-line "======================================================" f)
      (close f)
      (princ "\nUNITCHECK-XONG")
      t)))
