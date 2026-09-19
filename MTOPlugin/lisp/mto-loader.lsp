;;; ============================================================
;;; mto-loader.lsp -- NAP TOAN BO MTOPro bang DUY NHAT mot file
;;;
;;; CACH DUNG:
;;;   - Sau khi cai dat: chi can mo AutoCAD, plugin .NET / Startup Suite nap file nay.
;;;   - Thu cong: APPLOAD chon file nay, hoac go: (load "duong-dan/mto-loader.lsp")
;;;
;;; KHI FILE NAY DUOC LOAD, NO TU DONG NAP TOAN BO 16 MODULE CON
;;; (xem khoi "TU DONG NAP" o cuoi file). Khong can load tung file.
;;;
;;; LUU Y QUAN TRONG (SECURELOAD):
;;;   AutoCAD mac dinh SECURELOAD=1 -> chan (load ...) voi file ngoai
;;;   TRUSTEDPATHS ("File load canceled"). Neu gap loi nay, chon mot trong:
;;;     (a) Them thu muc vao Options > Files > Trusted Locations, hoac
;;;     (b) Dat SECURELOAD = 0 (khong khuyen nghi cho moi truong khong tin cay), hoac
;;;     (c) Dung APPLOAD (hop thoai) de nap file.
;;; ============================================================

