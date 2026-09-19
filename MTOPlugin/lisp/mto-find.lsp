;;; ============================================================
;;; mto-find.lsp -- MTO: tim & zoom nguoc ve doi tuong (TASK-010)
;;;
;;; Muc tieu: tu mot dong ket qua (hoac handle) -> tim doi tuong THUC tren
;;; ban ve -> chon (highlight) va zoom toi no.  "Bang -> ban ve".
;;;
;;; KHONG dung ActiveX (accoreconsole khong co): dung lenh ZOOM _O + sssetfirst.
;;;
;;; Logic thuan (testable headless):
;;;   mto-find-resolve        -- handle -> ename (chi khi con song)
;;;   mto-find-alive-handles  -- loc handle con song cua item
;;;   mto-find-build-index    -- danh muc STT -> item
;;;   mto-find-by-index       -- tra item theo STT
;;;   mto-find-search         -- tim theo ten/loai/he/handle
;;;   mto-find-matches-p      -- mot item co khop tu khoa?
;;;
;;; Tac dong ban ve:
;;;   mto-find-select-handle  -- chon doi tuong
;;;   mto-find-zoom-handle    -- zoom toi doi tuong
;;;   mto-find-zoom-item      -- zoom toi doi tuong dau tien con song cua item
;;;
;;; Command: MTOFIND
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

