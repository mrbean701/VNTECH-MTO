;;; ============================================================
;;; MTO Plugin - AutoLISP Wrapper Functions
;;; De tai: R&D-CAD-QTO-01
;;; Mo ta: Cac ham LISP de goi lenh .NET tu command line
;;; Cai dat: NETLOAD MTOPlugin.dll, sau do load file nay
;;; ============================================================

;;; MTO - Mo panel boc tach khoi luong
;;; Su dung: Go "MTO" tai command prompt
(defun c:MTO ()
  (command "._MTO")
  (princ)
)

;;; MTOSCAN - Quet ban ve khong mo panel (batch-friendly)
;;; Su dung: Go "MTOSCAN" tai command prompt
;;; Tham so: Khong (tu dong quet Model + All Layouts)
(defun c:MTOSCAN ()
  (command "._MTOTHONGKE")
  (princ)
)

;;; MTOEXPORT - Xuat Excel tu ket qua quet truoc do
;;; Su dung: Go "MTOEXPORT" tai command prompt
(defun c:MTOEXPORT ()
  (prompt "\nMTOEXPORT: Dung Bước 2 trong panel MTO de xuat Excel.")
  (prompt "\nHoac go MTO de mo panel, chon muc, bam 'Xuat Excel'.")
  (princ)
)

;;; MTOBANG - Tao bang tong hop khoi luong tren ban ve moi
;;; Su dung: Go "MTOBANG" tai command prompt
(defun c:MTOBANG ()
  (command "._MTOBANG")
  (princ)
)

;;; MTOZOOM - Phong toi doi tuong theo Handle
;;; Su dung: Go "MTOZOOM <handle>" tai command prompt
;;; Vi du: MTOZOOM 1A3B2C4D
(defun c:MTOZOOM ()
  (command "._MTOZOOM")
  (princ)
)

;;; MTORULES - Mo Rule Editor
;;; Su dung: Go "MTORULES" tai command prompt
(defun c:MTORULES ()
  (prompt "\nMTORULES: Mo panel MTO (go MTO), bam 'Mở Rule Editor'.")
  (princ)
)

;;; MTOSTATUS - Hien thi trang thai plugin
;;; Su dung: Go "MTOSTATUS" tai command prompt
(defun c:MTOSTATUS ()
  (prompt "\n=== MTO Plugin Status ===")
  (prompt "\nVersion: 0.1.0 (developer preview)")
  (prompt "\nCommands: MTO, MTOZOOM, MTOBANG, MTOSCAN, MTORULES")
  (prompt "\nDe tai: R&D-CAD-QTO-01")
  (princ)
)

(prompt "\nMTO Plugin LISP wrappers loaded. Go MTO de bat dau.")
(princ)
