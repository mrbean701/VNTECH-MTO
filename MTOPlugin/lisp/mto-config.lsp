;;; ============================================================
;;; mto-config.lsp -- MTO: cau hinh theo tung DWG (TASK-016)
;;;
;;; Muc tieu: moi ban ve nho duoc cau hinh MTO cua chinh no
;;; (duong dan bo quy tac, don vi, thu muc xuat, floor hien hanh...).
;;;
;;; HAI CO CHE (co ly do):
;;;   1. FILE canh DWG: <ten-dwg>.mtocfg  -- luon hoat dong, testable,
;;;      de doc/sao chep/gui kem ban ve.
;;;   2. NOD (Named Objects Dictionary) + XRecord -- luu NGAY TRONG DWG,
;;;      di theo ban ve. Co the khong kha dung o moi moi truong => thu va
;;;      bao ro neu that bai (khong lam hong luong chinh).
;;;
;;; Dinh dang file: moi dong "KEY|VALUE" -- KHONG dung read/eval
;;; (tranh thuc thi du lieu tu file).
;;;
;;; Logic thuan (testable headless):
;;;   mto-cfg-new              -- cau hinh mac dinh
;;;   mto-cfg-get / mto-cfg-set
;;;   mto-cfg-to-lines         -- cfg -> danh sach dong
;;;   mto-cfg-from-lines       -- danh sach dong -> cfg
;;;   mto-cfg-default-path     -- duong dan file theo ten DWG
;;;   mto-cfg-save / -load     -- ghi/doc file
;;;   mto-cfg-nod-save / -load -- thu luu/doc trong DWG (co the nil)
;;;
;;; Command: MTOCFG
;;; ============================================================

(vl-load-com)

(setq *MTO-CFG-SEP* "|")
(setq *MTO-CFG-NOD-KEY* "MTO_CONFIG")

;; ------------------------------------------------------------
;; 1. CAU HINH
;; ------------------------------------------------------------

(defun mto-cfg-new ()
  (list
    (cons "RULESPATH"  "config/rules.sample.json")
    (cons "UNIT"       "mm")
    (cons "OUTPUTDIR"  "")
    (cons "FLOOR"      "")
    (cons "ZONE"       "")
    (cons "XREFMODE"   "UniqueBySource")
    (cons "LAYERFILTER" "")
    (cons "LASTSCAN"   "")))

(defun mto-cfg-get (cfg key / hit)
  (setq key (mto-str-up key))
  (setq hit (assoc key cfg))
  (if hit (cdr hit) nil))

;; Dat/thay gia tri (immutable -> tra cfg moi)
(defun mto-cfg-set (cfg key val / k hit out)
  (setq k (mto-str-up key))
  (setq hit (assoc k cfg))
  (if hit
    (subst (cons k val) hit cfg)
    (append cfg (list (cons k val)))))

;; ------------------------------------------------------------
;; 2. SERIALIZE (khong dung read/eval)
;; ------------------------------------------------------------

;; Gia tri khong duoc chua ky tu phan cach hoac xuong dong
(defun mto-cfg-value-ok-p (v / s)
  (setq s (if v (vl-princ-to-string v) ""))
  (if (or (vl-string-search *MTO-CFG-SEP* s)
          (vl-string-search "\n" s)
          (vl-string-search "\r" s))
    nil t))

