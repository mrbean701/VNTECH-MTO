;;; Kiem chung canh bao don vi tren ban ve THAT
;;; Goi: (mto-unitwarn-test "log.txt")

(defun mto-unitwarn-test (out / f uw det ins warn)
  (setq f (open out "w"))
  (if (null f) (progn (princ "\nKhong mo duoc log") nil)
    (progn
      (write-line "===== KIEM CHUNG CANH BAO DON VI =====" f)
      (write-line (strcat "DWG      : " (getvar "DWGNAME")) f)
      (write-line (strcat "INSUNITS : " (itoa (getvar "INSUNITS"))
                        " -> " (mto-geo-current-unit)) f)
      (write-line "" f)

      ;; Goi ham tu phat hien
      (setq det (mto-geo-detect-unit))
      (write-line "--- mto-geo-detect-unit ---" f)
      (write-line (strcat "SAMPLES  = " (itoa (cdr (assoc 'SAMPLES det)))) f)
      (write-line (strcat "MM       = " (itoa (cdr (assoc 'MM det)))) f)
      (write-line (strcat "M        = " (itoa (cdr (assoc 'M det)))) f)
      (write-line (strcat "OTHER    = " (itoa (cdr (assoc 'OTHER det)))) f)
      (write-line (strcat "DETECTED = " (cdr (assoc 'DETECTED det))) f)
      (write-line "" f)

      ;; Goi ham canh bao
      (setq uw (mto-geo-warn-unit))
      (setq warn (cdr (assoc 'WARN uw)))
      (write-line "--- mto-geo-warn-unit ---" f)
      (write-line (strcat "INSUNIT  = " (cdr (assoc 'INSUNIT uw))) f)
      (write-line (strcat "CO CANH BAO = " (if warn "CO" "KHONG")) f)
      (if warn
        (progn
          (write-line "NOI DUNG CANH BAO:" f)
          (write-line warn f))
        (write-line "(khong co mau thuan)" f))

      (write-line "" f)
      (write-line "===== KET LUAN =====" f)
      (write-line (strcat "Phat hien duoc don vi that: " (cdr (assoc 'DETECTED det))) f)
      (write-line (strcat "Canh bao hoat dong: " (if (and warn (= (cdr (assoc 'DETECTED det)) "mm")) "DUNG" "KIEM TRA LAI")) f)

      (close f)
      (princ "\nUNITWARN-TEST-XONG")
      t)))
