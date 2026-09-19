;;; ============================================================
;;; mto-block.lsp -- MTO: nhan dang & dem BLOCK (TASK-003)
;;;
;;; Muc tieu:
;;;   - Chon mot block mau -> lay ten block
;;;   - Tim tat ca block cung ten trong ban ve (ssget "_X" + filter INSERT)
;;;   - Dem tu dong
;;;   - Cho phep MANUAL COUNT (bo sung/thuc te ngoai ban ve)
;;;   - TOTAL = AUTO_COUNT + MANUAL_ADJUSTMENT
;;;   - Luu ro AutoCount / ManualCount / FinalCount
;;;
;;; Logic thuan (testable headless):
;;;   mto-blk-name                -- ten block tu entity
;;;   mto-blk-anonymous-p         -- block an danh (*U, *D...)
;;;   mto-blk-build-filter        -- DXF filter
;;;   mto-blk-count               -- dem theo ten (+ layer)
;;;   mto-blk-handles             -- danh sach handle
;;;   mto-blk-classify            -- block -> item
;;;   mto-blk-apply-manual        -- dat MANQTY va tinh lai
;;;   mto-blk-scan                -- nap vao db
;;;   mto-blk-count-all           -- dem tat ca block (nhom theo ten)
;;;
;;; Command: MTOBLK, MTOBLKMAN
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

;; Ten block tu entity INSERT (DXF 2)
(defun mto-blk-name (en / d n)
  (if (null en) nil
    (progn
      (setq d (entget en))
      (setq n (cdr (assoc 2 d)))
      (if n (mto-str-trim n) nil))))

;; Block an danh (AutoCAD tao tu dong: *U, *D, *T, *X...)
(defun mto-blk-anonymous-p (name)
  (if (or (null name) (= name "")) nil
    (= (substr name 1 1) "*")))

;; Entity la INSERT?
(defun mto-blk-entity-p (en / ty)
  (if (null en) nil
    (progn
      (setq ty (mto-str-up (cdr (assoc 0 (entget en)))))
      (= ty "INSERT"))))

;; Filter DXF cho ten block (+ layer tuy chon)
(defun mto-blk-build-filter (name layerFilter / f)
  (setq f (list (cons 0 "INSERT") (cons 2 name)))
  (if (and layerFilter (/= layerFilter ""))
    (setq f (append f (list (cons 8 layerFilter)))))
  f)

;; Dem block theo ten (layerFilter = nil nghia la moi layer)
(defun mto-blk-count (name layerFilter / ss)
  (if (or (null name) (= name "")) 0
    (progn
      (setq ss (ssget "_X" (mto-blk-build-filter name layerFilter)))
      (if ss (sslength ss) 0))))

;; Danh sach handle cua block theo ten
(defun mto-blk-handles (name layerFilter / ss)
  (if (or (null name) (= name "")) '()
    (progn
      (setq ss (ssget "_X" (mto-blk-build-filter name layerFilter)))
      (mto-sel-ss->handles ss))))

