;;; ============================================================
;;; mto-ui.lsp -- HIEN THI TEN LENH DANG CHAY (UX)
;;;
;;; AutoCAD co 3 cach hien thi "dang lam gi":
;;;
;;;   1) DONG LENH (Command line)  <- (princ ...)
;;;      Hien banner + ten lenh ngay khi lenh bat dau.
;;;
;;;   2) THANH TRANG THAI (Status bar) <- bien he thong MODEMACRO
;;;      Ho tro DIESEL: "$(getvar,cmdnames)" tu dong tra ve TEN LENH
;;;      dang chay. Dat MOT LAN la hien cho MOI lenh, khong can sua
;;;      tung lenh.
;;;
;;;   3) TIEN TO TRONG PROMPT  <- (getstring T "[MTOGEO] ...")
;;;      Moi cau hoi deu mang ten lenh, de nguoi dung khong bi lac.
;;;
;;; Lenh MTOTITLE: BAT/TAT hien thi tren thanh trang thai.
;;; ============================================================

;; Trang thai bat/tat hien thi tren thanh trang thai
(if (null *MTO-UI-MACRO-ON*) (setq *MTO-UI-MACRO-ON* T))

;; Chuoi DIESEL: tu dong lay ten lenh dang chay
(setq *MTO-UI-DIESEL* "MTOPro | $(getvar,cmdnames)")

;; ------------------------------------------------------------
;; BAT hien thi ten lenh tren thanh trang thai
;; ------------------------------------------------------------
(defun mto-ui-status-on ()
  (setq *MTO-UI-MACRO-ON* T)
  (vl-catch-all-apply 'setvar (list "MODEMACRO" *MTO-UI-DIESEL*))
  T)

;; ------------------------------------------------------------
;; TAT hien thi (tra thanh trang thai ve mac dinh)
;; ------------------------------------------------------------
(defun mto-ui-status-off ()
  (setq *MTO-UI-MACRO-ON* nil)
  (vl-catch-all-apply 'setvar (list "MODEMACRO" ""))
  T)

;; ------------------------------------------------------------
;; BAT DAU LENH: in banner + hien thi lenh tren thanh trang thai
;;   cmd  = ten lenh, vd "MTOGEO"
;;   desc = mo ta ngan, vd "Do chieu dai cap / ong"
;; ------------------------------------------------------------
(defun mto-ui-start (cmd desc)
  ;; Thanh trang thai: hien ten lenh + mo ta (trong luc chay)
  (if *MTO-UI-MACRO-ON*
    (vl-catch-all-apply 'setvar (list "MODEMACRO"
      (strcat "MTOPro > " cmd " | " desc))))
  ;; Dong lenh: banner ro rang
  (princ "\n")
  (princ "==============================================================")
  (princ (strcat "\n  " cmd))
  (if (and desc (/= desc ""))
    (princ (strcat "  --  " desc)))
  (princ "\n==============================================================")
  (princ))

;; ------------------------------------------------------------
;; KET THUC LENH: tra thanh trang thai ve che do tu dong + bao xong
;; ------------------------------------------------------------
(defun mto-ui-end (cmd)
  (if *MTO-UI-MACRO-ON*
    (vl-catch-all-apply 'setvar (list "MODEMACRO" *MTO-UI-DIESEL*)))
  (princ (strcat "\n---- " cmd " : ket thuc ----"))
  (princ))

;; ------------------------------------------------------------
;; Tao chuoi prompt co tien to ten lenh
;;   (getstring T (mto-ui-prompt "MTOGEO" "Layer (wildcard *): "))
;; ------------------------------------------------------------
(defun mto-ui-prompt (cmd msg)
  (strcat "\n[" cmd "] " msg))

;; ------------------------------------------------------------
;; Cap nhat tien trinh len thanh trang thai (khi chay lau)
;;   (mto-ui-progress "MTOGEO" "Dang quet 574 doi tuong...")
;; ------------------------------------------------------------
(defun mto-ui-progress (cmd msg)
  (if *MTO-UI-MACRO-ON*
    (vl-catch-all-apply 'setvar (list "MODEMACRO"
      (strcat "MTOPro > " cmd " | " msg))))
  (princ))

;; ------------------------------------------------------------
;; LENH MTOTITLE -- BAT/TAT hien thi ten lenh tren thanh trang thai
;; ------------------------------------------------------------
(defun c:MTOTITLE ( / m on)
  (mto-ui-start "MTOTITLE" "Bat/tat hien thi ten lenh")
  (princ (strcat "\nTrang thai hien tai: "
                 (if *MTO-UI-MACRO-ON* "DANG BAT" "DANG TAT")))
  (princ "\nThanh trang thai se hien: MTOPro > <TEN LENH> | <mo ta>")
  (setq m (getstring T "\nBat/Tat [ON/OFF] <ON>: "))
  (setq on (if (or (= m "") (= (strcase m) "ON") (= (strcase m) "BAT")) T nil))
  (if on (mto-ui-status-on) (mto-ui-status-off))
  (princ (strcat "\n=> Da " (if on "BAT" "TAT")
                 " hien thi ten lenh tren thanh trang thai."))
  (if on
    (princ "\n   Thu go mot lenh MTO* de xem ten lenh hien o goc duoi man hinh."))
  (princ))

(princ "\nmto-ui.lsp loaded.")
(princ)
