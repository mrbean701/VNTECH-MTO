;;; ============================================================
;;; mto-orphan.lsp -- MTO: phat hien du lieu mo coi (TASK-008)
;;;
;;; Muc tieu: moi handle phai kiem tra duoc con ton tai hay khong.
;;;   (handent handle) -> nil nghia la doi tuong da bi xoa.
;;;
;;; Cho phep:
;;;   - thong ke orphan
;;;   - loai orphan khoi dataset (khong de orphan lam sai khoi luong)
;;;
;;; KHONG tu dong xoa doi tuong khoi DWG. Chi xoa du lieu MTO/cache.
;;;
;;; Logic thuan (testable headless):
;;;   mto-orphan-exists-p     -- handle con ton tai?
;;;   mto-orphan-of-item      -- danh sach handle mo coi cua item
;;;   mto-orphan-check-db     -- thong ke orphan toan DB
;;;   mto-orphan-prune-item   -- bo handle mo coi khoi item
;;;   mto-orphan-prune-db     -- bo orphan toan DB
;;;   mto-orphan-report       -- chuoi bao cao
;;;
;;; Command: MTOORPHAN
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

;; Handle con ton tai trong ban ve?
;;
;; QUAN TRONG (da kiem chung bang thuc nghiem tren accoreconsole):
;;   (handent h) VAN tra ve ename doi voi entity DA BI XOA bang entdel
;;   (entity chi bi danh dau xoa, chua purge cho den khi luu/dong ban ve).
;;   Trong khi do (entget ename) tra ve nil.
;; => Phai kiem tra CA HAI: handent resolve duoc VA entget tra ve du lieu.
(defun mto-orphan-exists-p (h / e res got)
  (if (or (null h) (= h "")) nil
    (progn
      (setq res (vl-catch-all-apply 'handent (list h)))
      (if (or (vl-catch-all-error-p res) (null res))
        nil
        (progn
          (setq got (vl-catch-all-apply 'entget (list res)))
          (if (or (vl-catch-all-error-p got) (null got))
            nil   ; entity da bi xoa -> mo coi
            t))))))

;; Danh sach handle mo coi cua mot item
(defun mto-orphan-of-item (it / out)
  (setq out '())
  (foreach h (mto-item-get it 'HANDLES)
    (if (not (mto-orphan-exists-p h))
      (setq out (append out (list h)))))
  out)

;; Thong ke orphan toan DB
;; Tra ve: TOTAL-HANDLES, ORPHAN, ALIVE, ITEMS-ORPHAN
(defun mto-orphan-check-db (db / total orphan alive itemsOrphan orphs)
  (setq total 0 orphan 0 alive 0 itemsOrphan 0)
  (foreach it db
    (setq orphs (mto-orphan-of-item it))
    (setq total (+ total (length (mto-item-get it 'HANDLES))))
    (if orphs
      (progn
        (setq orphan (+ orphan (length orphs)))
        (setq itemsOrphan (1+ itemsOrphan)))))
  (setq alive (- total orphan))
  (list
    (cons 'TOTAL total)
    (cons 'ALIVE alive)
    (cons 'ORPHAN orphan)
    (cons 'ITEMS-ORPHAN itemsOrphan)))

;; Bo handle mo coi khoi item. Tra ve (ITEM . REMOVED-COUNT)
(defun mto-orphan-prune-item (it / keep removed h)
  (setq keep '() removed 0)
  (foreach h (mto-item-get it 'HANDLES)
    (if (mto-orphan-exists-p h)
      (setq keep (append keep (list h)))
      (setq removed (1+ removed))))
  (list (mto-item-set it 'HANDLES keep) removed))

;; Bo orphan toan DB. Tra ve (DB . REMOVED)
(defun mto-orphan-prune-db (db / out removed res)
  (setq out '() removed 0)
  (foreach it db
    (setq res (mto-orphan-prune-item it))
    (setq out (append out (list (car res))))
    (setq removed (+ removed (cadr res))))
  (list out removed))

;; Bao cao dang chuoi
(defun mto-orphan-report (db / s)
  (setq s (mto-orphan-check-db db))
  (strcat
    "Tong handle : " (itoa (cdr (assoc 'TOTAL s)))
    " | Con song: " (itoa (cdr (assoc 'ALIVE s)))
    " | Mo coi: "    (itoa (cdr (assoc 'ORPHAN s)))
    " | Dong bi anh huong: " (itoa (cdr (assoc 'ITEMS-ORPHAN s)))))

;; ------------------------------------------------------------
;; 2. COMMAND
;; ------------------------------------------------------------

(defun c:MTOORPHAN ( / db stats ans pruned)
  (mto-ui-start "MTOORPHAN" "Kiem tra du lieu mo coi")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq stats (mto-orphan-check-db db))
      (princ (strcat "\n" (mto-orphan-report db)))
      (if (= 0 (cdr (assoc 'ORPHAN stats)))
        (princ "\nKhong co du lieu mo coi.")
        (progn
          (princ "\nLUU Y: chi xoa du lieu MTO (handle), KHONG xoa doi tuong trong DWG.")
          (initget "Y N")
          (setq ans (getkword "\nLoai bo handle mo coi khoi DB? [Y/N] <N>: "))
          (if (= (mto-str-up (if ans ans "N")) "Y")
            (progn
              (setq pruned (mto-orphan-prune-db db))
              (mto-db-save (car pruned))
              (princ (strcat "\nDa loai bo " (itoa (cadr pruned)) " handle mo coi."))
              (princ (strcat "\nDB con " (itoa (mto-db-count (car pruned))) " dong.")))
            (princ "\nGiu nguyen DB."))))))
  (princ))

(princ "\nmto-orphan.lsp loaded.")
(princ)
