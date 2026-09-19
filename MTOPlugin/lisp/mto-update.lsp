;;; ============================================================
;;; mto-update.lsp -- MTO: cap nhat nguoc du lieu vao ban ve (TASK-011)
;;;
;;; Muc tieu: sua du lieu tu dataset roi cap nhat nguoc vao
;;;   - TEXT / MTEXT (DXF 1) qua entmod
;;;   - XData (group -3) qua entmod + APPID
;;;
;;; Nguyen tac an toan:
;;;   - KHONG sua doi tuong khong co handle hop le
;;;   - KHONG sua doi tuong da bi xoa (orphan)
;;;   - Moi doi tuong nam trong try/catch (vl-catch-all-apply)
;;;   - Co thong bao "Da cap nhat thanh cong X doi tuong"
;;;
;;; Logic thuan (testable headless):
;;;   mto-upd-supported-p     -- entity sua duoc?
;;;   mto-upd-get-value       -- noi dung hien tai
;;;   mto-upd-set-value       -- dat noi dung moi
;;;   mto-upd-apply-item      -- ap gia tri cho moi handle cua item
;;;   mto-upd-ensure-appid    -- dang ky APPID cho XData
;;;   mto-upd-xdata-set/get   -- ghi/doc XData
;;;   mto-upd-batch           -- cap nhat hang loat
;;;
;;; Command: MTOUPDATE
;;; ============================================================

(vl-load-com)

(setq *MTO-XDATA-APP* "MTO_QTO")

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

;; Entity co sua duoc noi dung khong?
(defun mto-upd-supported-p (en / ty)
  (if (null en) nil
    (progn
      (setq ty (mto-str-up (cdr (assoc 0 (entget en)))))
      (or (= ty "TEXT") (= ty "MTEXT")))))

;; Noi dung hien tai (DXF 1)
(defun mto-upd-get-value (en / r)
  (if (mto-upd-supported-p en)
    (cdr (assoc 1 (entget en)))
    nil))

;; Dat noi dung moi. Tra ve T/nil.
(defun mto-upd-set-value (en val / d r)
  (if (or (null en) (null val)) nil
    (if (not (mto-upd-supported-p en)) nil
      (progn
        (setq d (entget en))
        (setq r (vl-catch-all-apply
                  'entmod
                  (list (subst (cons 1 val) (assoc 1 d) d))))
        (if (vl-catch-all-error-p r) nil (if r t nil))))))

;; ------------------------------------------------------------
;; 2. XDATA
;; ------------------------------------------------------------

