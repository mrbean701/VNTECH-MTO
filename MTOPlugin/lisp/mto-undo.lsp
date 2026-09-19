;;; ============================================================
;;; mto-undo.lsp -- MTO: snapshot / restore cho batch update (TASK-012)
;;;
;;; Muc tieu: KHONG phu thuoc hoan toan vao UNDO cua AutoCAD.
;;; Truoc khi batch update:
;;;     snapshot: HANDLE -> GIA TRI CU
;;; Sau do moi update. Cho phep:
;;;     MTOUNDO  -> khoi phuc du lieu ve truoc batch operation.
;;;
;;; Pham vi: chi ap dung cho du lieu ma LISP kiem soat duoc
;;; (noi dung TEXT/MTEXT). KHONG khoi phuc XData (ghi chu ro).
;;;
;;; Logic thuan (testable headless):
;;;   mto-undo-capture-entity  -- (handle . value) hoac nil
;;;   mto-undo-snapshot        -- chup tu mot item
;;;   mto-undo-snapshot-many   -- chup tu nhieu item
;;;   mto-undo-count           -- so entry
;;;   mto-undo-save / -load    -- luu/doc snapshot phien
;;;   mto-undo-restore-list    -- khoi phuc -> (OK . FAIL)
;;;   mto-undo-restore         -- khoi phuc snapshot phien
;;;
;;; Command: MTOSNAP (chup), MTOUNDO (khoi phuc), MTOSNAPSHOW (xem)
;;; ============================================================

(vl-load-com)

(if (null *MTO-UNDO*) (setq *MTO-UNDO* '()))

;; ------------------------------------------------------------
;; 1. CHUP SNAPSHOT
;; ------------------------------------------------------------

;; Chup mot handle: (handle . gia-tri-cu) hoac nil neu khong chup duoc
(defun mto-undo-capture-entity (h / en v)
  (setq en (mto-find-resolve h))
  (if (null en) nil
    (progn
      (setq v (mto-upd-get-value en))
      (if v (cons h v) nil))))

;; Chup snapshot tu mot item -> list cac (handle . value)
(defun mto-undo-snapshot (it / out c)
  (setq out '())
  (foreach h (mto-item-get it 'HANDLES)
    (setq c (mto-undo-capture-entity h))
    (if c (setq out (append out (list c)))))
  out)

;; Chup tu nhieu item
(defun mto-undo-snapshot-many (items / out)
  (setq out '())
  (foreach it items
    (setq out (append out (mto-undo-snapshot it))))
  out)

(defun mto-undo-count (snap) (length snap))

;; ------------------------------------------------------------
;; 2. LUU / DOC SNAPSHOT PHIEN
;; ------------------------------------------------------------

(defun mto-undo-save (snap)
  (setq *MTO-UNDO* snap)
  (mto-undo-count snap))

(defun mto-undo-load ()
  (if *MTO-UNDO* *MTO-UNDO* '()))

(defun mto-undo-clear ()
  (setq *MTO-UNDO* '())
  0)

;; ------------------------------------------------------------
;; 3. KHOI PHUC
;; ------------------------------------------------------------

;; Khoi phuc tu mot snapshot. Tra ve (OK . FAIL)
(defun mto-undo-restore-list (snap / ok fail en)
  (setq ok 0 fail 0)
  (foreach pair snap
    (setq en (mto-find-resolve (car pair)))
    (if (and en (mto-upd-set-value en (cdr pair)))
      (setq ok (1+ ok))
      (setq fail (1+ fail))))
  (cons ok fail))

;; Khoi phuc snapshot phien
(defun mto-undo-restore ()
  (mto-undo-restore-list (mto-undo-load)))

;; Mo ta snapshot dang chuoi
(defun mto-undo-describe (snap / )
  (strcat "Snapshot: " (itoa (mto-undo-count snap)) " doi tuong"))

;; ------------------------------------------------------------
;; 4. BATCH UPDATE CO SNAPSHOT (an toan)
;; ------------------------------------------------------------

;; Nhu mto-upd-batch nhung CHUP SNAPSHOT truoc.
;; Tra ve alist: OK / FAIL / ITEMS / SNAP-COUNT
(defun mto-upd-batch-safe (pairs / items snap res)
  (setq items '())
  (foreach p pairs (setq items (append items (list (car p)))))
  ;; chup TRUOC khi sua
  (setq snap (mto-undo-snapshot-many items))
  (mto-undo-save snap)
  (setq res (mto-upd-batch pairs))
  (append res (list (cons 'SNAP-COUNT (mto-undo-count snap)))))

;; ------------------------------------------------------------
;; 5. COMMAND
;; ------------------------------------------------------------

(defun c:MTOSNAP ( / db snap)
  (mto-ui-start "MTOSNAP" "Chup anh du lieu truoc khi sua")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong.")
    (progn
      (setq snap (mto-undo-snapshot-many db))
      (mto-undo-save snap)
      (princ (strcat "\nDa chup snapshot: " (itoa (mto-undo-count snap)) " doi tuong."))
      (foreach p snap
        (princ (strcat "\n  " (car p) " = \"" (cdr p) "\"")))))
  (princ))

(defun c:MTOUNDO ( / snap res)
  (mto-ui-start "MTOUNDO" "Khoi phuc du lieu tu anh chup")
  (setq snap (mto-undo-load))
  (if (null snap)
    (princ "\nChua co snapshot nao trong phien. Hay chup bang MTOSNAP truoc.")
    (progn
      (princ (strcat "\n" (mto-undo-describe snap)))
      (initget "Y N")
      (setq ans (getkword "\nKhoi phuc gia tri cu? [Y/N] <N>: "))
      (if (= (mto-str-up (if ans ans "N")) "Y")
        (progn
          (setq res (mto-undo-restore))
          (princ (strcat "\nDa khoi phuc " (itoa (car res)) " doi tuong."))
          (if (> (cdr res) 0)
            (princ (strcat " That bai " (itoa (cdr res)) " (mo coi hoac khong phai TEXT).")))
          (princ "\nLUU Y: XData KHONG duoc khoi phuc (chi noi dung TEXT/MTEXT)."))
        (princ "\nDa huy."))))
  (princ))

(defun c:MTOSNAPSHOW ( / snap)
  (setq snap (mto-undo-load))
  (if (null snap)
    (princ "\nSnapshot rong.")
    (progn
      (princ (strcat "\n" (mto-undo-describe snap)))
      (foreach p snap
        (princ (strcat "\n  " (car p) " = \"" (cdr p) "\"")))))
  (princ))

(princ "\nmto-undo.lsp loaded.")
(princ)