(defun mto-cfg-to-lines (cfg / out v)
  (setq out '())
  (foreach p cfg
    (setq v (if (cdr p) (vl-princ-to-string (cdr p)) ""))
    ;; lam sach: bo ky tu phan cach de khong pha dinh dang
    (setq v (vl-string-translate "|\r\n" "___" v))
    (setq out (append out (list (strcat (car p) *MTO-CFG-SEP* v)))))
  out)

(defun mto-cfg-from-lines (lines / out s pos k v)
  (setq out '())
  (foreach s lines
    (if (and s (/= (mto-str-trim s) ""))
      (progn
        (setq pos (vl-string-search *MTO-CFG-SEP* s))
        (if pos
          (progn
            (setq k (substr s 1 pos))
            (setq v (substr s (+ pos 2)))
            (setq out (append out (list (cons (mto-str-up k) v)))))))))
  out)

;; ------------------------------------------------------------
;; 3. FILE
;; ------------------------------------------------------------

;; Duong dan file cau hinh theo ten DWG
(defun mto-cfg-default-path (dwgname / base n)
  (setq base (if (or (null dwgname) (= dwgname "")) "drawing" dwgname))
  ;; bo duoi .dwg
  (setq n (strlen base))
  (if (and (> n 4) (= (strcase (substr base (- n 3))) (strcase ".dwg")))
    (setq base (substr base 1 (- n 4))))
  (strcat base ".mtocfg"))

(defun mto-cfg-save (cfg path / f)
  (setq f (open path "w"))
  (if (null f) nil
    (progn
      (foreach line (mto-cfg-to-lines cfg)
        (write-line line f))
      (close f)
      t)))

(defun mto-cfg-load (path / f lines line)
  (if (null (findfile path))
    nil
    (progn
      (setq lines '())
      (setq f (open path "r"))
      (if (null f) nil
        (progn
          (while (setq line (read-line f))
            (setq lines (append lines (list line))))
          (close f)
          (mto-cfg-from-lines lines))))))

;; ------------------------------------------------------------
;; 4. NOD (thu luu trong DWG; co the khong kha dung)
;; ------------------------------------------------------------

(defun mto-cfg-nod-save (cfg / nod xr payload r)
  (setq payload (mto-str-join (mto-cfg-to-lines cfg) "~"))
  (setq r (vl-catch-all-apply
    '(lambda ( / nod xr)
       (setq nod (namedobjdict))
       (if (dictsearch nod *MTO-CFG-NOD-KEY*)
         (dictremove nod *MTO-CFG-NOD-KEY*))
       (setq xr (entmakex (list '(0 . "XRECORD")
                                '(100 . "AcDbXrecord")
                                (cons 1 payload))))
       (if xr (dictadd nod *MTO-CFG-NOD-KEY* xr) nil))))
  (if (vl-catch-all-error-p r) nil (if r t nil)))

(defun mto-cfg-nod-load ( / nod xr data r)
  (setq r (vl-catch-all-apply
    '(lambda ( / nod xr data)
       (setq nod (namedobjdict))
       (setq xr (dictsearch nod *MTO-CFG-NOD-KEY*))
       (if (null xr) nil
         (progn
           (setq data (cdr (assoc 1 xr)))
           (if data (mto-cfg-from-lines (mto-str-split data "~")) nil))))))
  (if (vl-catch-all-error-p r) nil r))

;; ------------------------------------------------------------
;; 5. COMMAND
;; ------------------------------------------------------------

(defun mto-cfg-print (cfg)
  (foreach p cfg
    (princ (strcat "\n  " (car p) " = " (if (cdr p) (cdr p) "")))))

(defun c:MTOCFG ( / cfg path dwg pathIn opt val k)
  (mto-ui-start "MTOCFG" "Cau hinh theo tung ban ve")
  (setq dwg (getvar "DWGNAME"))
  (setq path (mto-cfg-default-path dwg))
  (princ (strcat "\nBan ve: " (if dwg dwg "(khong ten)")))
  (princ (strcat "\nFile cau hinh: " path))

  ;; nap: uu tien NOD (trong DWG), roi file, roi mac dinh
  (setq cfg (mto-cfg-nod-load))
  (if cfg
    (princ "\n(Da nap cau hinh tu NOD trong DWG)")
    (progn
      (setq cfg (mto-cfg-load path))
      (if cfg
        (princ "\n(Da nap cau hinh tu file)")
        (progn
          (setq cfg (mto-cfg-new))
          (princ "\n(Dung cau hinh mac dinh)")))))

  (princ "\n\nCau hinh hien tai:")
  (mto-cfg-print cfg)

  (princ "\n\n1 = Sua mot khoa")
  (princ "\n2 = Luu ra file")
  (princ "\n3 = Luu vao DWG (NOD)")
  (princ "\n4 = Bo qua")
  (setq opt (getstring T "\nChon <4>: "))

  (cond
    ((= opt "1")
     (setq k (mto-str-up (mto-str-trim (getstring T "\nKhoa (vd UNIT): "))))
     (if (/= k "")
       (progn
         (setq val (getstring T "\nGia tri moi: "))
         (setq cfg (mto-cfg-set cfg k val))
         (if (mto-cfg-save cfg path)
           (progn
             (princ "\nDa luu file cau hinh.")
             (mto-cfg-print cfg))
           (princ "\nKhong ghi duoc file.")))
       (princ "\nDa huy.")))

    ((= opt "2")
     (if (mto-cfg-save cfg path)
       (princ (strcat "\nDa luu: " path))
       (princ "\nKhong ghi duoc file.")))

    ((= opt "3")
     (if (mto-cfg-nod-save cfg)
       (princ "\nDa luu cau hinh vao DWG (NOD).")
       (princ "\nKHONG luu duoc vao NOD (moi truong khong ho tro) -- dung che do file.")))

    (t (princ "\nBo qua.")))
  (princ))

(princ "\nmto-config.lsp loaded.")
(princ)