;; Thu muc goc cua bo LISP. Plugin .NET dat truoc khi nap; neu nap thu cong thi
;; de trong, loader se tu tim qua Support Path.
(if (null *MTO-HOME*) (setq *MTO-HOME* ""))
(if (null *MTO-LOAD-RESULT*) (setq *MTO-LOAD-RESULT* '()))

(setq *MTO-MODULES*
  '("mto-ui.lsp"
    "mto-core.lsp"
    "mto-select.lsp"
    "mto-text.lsp"
    "mto-block.lsp"
    "mto-geometry.lsp"
    "mto-result.lsp"
    "mto-csv.lsp"
    "mto-orphan.lsp"
    ;; PHASE 2
    "mto-table.lsp"
    "mto-find.lsp"
    "mto-update.lsp"
    "mto-undo.lsp"
    ;; PHASE 3
    "mto-formula.lsp"
    "mto-subtotal.lsp"
    ;; PHASE 4
    "mto-floor.lsp"
    "mto-config.lsp"))

(setq *MTO-VERSION* "0.6.0-lisp")

;; Load tat ca module tu thu muc `base`.
;; Tra ve alist: ((OK . n) (FAIL . n) (MISSING . (ten-file...)))
;;
;; LUU Y QUAN TRONG: (findfile ...) cua AutoLISP CHI tim trong Support File Search
;; Path, KHONG resolve duong dan tuyet doi. Vi vay phai kiem tra them bang
;; (vl-file-size path) de nap duoc file o thu muc cai dat (vd %LOCALAPPDATA%).
(defun mto-load-modules (base / ok fail missing p f full sz)
  (setq ok 0 fail 0 missing '())
  (foreach f *MTO-MODULES*
    (setq full (strcat base "/" f))
    (setq p nil)
    ;; 1) duong dan tuyet doi / tuong doi: kiem tra file co that
    (if (and full
             (setq sz (vl-catch-all-apply 'vl-file-size (list full)))
             (not (vl-catch-all-error-p sz))
             sz (> sz 0))
      (setq p full)
      ;; 2) theo Support File Search Path
      (progn
        (setq p (findfile full))
        (if (null p) (setq p (findfile f)))))
    (if (null p)
      (progn
        (setq fail (1+ fail))
        (setq missing (append missing (list f))))
      (progn
        (if (vl-catch-all-error-p (vl-catch-all-apply 'load (list p)))
          (setq fail (1+ fail))
          (setq ok (1+ ok))))))
  (list (cons 'OK ok) (cons 'FAIL fail) (cons 'MISSING missing)))

;; Load tu thu muc cua chinh loader nay.
;; Uu tien *MTO-HOME* (do plugin .NET dat truoc khi nap), roi Support Path.
;; LUU Y: (vl-filename-directory nil) se loi "bad argument type: stringp nil"
;; => phai kiem tra nil truoc khi goi.
(defun mto-load-all ( / base lf)
  (setq base nil)
  (if (and *MTO-HOME* (/= *MTO-HOME* ""))
    (setq base *MTO-HOME*))
  (if (null base)
    (progn
      (setq lf (findfile "mto-loader.lsp"))
      (if lf (setq base (vl-filename-directory lf)))))
  (if (null base) (setq base ""))
  (mto-load-modules base))

(defun c:MTOHELP ( / )
  (princ "\n=== MTO LISP Toolset ===")
  (princ (strcat "\nPhien ban: " *MTO-VERSION*))
  (princ "\n\n--- NAP DU LIEU ---")
  (princ "\nMTOSEL      Chon vung (W/C/WP/CP/F) + loc loai/layer")
  (princ "\nMTOTEXT     Nhan dang TEXT/MTEXT theo PREFIX -> CATEGORY")
  (princ "\nMTOBLK      Chon block mau -> dem + MANUAL ADJUSTMENT")
  (princ "\nMTOBLKMAN   Dieu chinh manual cho dong co san")
  (princ "\nMTOGEO      Boc chieu dai LINE/LWPOLYLINE/ARC/CIRCLE")
  (princ "\n\n--- KET QUA ---")
  (princ "\nMTOLIST     Hien thi bang ket qua (loc theo CATEGORY)")
  (princ "\nMTOCSV      Xuat CSV")
  (princ "\nMTOTABLE    Tao bang tren ban ve (Table/Grid)")
  (princ "\nMTOORPHAN   Kiem tra & loai du lieu mo coi")
  (princ "\n\n--- DOI CHIEU BAN VE ---")
  (princ "\nMTOFIND     Tim STT/tu khoa -> zoom + chon doi tuong")
  (princ "\nMTOGOTO     Zoom theo handle")
  (princ "\n\n--- CAP NHAT NGUOC ---")
  (princ "\nMTOUPDATE   Cap nhat noi dung TEXT/MTEXT theo dong")
  (princ "\nMTOSNAP     Chup snapshot truoc khi sua")
  (princ "\nMTOUNDO     Khoi phuc gia tri cu tu snapshot")
  (princ "\nMTOSNAPSHOW Xem snapshot hien tai")
  (princ "\nMTOXCHECK   Kiem tra XData MTO tren doi tuong")
  (princ "\n\n--- TINH TOAN ---")
  (princ "\nMTOFORMULA  Cong thuc tuy chinh (vd: LEN * 1.05, SL x 2)")
  (princ "\nMTOSUB      Subtotal / gom nhom theo khoa")
  (princ "\nMTODED      Khau tru (deduction) theo dong")
  (princ "\n\n--- TANG / KHU VUC / CAU HINH ---")
  (princ "\nMTOFLOOR    Gan Floor/Zone/Area + subtotal theo tang")
  (princ "\nMTOCFG      Cau hinh theo tung DWG (file .mtocfg + NOD)")
  (princ "\n\nDU LIEU PHIEN: *MTO-DB*, *MTO-UNDO*, *MTO-LAST-SELECTION*")
  (princ))

;; ============================================================
;; TU DONG NAP CAC MODULE khi file nay duoc load
;;
;; DAY LA HANH VI BAT BUOC: nguoi dung (hoac plugin .NET, hoac Startup Suite)
;; chi can load DUY NHAT file mto-loader.lsp, cac module con phai duoc nap ngay.
;; Truoc day file nay chi dinh nghia ham ma khong goi -> MTOBLK... khong ton tai.
;; ============================================================
(setq *MTO-LOAD-RESULT* (mto-load-all))

(princ (strcat "\nMTOPro v" *MTO-VERSION*
               " : da nap " (itoa (cdr (assoc 'OK *MTO-LOAD-RESULT*)))
               "/" (itoa (length *MTO-MODULES*)) " module."))

;; Bat hien thi TEN LENH tren thanh trang thai (DIESEL, tu dong cho moi lenh)
(if (not (vl-catch-all-error-p (vl-catch-all-apply 'mto-ui-status-on (list))))
  (princ "\nDa bat hien thi ten lenh tren thanh trang thai (go MTOTITLE de tat)."))

(if (> (cdr (assoc 'FAIL *MTO-LOAD-RESULT*)) 0)
  (progn
    (princ "\nCANH BAO: khong nap duoc cac module sau:")
    (foreach f (cdr (assoc 'MISSING *MTO-LOAD-RESULT*))
      (princ (strcat "\n  - " f)))
    (princ "\nThu muc da thu: ")
    (princ (if (and *MTO-HOME* (/= *MTO-HOME* "")) *MTO-HOME* "(Support Path)"))))
(princ "\nGo MTOHELP de xem danh sach lenh.")
(princ)
