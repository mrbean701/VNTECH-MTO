;;; ============================================================
;;; fieldtest.lsp -- TEST TUNG CHUC NANG tren BAN VE THAT
;;;
;;; Ban ve dich: "MB Camera khu Restaurant,Recepption.dwg"
;;; Chay trong accoreconsole (khong tuong tac) - dung ssget "_X".
;;;
;;; Ghi ket qua tung buoc ra file log (khong dau, tranh loi encoding).
;;; KHONG sua ban ve goc tru khi goi buoc ve bang (co the tat).
;;;
;;; Goi: (mto-fieldtest "duong-dan-log.txt" [che-do])
;;;   che-do: 0 = chi doc (mac dinh), 1 = co ve bang len ban ve
;;; ============================================================

(setq *FT-OK* 0)
(setq *FT-FAIL* 0)

(defun ft-log (f s)
  (write-line s f)
  (princ (strcat "\n  " s)))

(defun ft-check (f name expr)
  (if expr
    (progn (setq *FT-OK* (1+ *FT-OK*))
           (ft-log f (strcat "PASS | " name)))
    (progn (setq *FT-FAIL* (1+ *FT-FAIL*))
           (ft-log f (strcat "FAIL | " name)))))

(defun ft-info (f s) (ft-log f (strcat "INFO | " s)))