(defun mto-upd-ensure-appid (name)
  (if (not (tblsearch "APPID" name))
    ;; APPID CAN du DXF subclass markers, neu thieu thi entmake tra nil
    ;; (cung loai loi nhu MTEXT thieu (100 . "AcDbMText"))
    (entmake (list '(0 . "APPID")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbRegAppTableRecord")
                   (cons 2 name)
                   '(70 . 0))))
  name)

;; Ghi mot gia tri chuoi vao XData cua entity
(defun mto-upd-xdata-set (en appname val / r)
  (if (or (null en) (null appname)) nil
    (progn
      (mto-upd-ensure-appid appname)
      (setq r (vl-catch-all-apply
                '(lambda ( / d)
                   (setq d (entget en))
                   ;; bo -3 cu cua appname nay (neu co) roi them moi
                   (entmod (append
                             (vl-remove-if
                               '(lambda (x)
                                  (and (= (car x) -3)
                                       (equal (car (cadr x)) appname)))
                               d)
                             (list (list -3 (list appname (cons 1000 val)))))))))
      (if (vl-catch-all-error-p r) nil (if r t nil)))))

;; Doc gia tri chuoi tu XData
(defun mto-upd-xdata-get (en appname / d xd rec)
  (if (or (null en) (null appname)) nil
    (progn
      (setq d (vl-catch-all-apply 'entget (list en (list appname))))
      (if (or (vl-catch-all-error-p d) (null d)) nil
        (progn
          (setq xd (cdr (assoc -3 d)))       ; ((APPNAME (1000 . "VAL")))
          (if (null xd) nil
            (progn
              (setq rec (cdr (car xd)))      ; ((1000 . "VAL"))
              (cdr (assoc 1000 rec)))))))))

;; ------------------------------------------------------------
;; 3. CAP NHAT THEO ITEM / HANG LOAT
;; ------------------------------------------------------------

;; Ap gia tri moi cho MOI handle con song cua item.
;; Tra ve (THANH-CONG . THAT-BAI)
(defun mto-upd-apply-item (it newval / ok fail en)
  (setq ok 0 fail 0)
  (foreach h (mto-item-get it 'HANDLES)
    (setq en (mto-find-resolve h))
    (if (and en (mto-upd-set-value en newval))
      (setq ok (1+ ok))
      (setq fail (1+ fail))))
  (cons ok fail))

;; Cap nhat hang loat. `pairs` = list (item . gia-tri-moi)
;; Tra ve alist: OK / FAIL / ITEMS
(defun mto-upd-batch (pairs / ok fail items res)
  (setq ok 0 fail 0 items 0)
  (foreach p pairs
    (setq res (mto-upd-apply-item (car p) (cdr p)))
    (setq ok (+ ok (car res)))
    (setq fail (+ fail (cdr res)))
    (setq items (1+ items)))
  (list (cons 'OK ok) (cons 'FAIL fail) (cons 'ITEMS items)))

;; ------------------------------------------------------------
;; 4. COMMAND
;; ------------------------------------------------------------

(defun c:MTOUPDATE ( / db idx pick it newval res e0)
  (mto-ui-start "MTOUPDATE" "Cap nhat TEXT / MTEXT + ghi XData")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (princ "\nCac dong trong DB:")
      (setq idx (mto-find-build-index db))
      (foreach p idx
        (princ (strcat "\n  " (itoa (car p)) ". "
                       (mto-item-get (cdr p) 'NAME)
                       " | handle song: "
                       (itoa (length (mto-find-alive-handles (cdr p)))))))
      (setq pick (getint "\nChon STT dong can cap nhat: "))
      (if pick
        (progn
          (setq it (mto-find-by-index db pick))
          (if (null it)
            (princ "\nSTT khong hop le.")
            (progn
              (princ (strcat "\nDong: " (mto-item-get it 'NAME)))
              ;; LUU Y: AutoLISP KHONG co `let` -> dung setq voi bien local
              (setq e0 (mto-find-resolve (car (mto-item-get it 'HANDLES))))
              (princ (strcat "\nGia tri hien tai (handle dau): "
                             (if e0
                               (if (mto-upd-get-value e0) (mto-upd-get-value e0) "(khong phai TEXT)")
                               "(mo coi)")))
              (setq newval (getstring T "\nGia tri moi (Enter = huy): "))
              (if (or (null newval) (= newval ""))
                (princ "\nDa huy.")
                (progn
                  (setq res (mto-upd-apply-item it newval))
                  (princ (strcat "\nDa cap nhat thanh cong " (itoa (car res)) " doi tuong."))
                  (if (> (cdr res) 0)
                    (princ (strcat " Bo qua " (itoa (cdr res)) " (mo coi hoac khong phai TEXT)")))
                  ;; ghi XData de truy vet
                  (foreach h (mto-item-get it 'HANDLES)
                    (setq e (mto-find-resolve h))
                    (if e (mto-upd-xdata-set e *MTO-XDATA-APP* newval)))
                  (princ "\nDa ghi XData truy vet."))))))
        (princ "\nDa huy."))))
  (princ))

;; Lenh tien ich: ghi/kiem tra XData tren mot doi tuong
(defun c:MTOXCHECK ( / e v)
  (setq e (car (entsel "\nChon doi tuong de kiem tra XData: ")))
  (if e
    (progn
      (setq v (mto-upd-xdata-get e *MTO-XDATA-APP*))
      (if v
        (princ (strcat "\nXData [" *MTO-XDATA-APP* "]: " v))
        (princ "\nKhong co XData MTO tren doi tuong nay."))))
  (princ))

(princ "\nmto-update.lsp loaded.")
(princ)