;; Danh sach layer xuat hien cua mot block (co the block nam nhieu layer)
(defun mto-blk-layers (name / ss i n e l lst pair)
  (setq lst '())
  (if (and name (/= name ""))
    (progn
      (setq ss (ssget "_X" (mto-blk-build-filter name nil)))
      (setq i 0 n (if ss (sslength ss) 0))
      (while (< i n)
        (setq e (ssname ss i))
        (if e
          (progn
            (setq l (cdr (assoc 8 (entget e))))
            (setq pair (assoc l lst))
            (if pair
              (setq lst (subst (cons l (1+ (cdr pair))) pair lst))
              (setq lst (append lst (list (cons l 1)))))))
        (setq i (1+ i)))))
  lst)

;; Tao item tu block name + so luong
(defun mto-blk-classify (name autoQty / pfx cat layers layer it)
  (setq pfx   (mto-text-recognize-prefix name))
  (setq cat   (mto-text-category-for-prefix pfx))
  ;; LUU Y: mto-blk-layers tra alist ((LAYER . count) ...) nen phai lay
  ;; (car (car layers)) -- (car layers) la DOTTED PAIR, khong phai chuoi.
  (setq layers (mto-blk-layers name))
  (setq layer  (if layers (car (car layers)) ""))

  (setq it (mto-item-new cat pfx name))
  (setq it (mto-item-set it 'PREFIX pfx))
  (setq it (mto-item-set it 'DESCRIPTION name))
  (setq it (mto-item-set it 'SPEC ""))
  (setq it (mto-item-set it 'LAYER (if layer layer "")))
  (setq it (mto-item-set it 'SOURCETYPE *MTO-SRC-BLOCK*))
  (setq it (mto-item-set it 'SOURCEOBJECT name))
  (setq it (mto-item-set it 'UNIT *MTO-UNIT-PCS*))
  (setq it (mto-item-set it 'AUTOQTY (float autoQty)))
  (setq it (mto-item-set it 'MANQTY 0.0))
  (setq it (mto-item-recalc it)))

;; Dat so luong MANUAL va tinh lai (TOTAL = AUTO + MANUAL)
(defun mto-blk-apply-manual (it manualQty)
  (mto-item-recalc (mto-item-set it 'MANQTY (float manualQty))))

;; Cong them MANUAL (thay vi dat de)
(defun mto-blk-add-manual (it delta)
  (mto-item-recalc
    (mto-item-set it 'MANQTY (+ (mto-item-get it 'MANQTY) (float delta)))))

;; Nap mot block (theo ten) vao db
(defun mto-blk-scan (name db layerFilter / cnt hs it)
  (setq cnt (mto-blk-count name layerFilter))
  (setq hs  (mto-blk-handles name layerFilter))
  (setq it  (mto-blk-classify name cnt))
  (foreach h hs (setq it (mto-item-add-handle it h)))
  (mto-db-merge-item db it))

;; Dem TAT CA block trong ban ve, nhom theo ten
;; Tra ve alist ((NAME . count) ...) — bo qua block an danh
(defun mto-blk-count-all (/ ss i n e nm lst pair)
  (setq lst '() i 0)
  (setq ss (ssget "_X" (list (cons 0 "INSERT"))))
  (setq n (if ss (sslength ss) 0))
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (progn
        (setq nm (mto-blk-name e))
        (if (and nm (not (mto-blk-anonymous-p nm)))
          (progn
            (setq pair (assoc nm lst))
            (if pair
              (setq lst (subst (cons nm (1+ (cdr pair))) pair lst))
              (setq lst (append lst (list (cons nm 1)))))))))
    (setq i (1+ i)))
  (vl-sort lst '(lambda (a b) (< (car a) (car b)))))

;; Nap TAT CA block vao db
(defun mto-blk-scan-all (db / pairs)
  (setq pairs (mto-blk-count-all))
  (foreach p pairs
    (setq db (mto-blk-scan (car p) db nil)))
  db)

;; ------------------------------------------------------------
;; 2. COMMAND
;; ------------------------------------------------------------

;; Chon mot block mau tren ban ve
(defun mto-blk-pick-sample ( / e nm)
  (setq e (car (entsel "\nChon mot BLOCK mau: ")))
  (if (null e)
    (progn (princ "\nKhong chon duoc doi tuong.") nil)
    (if (not (mto-blk-entity-p e))
      (progn (princ "\nDoi tuong khong phai BLOCK (INSERT).") nil)
      (progn
        (setq nm (mto-blk-name e))
        (princ (strcat "\nBlock: " nm))
        nm))))

(defun c:MTOBLK ( / nm layerFilter cnt man it db)
  (mto-ui-start "MTOBLK" "Dem block theo ten")
  (setq nm (mto-blk-pick-sample))
  (if nm
    (progn
      (if (mto-blk-anonymous-p nm)
        (princ "\nCANH BAO: day la block an danh (*).")

        (progn
          (setq layerFilter (mto-str-trim
                             (getstring T "\nGioi han layer (wildcard, Enter = tat ca): ")))
          (if (= layerFilter "") (setq layerFilter nil))

          (setq cnt (mto-blk-count nm layerFilter))
          (princ (strcat "\nAUTO COUNT = " (itoa cnt)))

          (initget 4) ; cho phep so, khong am
          (setq man (getreal "\nMANUAL ADJUSTMENT (so bo sung/thuc te, Enter = 0): "))
          (if (null man) (setq man 0.0))

          (setq it (mto-blk-classify nm cnt))
          (setq it (mto-blk-apply-manual it man))

          ;; gan handle
          (foreach h (mto-blk-handles nm layerFilter)
            (setq it (mto-item-add-handle it h)))

          (setq db (mto-db-merge-item (mto-db-load) it))
          (mto-db-save db)

          (princ (strcat "\n--- KET QUA ---"))
          (princ (strcat "\nBlock      : " nm))
          (princ (strcat "\nAutoCount  : " (itoa (fix (mto-item-get it 'AUTOQTY)))))
          (princ (strcat "\nManualCount: " (mto-num->str (mto-item-get it 'MANQTY))))
          (princ (strcat "\nFinalCount : " (mto-num->str (mto-item-get it 'QTY))))
          (princ (strcat "\nCategory   : " (mto-item-get it 'CATEGORY)))
          (princ (strcat "\nDB co " (itoa (mto-db-count db)) " dong."))))))
  (princ))

;; Dieu chinh manual cho mot dong da co trong DB (theo TYPE hoac NAME)
(defun c:MTOBLKMAN ( / key qty db hit found)
  (mto-ui-start "MTOBLKMAN" "Dieu chinh so luong thu cong")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOBLK hoac MTOTEXT truoc.")
    (progn
      (setq key (mto-str-trim (getstring T "\nNhap TYPE hoac NAME can dieu chinh: ")))
      (setq hit nil)
      (foreach it db
        (if (and (null hit)
                 (or (= (mto-item-get it 'TYPE) key)
                     (= (mto-item-get it 'NAME) key)))
          (setq hit it)))
      (if (null hit)
        (princ (strcat "\nKhong tim thay dong nao khop '" key "'."))
        (progn
          (princ (strcat "\nDong: " (mto-item-get hit 'NAME)
                         " | Auto=" (mto-num->str (mto-item-get hit 'AUTOQTY))))
          (setq qty (getreal "\nManual adjustment moi: "))
          (if qty
            (progn
              (setq hit (mto-blk-apply-manual hit qty))
              (setq db (mto-db-merge-replace db hit))
              (mto-db-save db)
              (princ (strcat "\nDa cap nhat. FinalCount = "
                             (mto-num->str (mto-item-get hit 'QTY))))))))))
  (princ))

;; Thay the mot dong theo key (dung cho dieu chinh)
(defun mto-db-merge-replace (db it / key out x done)
  (setq key (mto-item-key it) out '() done nil)
  (foreach x db
    (if (and (not done) (= (mto-item-key x) key))
      (progn (setq out (append out (list it))) (setq done t))
      (setq out (append out (list x)))))
  (if done out (append out (list it))))

(princ "\nmto-block.lsp loaded.")
(princ)