;; ------------------------------------------------------------
(defun mto-fieldtest (out mode / f ss n db db2 res it rows csv tbl cnt hs unit)

  (setq f (open out "w"))
  (if (null f) (progn (princ "\nKhong mo duoc log") nil)
    (progn
      (setq *FT-OK* 0 *FT-FAIL* 0)
      (ft-log f "======================================================")
      (ft-log f "MTOPro - FIELD TEST tren ban ve THAT")
      (ft-log f (strcat "DWG      : " (getvar "DWGNAME")))
      (ft-log f (strcat "INSUNITS : " (itoa (getvar "INSUNITS"))))
      (ft-log f (strcat "ACADVER  : " (getvar "ACADVER")))
      (ft-log f "======================================================")

      ;; ============ BUOC 1: MTOTEXT - nhan dang text ============
      (ft-log f "")
      (ft-log f "--- BUOC 1: MTOTEXT (nhan dang text theo prefix) ---")
      (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
      (ft-info f (strcat "Tong text trong ban ve = " (itoa (if ss (sslength ss) 0))))
      (ft-check f "ssget TEXT/MTEXT tra ve du lieu" ss)

      ;; text tren cac layer ELV
      (setq ss (ssget "_X" '((0 . "TEXT,MTEXT") (8 . "ELV- QUANG,CCTV,ELV-EQP,ELV-CCTV block"))))
      (ft-info f (strcat "Text tren layer ELV = " (itoa (if ss (sslength ss) 0))))
      (if ss
        (progn
          (setq res (mto-text-scan-ss ss '()))
          (setq db (cdr (assoc 'DB res)))
          (ft-info f (strcat "mto-text-scan-ss: ADDED=" (itoa (cdr (assoc 'ADDED res)))
                             " DB=" (itoa (mto-db-count db))))
          (ft-check f "MTOTEXT quet duoc text ELV" (> (cdr (assoc 'ADDED res)) 0)))
        (ft-info f "Khong co text tren layer ELV - bo qua"))

      ;; ============ BUOC 2: MTOBLK - dem block camera ============
      (ft-log f "")
      (ft-log f "--- BUOC 2: MTOBLK (dem block) ---")
      (setq cnt (mto-blk-count "SE.DOME CAMERA" nil))
      (ft-info f (strcat "mto-blk-count SE.DOME CAMERA = " (itoa cnt)))
      (ft-check f "Dem duoc block SE.DOME CAMERA" (> cnt 0))
      (setq cnt (mto-blk-count "cam" nil))
      (ft-info f (strcat "mto-blk-count cam = " (itoa cnt)))

      ;; dem TAT CA block
      (setq res (mto-blk-count-all))
      (ft-info f (strcat "mto-blk-count-all: " (itoa (length res)) " loai block"))
      (ft-check f "mto-blk-count-all tra ve du lieu" (> (length res) 0))

      ;; nap vao DB
      (setq db (mto-db-new))
      (setq db (mto-blk-scan "SE.DOME CAMERA" db nil))
      (setq db (mto-blk-scan "cam" db nil))
      (ft-info f (strcat "Sau MTOBLK: DB = " (itoa (mto-db-count db)) " dong"))
      (ft-check f "MTOBLK nap vao DB" (> (mto-db-count db) 0))

      ;; kiem tra manual adjustment
      (setq it (car db))
      (setq it (mto-blk-apply-manual it 5))
      (ft-info f (strcat "Manual test: AUTO=" (mto-num->str (mto-item-get it 'AUTOQTY))
                         " MAN=" (mto-num->str (mto-item-get it 'MANQTY))
                         " QTY=" (mto-num->str (mto-item-get it 'QTY))))
      (ft-check f "MANUAL ADJUSTMENT hoat dong"
        (= (mto-item-get it 'QTY) (+ (mto-item-get it 'AUTOQTY) 5.0)))

      ;; ============ BUOC 3: MTOGEO - do chieu dai ============
      (ft-log f "")
      (ft-log f "--- BUOC 3: MTOGEO (do chieu dai cap/ong) ---")
      (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,ARC") (8 . "Camera Cable,ELV-LINE-LT,ELV-TRAY,1-ELV-Tray&Conduit"))))
      (ft-info f (strcat "Doi tuong cap/tray = " (itoa (if ss (sslength ss) 0))))
      (if ss
        (progn
          (setq res (mto-geo-total-length ss))
          (ft-info f (strcat "Tong chieu dai = " (mto-num->str (cdr (assoc 'TOTAL res)))
                             " " (mto-geo-current-unit)))
          (ft-check f "MTOGEO do duoc chieu dai" (> (cdr (assoc 'TOTAL res)) 0))
          (setq res (mto-geo-scan-ss ss db))
          (setq db (cdr (assoc 'DB res)))
          (ft-info f (strcat "Sau MTOGEO: DB = " (itoa (mto-db-count db)) " dong")))
        (ft-info f "Khong co cap/tray tren cac layer nay"))

      (ft-info f (strcat "Don vi ban ve (INSUNITS=" (itoa (mto-geo-insunits)) ") -> " (mto-geo-current-unit)))

      ;; ============ BUOC 4: MTOLIST - bang ket qua ============
      (ft-log f "")
      (ft-log f "--- BUOC 4: MTOLIST (bang ket qua) ---")
      (ft-check f "mto-db-sort khong loi" (mto-db-sort db))
      (setq rows (mto-res-table db))
      (ft-info f (strcat "Bang co " (itoa (length rows)) " dong (ke ca header)"))
      (foreach r rows (write-line (strcat "TABLE|" r) f))
      (ft-check f "mto-res-table tra ve bang" (> (length rows) 1))
      (setq it (mto-res-stats db))
      (ft-info f (strcat "Thong ke: ROWS=" (itoa (cdr (assoc 'ROWS it)))
                         " QTY=" (mto-num->str (cdr (assoc 'QTY it)))
                         " LEN=" (mto-num->str (cdr (assoc 'LENGTH it)))))

      ;; ============ BUOC 5: MTOCSV ============
      (ft-log f "")
      (ft-log f "--- BUOC 5: MTOCSV (xuat CSV) ---")
      (setq csv (strcat (vl-filename-directory out) "/FIELDTEST-camera.csv"))
      (ft-check f "mto-csv-write thanh cong" (mto-csv-write db csv))
      (ft-check f "File CSV ton tai" (findfile csv))
      (if (findfile csv)
        (ft-info f (strcat "CSV: " csv " (" (itoa (vl-file-size csv)) " bytes)")))

      ;; ============ BUOC 6: MTOTABLE - bang tren ban ve ============
      (ft-log f "")
      (ft-log f "--- BUOC 6: MTOTABLE (bang tren ban ve) ---")
      (setq rows (mto-table-build-rows db))
      (ft-info f (strcat "Bang co " (itoa (length rows)) " dong"))
      (setq it (mto-table-grid-entities rows))
      (ft-info f (strcat "Du kien ve: " (itoa (car it)) " TEXT + " (itoa (cdr it)) " LINE"))
      (ft-check f "mto-table-build-rows co du lieu" (> (length rows) 1))
      (ft-check f "Khong co ActiveX trong accoreconsole (dung GRID)"
        (not (mto-table-activex-available-p)))
      (if (= mode 1)
        (progn
          (ft-info f "CHE DO VE: dang ve bang len ban ve...")
          (setq n (mto-table-draw-grid rows (list 0.0 0.0) "MTO-FIELDTEST"))
          (ft-info f (strcat "Da ve " (itoa n) " o text"))
          (ft-check f "Ve bang len ban ve" (> n 0))
          (setq ss (ssget "_X" '((8 . "MTO-FIELDTEST"))))
          (ft-info f (strcat "Entity tren layer MTO-FIELDTEST = " (itoa (if ss (sslength ss) 0))))))

      ;; mode = 2: ve bang + LUU ra DWG MOI (khong sua ban ve goc)
      (if (= mode 2)
        (progn
          (ft-info f "CHE DO VE+LUU: ve bang roi luu DWG moi...")
          (setq n (mto-table-draw-grid rows (list 0.0 0.0) "MTO-FIELDTEST"))
          (ft-info f (strcat "Da ve " (itoa n) " o text"))
          (ft-check f "Ve bang len ban ve" (> n 0))
          (setq ss (ssget "_X" '((8 . "MTO-FIELDTEST"))))
          (ft-info f (strcat "Entity tren layer MTO-FIELDTEST = " (itoa (if ss (sslength ss) 0))))
          (if (and *FT-SAVE-TO* (/= *FT-SAVE-TO* ""))
            (progn
              (setvar "FILEDIA" 0)
              (setq res (vl-catch-all-apply
                          '(lambda () (command "_.SAVEAS" "2018" *FT-SAVE-TO*))))
              (if (vl-catch-all-error-p res)
                (ft-info f (strcat "SAVEAS loi: " (vl-catch-all-error-message res)))
                (ft-info f (strcat "Da luu DWG moi -> " *FT-SAVE-TO*)))
              (ft-check f "Luu DWG moi thanh cong" (findfile *FT-SAVE-TO*)))
            (ft-info f "Khong co *FT-SAVE-TO* -> khong luu"))))

      ;; ============ BUOC 7: MTOORPHAN ============
      (ft-log f "")
      (ft-log f "--- BUOC 7: MTOORPHAN (du lieu mo coi) ---")
      (setq it (mto-orphan-check-db db))
      (ft-info f (strcat "TOTAL=" (itoa (cdr (assoc 'TOTAL it)))
                         " ALIVE=" (itoa (cdr (assoc 'ALIVE it)))
                         " ORPHAN=" (itoa (cdr (assoc 'ORPHAN it)))))
      (ft-check f "MTOORPHAN tra ve thong ke" it)
      (ft-info f (strcat "Bao cao: " (mto-orphan-report db)))

      ;; ============ BUOC 8: MTOSUB / MTODED ============
      (ft-log f "")
      (ft-log f "--- BUOC 8: MTOSUB / MTODED (subtotal + khau tru) ---")
      (setq res (mto-sub-group db 'CATEGORY))
      (ft-info f (strcat "So nhom theo CATEGORY = " (itoa (length res))))
      (foreach g res
        (ft-info f (strcat "  NHOM " (car g) ": NET=" (mto-num->str (mto-sub-net-of g))
                           " LEN=" (mto-num->str (mto-sub-total-of g 'LEN)))))
      (ft-check f "MTOSUB gom nhom duoc" (>= (length res) 1))

      ;; deduction
      (setq it (car db))
      (setq it (mto-sub-set-deduction it 2))
      (ft-info f (strcat "Sau khau tru 2: QTY=" (mto-num->str (mto-item-get it 'QTY))
                         " DED=" (mto-num->str (mto-item-get it 'DEDUCTION))
                         " NET=" (mto-num->str (mto-item-get it 'NETQTY))))
      (ft-check f "MTODED khau tru hoat dong"
        (= (mto-item-get it 'NETQTY) (- (mto-item-get it 'QTY) 2.0)))

      ;; ============ BUOC 9: MTOFORMULA ============
      (ft-log f "")
      (ft-log f "--- BUOC 9: MTOFORMULA (cong thuc) ---")
      (setq res (mto-formula-run "LEN * 1.05" (mto-formula-vars-of-item (car db))))
      (if res
        (progn
          (ft-info f (strcat "Cong thuc LEN * 1.05 = " (mto-num->str (car res))))
          (ft-info f (strcat "Giai thich: " (cdr res)))
          (ft-check f "MTOFORMULA tinh duoc" (> (car res) 0)))
        (ft-info f "Khong tinh duoc (co the LEN = 0)"))

      ;; ============ BUOC 10: MTOFLOOR ============
      (ft-log f "")
      (ft-log f "--- BUOC 10: MTOFLOOR (gan tang) ---")
      (setq res (mto-floor-assign-by-layer db (list (cons "ELV-*" "T1") (cons "Camera*" "T1") (cons "*" "T1")) nil nil))
      (setq db2 (car res))
      (ft-info f (strcat "Gan floor cho " (itoa (cdr res)) " dong"))
      (ft-check f "MTOFLOOR gan duoc" (>= (cdr res) 1))
      (setq res (mto-floor-subtotal db2))
      (foreach g res
        (ft-info f (strcat "  FLOOR " (if (= (car g) "") "(trong)" (car g))
                           ": NET=" (mto-num->str (mto-sub-net-of g)))))

      ;; ============ BUOC 11: MTOFIND / MTOGOTO ============
      (ft-log f "")
      (ft-log f "--- BUOC 11: MTOFIND / MTOGOTO (truy vet) ---")
      (setq it (car db))
      (setq n (mto-find-build-index db))
      (ft-check f "mto-find-build-index hoat dong" (> (length n) 0))
      (setq it (mto-find-by-index db 1))
      (ft-check f "mto-find-by-index tra ve item" it)
      (if it
        (progn
          (setq hs (mto-find-alive-handles it))
          (ft-info f (strcat "Item 1: " (mto-item-get it 'NAME)
                             " | handle song = " (itoa (length hs))))
          (if hs
            (ft-check f "mto-find-zoom-handle chay duoc" (mto-find-zoom-handle (car hs)))
            (ft-info f "Khong co handle song"))))

      ;; ============ BUOC 12: MTOCFG ============
      (ft-log f "")
      (ft-log f "--- BUOC 12: MTOCFG (cau hinh theo DWG) ---")
      (setq it (mto-cfg-new))
      (setq it (mto-cfg-set it "UNIT" (mto-geo-current-unit)))
      (setq it (mto-cfg-set it "FLOOR" "T1"))
      (setq csv (strcat (vl-filename-directory out) "/FIELDTEST-camera.mtocfg"))
      (ft-check f "mto-cfg-save thanh cong" (mto-cfg-save it csv))
      (setq it (mto-cfg-load csv))
      (ft-check f "mto-cfg-load doc lai duoc" it)
      (if it (ft-info f (strcat "Cau hinh doc lai: UNIT=" (mto-cfg-get it "UNIT")
                                " FLOOR=" (mto-cfg-get it "FLOOR"))))

      ;; ============ TONG KET ============
      (ft-log f "")
      (ft-log f "======================================================")
      (ft-log f (strcat "TONG KET: PASS=" (itoa *FT-OK*) "  FAIL=" (itoa *FT-FAIL*)))
      (ft-log f "======================================================")

      (close f)
      (princ (strcat "\nFIELDTEST-XONG: PASS=" (itoa *FT-OK*) " FAIL=" (itoa *FT-FAIL*)))
      t)))

;; guard: ham no-op de tranh loi neu goi nham
(defun ft-infof (x) nil)