;; Handle -> ename, CHI khi doi tuong con song.
;; (handent van resolve entity da entdel -> phai kiem them entget)
(defun mto-find-resolve (h / res got)
  (if (or (null h) (= h "")) nil
    (progn
      (setq res (vl-catch-all-apply 'handent (list h)))
      (if (or (vl-catch-all-error-p res) (null res))
        nil
        (progn
          (setq got (vl-catch-all-apply 'entget (list res)))
          (if (or (vl-catch-all-error-p got) (null got)) nil res))))))

;; Danh sach handle con song cua item
(defun mto-find-alive-handles (it / out)
  (setq out '())
  (foreach h (mto-item-get it 'HANDLES)
    (if (mto-find-resolve h)
      (setq out (append out (list h)))))
  out)

;; Danh muc: alist ((STT . item) ...) theo thu tu da sap xep nhu bang
(defun mto-find-build-index (db / idx out)
  (setq idx 0 out '())
  (foreach it (mto-db-sort db)
    (setq idx (1+ idx))
    (setq out (append out (list (cons idx it)))))
  out)

(defun mto-find-by-index (db n / idx found)
  (setq idx (mto-find-build-index db))
  (setq found (assoc n idx))
  (if found (cdr found) nil))

;; Mot item co khop tu khoa (khong phan biet hoa/thuong)?
(defun mto-find-matches-p (it q / up fields f hit)
  (setq up (mto-str-up q))
  (setq fields (list
                 (mto-item-get it 'NAME)
                 (mto-item-get it 'TYPE)
                 (mto-item-get it 'CATEGORY)
                 (mto-item-get it 'LAYER)
                 (mto-item-get it 'PREFIX)
                 (mto-item-get it 'DESCRIPTION)
                 (mto-item-get it 'SOURCEOBJECT)))
  ;; khop theo handle cung tinh
  (setq fields (append fields (mto-item-get it 'HANDLES)))
  (setq hit nil)
  (foreach f fields
    (if (and (null hit) f (= (type f) 'STR) (/= f ""))
      (if (vl-string-search up (mto-str-up f))
        (setq hit t))))
  (if hit t nil))

;; Tim tat ca item khop tu khoa
(defun mto-find-search (db q / out)
  (setq out '())
  (if (and q (/= (mto-str-trim q) ""))
    (foreach it db
      (if (mto-find-matches-p it q)
        (setq out (append out (list it))))))
  out)

;; ------------------------------------------------------------
;; 2. TAC DONG BAN VE (khong dung ActiveX)
;; ------------------------------------------------------------

;; Chon (highlight) doi tuong theo handle. Tra ve T/nil.
(defun mto-find-select-handle (h / e ss)
  (setq e (mto-find-resolve h))
  (if (null e) nil
    (progn
      (setq ss (ssadd))
      (ssadd e ss)
      (sssetfirst nil ss)
      t)))

;; Zoom toi doi tuong theo handle. Dung lenh ZOOM _O (khong can ActiveX).
(defun mto-find-zoom-handle (h / e r)
  (setq e (mto-find-resolve h))
  (if (null e) nil
    (progn
      (setq r (vl-catch-all-apply
                '(lambda () (command "_.ZOOM" "_O" e ""))))
      (if (vl-catch-all-error-p r) nil t))))

;; Zoom toi doi tuong dau tien con song cua item. Tra ve handle da zoom hoac nil.
(defun mto-find-zoom-item (it / hs h done)
  (setq hs (mto-find-alive-handles it))
  (setq done nil)
  (foreach h hs
    (if (null done)
      (if (mto-find-zoom-handle h)
        (setq done h))))
  done)

;; ------------------------------------------------------------
;; 3. COMMAND
;; ------------------------------------------------------------

(defun mto-find-print-hits (hits / idx it)
  (setq idx 0)
  (foreach it hits
    (setq idx (1+ idx))
    (princ (strcat "\n" (itoa idx) ". "
                   (mto-item-get it 'CATEGORY) " | "
                   (mto-item-get it 'TYPE) " | "
                   (mto-item-get it 'NAME)
                   " | QTY=" (mto-num->str (mto-item-get it 'NETQTY))
                   " | handle=" (itoa (length (mto-item-get it 'HANDLES))))))
  (princ))

(defun c:MTOFIND ( / db q hits pick n idx it h alive)
  (mto-ui-start "MTOFIND" "Tim doi tuong theo STT / tu khoa")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq q (mto-str-trim (getstring T "\nNhap STT hoac tu khoa (ten/loai/he/handle): ")))
      (if (= q "")
        (princ "\nDa huy.")
        (progn
          ;; uu tien STT neu la so va ton tai
          (setq n (atoi q))
          (setq it (if (and (> n 0) (= q (itoa n))) (mto-find-by-index db n) nil))

          (if it
            (progn
              (princ (strcat "\n[STT " q "] " (mto-item-get it 'NAME)))
              (setq alive (mto-find-alive-handles it))
              (if (null alive)
                (princ "\nCANH BAO: moi handle deu mo coi (doi tuong da bi xoa).")
                (progn
                  (princ (strcat "\nCo " (itoa (length alive)) " doi tuong con song."))
                  (setq h (mto-find-zoom-item it))
                  (if h
                    (progn
                      (mto-find-select-handle h)
                      (princ (strcat "\nDa zoom + chon doi tuong handle " h ".")))
                    (princ "\nKhong zoom duoc (moi truong khong ho tro ZOOM)."))))))
            (progn
              (setq hits (mto-find-search db q))
              (if (null hits)
                (princ (strcat "\nKhong tim thay dong nao khop '" q "'."))
                (progn
                  (princ (strcat "\nTim thay " (itoa (length hits)) " dong:"))
                  (mto-find-print-hits hits)
                  (setq pick (getint "\nChon so thu tu de zoom (Enter = bo qua): "))
                  (if pick
                    (progn
                      (setq it (nth (1- pick) hits))
                      (if it
                        (progn
                          (setq h (mto-find-zoom-item it))
                          (if h
                            (progn
                              (mto-find-select-handle h)
                              (princ (strcat "\nDa zoom + chon handle " h ".")))
                            (princ "\nKhong con doi tuong nao song de zoom.")))
                        (princ "\nSo thu tu khong hop le.")))))))))))
  (princ))

;; Lenh tien ich: zoom thang theo handle
(defun c:MTOGOTO ( / h)
  (setq h (mto-str-trim (getstring T "\nNhap handle: ")))
  (if (= h "")
    (princ "\nDa huy.")
    (if (mto-find-zoom-handle h)
      (progn (mto-find-select-handle h) (princ (strcat "\nDa zoom + chon " h ".")))
      (princ "\nKhong tim thay doi tuong con song voi handle nay.")))
  (princ))

(princ "\nmto-find.lsp loaded.")
(princ)
