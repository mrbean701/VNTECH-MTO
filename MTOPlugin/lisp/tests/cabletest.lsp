;;; ============================================================
;;; cabletest.lsp -- DO CAP + IN BANG len ban ve THAT
;;;
;;; Quy trinh dung trong accoreconsole (khong tuong tac):
;;;   ssget "_X" voi filter layer cap -> mto-geo-scan-ss -> DB
;;;   -> mto-table-build-rows -> mto-table-draw-grid (ve len ban ve)
;;;   -> SAVEAS ra DWG moi
;;;
;;; Goi: (mto-cabletest "log.txt" "dwg-moi.dwg")
;;; ============================================================

;; Cac layer chua cap/tray trong ban ve camera
(setq *CABLE-LAYERS*
  "Camera Cable,ELV-LINE-LT,ELV-TRAY,1-ELV-Tray&Conduit,ELV-CCTV block,CCTV,ELV-EQP,1-ELV-Equipment")

(defun ct-log (f s) (write-line s f) (princ (strcat "\n  " s)))

(defun mto-cabletest (out saveto / f ss res db rows n)
  (setq f (open out "w"))
  (if (null f) (progn (princ "\nKhong mo duoc log") nil)
    (progn
      (ct-log f "======================================================")
      (ct-log f "DO CAP + IN BANG KHOI LUONG len ban ve")
      (ct-log f (strcat "DWG: " (getvar "DWGNAME")))
      (ct-log f (strcat "INSUNITS: " (itoa (getvar "INSUNITS"))
                        " -> don vi: " (mto-geo-current-unit)))
      (ct-log f "======================================================")

      ;; ---------- BUOC 1: KIEM TRA DU LIEU CAP ----------
      (ct-log f "")
      (ct-log f "--- BUOC 1: Kiem tra du lieu cap/tray trong ban ve ---")
      (setq ss (ssget "_X" (list '(0 . "LINE,LWPOLYLINE,POLYLINE,ARC")
                                 (cons 8 *CABLE-LAYERS*))))
      (ct-log f (strcat "Doi tuong tren cac layer cap = "
                        (itoa (if ss (sslength ss) 0))))
      (if (null ss)
        (ct-log f "KHONG tim thay doi tuong cap -> kiem tra lai ten layer")
        (progn
          ;; chi tiet theo layer (tu tinh vi mto-geo-total-length chi tra TOTAL)
          (setq res (mto-geo-total-length ss))
          (ct-log f (strcat "Tong chieu dai = " (mto-num->str (cdr (assoc 'TOTAL res)))
                            " " (mto-geo-current-unit)
                            " | bo qua = " (itoa (cdr (assoc 'SKIPPED res)))))
          ;; ---------- BUOC 2: NAP VAO DB ----------
          (ct-log f "")
          (ct-log f "--- BUOC 2: Nap vao DB (mto-geo-scan-ss) ---")
          (setq res (mto-geo-scan-ss ss (mto-db-new)))
          (setq db (cdr (assoc 'DB res)))
          (ct-log f (strcat "ADDED = " (itoa (cdr (assoc 'ADDED res)))
                            " | DB = " (itoa (mto-db-count db)) " dong"))

          ;; ---------- BUOC 3: THEM CAMERA (block) ----------
          (ct-log f "")
          (ct-log f "--- BUOC 3: Them camera vao cung bang ---")
          (setq db (mto-blk-scan "SE.DOME CAMERA" db nil))
          (setq db (mto-blk-scan "cam" db nil))
          (ct-log f (strcat "DB sau khi them camera = " (itoa (mto-db-count db)) " dong"))

          ;; ---------- BUOC 4: BANG KET QUA ----------
          (ct-log f "")
          (ct-log f "--- BUOC 4: Bang khoi luong ---")
          (setq db (mto-db-sort db))
          (foreach r (mto-res-table db) (ct-log f r))

          ;; ---------- BUOC 5: VE BANG LEN BAN VE ----------
          (ct-log f "")
          (ct-log f "--- BUOC 5: Ve bang len ban ve ---")
          (setq rows (mto-table-build-rows db))
          (ct-log f (strcat "So dong bang = " (itoa (length rows))))
          (ct-log f "Vi tri: goc toa do (0,0) | Layer: MTO-BANG-CAP")
          (setq n (mto-table-draw-grid rows (list 0.0 0.0) "MTO-BANG-CAP"))
          (ct-log f (strcat "Da ve " (itoa n) " o text"))
          (setq ss (ssget "_X" '((8 . "MTO-BANG-CAP"))))
          (ct-log f (strcat "Entity tren layer MTO-BANG-CAP = "
                            (itoa (if ss (sslength ss) 0))))

          ;; ---------- BUOC 6: LUU DWG ----------
          (ct-log f "")
          (ct-log f "--- BUOC 6: Luu DWG moi ---")
          (setvar "FILEDIA" 0)
          (setq res (vl-catch-all-apply '(lambda () (command "_.SAVEAS" "2018" saveto))))
          (if (vl-catch-all-error-p res)
            (ct-log f (strcat "SAVEAS loi: " (vl-catch-all-error-message res)))
            (ct-log f (strcat "Da luu: " saveto)))))

      (ct-log f "")
      (ct-log f "======================================================")
      (ct-log f "XONG.")
      (close f)
      (princ "\nCABLETEST-XONG")
      t)))
