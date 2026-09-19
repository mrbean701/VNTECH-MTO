;;; ============================================================
;;; mto-table.lsp -- MTO: tao AutoCAD Table tu dataset (TASK-009)
;;;
;;; Muc tieu: tao bang tren ban ve tu ket qua MTO, co:
;;;   STT | CATEGORY | TYPE | DESCRIPTION | QTY | LENGTH | UNIT | LAYER | NOTES
;;; va SUBTOTAL theo CATEGORY + GRAND TOTAL.
;;;
;;; HAI BACKEND (co ly do):
;;;   1. NATIVE TABLE qua ActiveX (vla-AddTable) -- dep, co style,
;;;      CHI co tren AutoCAD day du (accoreconsole KHONG co ActiveX).
;;;   2. GRID bang TEXT + LINE (entmake) -- luon hoat dong o moi moi truong
;;;      ke ca accoreconsole => TESTABLE HEADLESS.
;;;   Chon tu dong: co ActiveX -> native; khong -> grid.
;;;
;;; Logic thuan (testable headless):
;;;   mto-table-columns       -- dinh nghia cot (key . width)
;;;   mto-table-total-width   -- tong do rong
;;;   mto-table-header-cells  -- tieu de
;;;   mto-table-item-cells    -- o cua mot item
;;;   mto-table-subtotal-by   -- subtotal theo khoa
;;;   mto-table-build-rows    -- header + data + subtotal + grand total
;;;   mto-table-grid-entities -- mo ta entity grid (khong tao)
;;;
;;; Command: MTOTABLE
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. DINH NGHIA COT
;;
;; LUU Y (loi da gap): chu bi "long vao nhau" khi ve bang.
;; Nguyen nhan: chieu rong cot KHONG DU cho noi dung that
;;   - cot TYPE rong 14 nhung "Camera Cable" (12 ky tu) can ~16.8
;;   - cot LAYER rong 14, cung noi dung tren
;;   => chu tran ra ngoai o, de len cot ben canh.
;; Cach chua: (a) tang chieu rong cot, (b) giam chieu cao chu,
;;            (c) TU DONG CAT bot noi dung neu van qua dai.
;; ------------------------------------------------------------

(setq *MTO-TABLE-COLS*
  '(("STT"         .  7.0)
    ("CATEGORY"    . 18.0)
    ("TYPE"        . 18.0)
    ("DESCRIPTION" . 36.0)
    ("QTY"         .  9.0)
    ("LENGTH"      . 14.0)
    ("UNIT"        .  8.0)
    ("LAYER"       . 18.0)
    ("NOTES"       . 18.0)))

(setq *MTO-TABLE-ROW-H* 6.0)   ; chieu cao dong (>= 2.5 x chieu cao chu)
(setq *MTO-TABLE-TXT-H* 2.0)   ; chieu cao chu
(setq *MTO-TABLE-PAD-X* 0.9)   ; le trai/phai trong o
(setq *MTO-TABLE-PAD-Y* 2.6)   ; khoang cach tu day o len chan chu

;; He so chieu rong trung binh cua 1 ky tu so voi chieu cao chu
;; (font chu thuong: ~0.6 x chieu cao)
(setq *MTO-TABLE-CHAR-W* 0.62)

;; So ky tu toi da vua trong cot co chieu rong w
(defun mto-table-max-chars (w / usable)
  (setq usable (- w (* 2.0 *MTO-TABLE-PAD-X*)))
  (if (<= usable 0.0)
    1
    (fix (/ usable (* *MTO-TABLE-TXT-H* *MTO-TABLE-CHAR-W*)))))

;; Cat bot chuoi cho vua maxc ky tu (them "." neu bi cat)
(defun mto-table-fit (s maxc / n)
  (if (null s) ""
    (progn
      (setq n (strlen s))
      (cond
        ((<= n maxc) s)
        ((<= maxc 2) (substr s 1 maxc))
        (t (strcat (substr s 1 (- maxc 1)) "."))))))

;; Chuan hoa 1 o de VE: ep ve chuoi + CAT cho vua chieu rong cot
(defun mto-table-cell-draw (c colIdx / w)
  (setq w (mto-table-col-width colIdx))
  (mto-table-fit (mto-table-cell->str c) (mto-table-max-chars w)))

(defun mto-table-keys ()
  (mapcar 'car *MTO-TABLE-COLS*))

(defun mto-table-total-width ( / w)
  (setq w 0.0)
  (foreach c *MTO-TABLE-COLS* (setq w (+ w (cdr c))))
  w)

;; Tra ve do rong cua cot thu i (0-based)
(defun mto-table-col-width (i / w)
  (setq w (nth i *MTO-TABLE-COLS*))
  (if w (cdr w) 0.0))

;; ------------------------------------------------------------
;; 2. LOGIC THUAN
;; ------------------------------------------------------------

(defun mto-table-header-cells ()
  (mapcar 'car *MTO-TABLE-COLS*))

(defun mto-table-item-cells (it idx / qty len)
  (setq qty (mto-item-get it 'NETQTY))
  (setq len (mto-item-get it 'LENGTH))
  (list
    (itoa idx)
    (mto-item-get it 'CATEGORY)
    (mto-item-get it 'TYPE)
    (mto-item-get it 'NAME)
    (mto-num->str qty)
    (if (> len 0.0) (mto-num->str len) "")
    (mto-item-get it 'UNIT)
    (mto-item-get it 'LAYER)
    (mto-item-get it 'NOTES)))

;; Subtotal theo mot khoa: alist ((value . qty) ...)
(defun mto-table-subtotal-by (db key / out pair)
  (setq out '())
  (foreach it db
    (setq pair (assoc (mto-item-get it key) out))
    (if pair
      (setq out (subst (cons (car pair) (+ (cdr pair) (mto-item-get it 'NETQTY))) pair out))
      (setq out (append out (list (cons (mto-item-get it key)
                                        (mto-item-get it 'NETQTY)))))))
  out)

;; Tao toan bo dong cua bang.
;; Tra ve list of rows; moi row = (TYPE-ROW . CELLS)
;;   TYPE-ROW: "H" header, "D" du lieu, "S" subtotal, "G" grand total
(defun mto-table-build-rows (db / rows sorted idx curCat subQty subLen)
  (setq rows '())
  (setq sorted (mto-db-sort db))

  ;; header
  (setq rows (append rows (list (cons "H" (mto-table-header-cells)))))

  (setq idx 0 curCat nil subQty 0.0 subLen 0.0)

  (foreach it sorted
    ;; chuyen he -> chot subtotal he truoc
    (if (and curCat (/= curCat (mto-item-get it 'CATEGORY)))
      (progn
        (setq rows (append rows
          (list (cons "S" (list "" (strcat "Subtotal " curCat) "" "" 
                                (mto-num->str subQty) (mto-num->str subLen) "" "" "")))))
        (setq subQty 0.0 subLen 0.0)))

    (setq curCat (mto-item-get it 'CATEGORY))
    (setq idx (1+ idx))
    (setq subQty (+ subQty (mto-item-get it 'NETQTY)))
    (setq subLen (+ subLen (mto-item-get it 'LENGTH)))
    (setq rows (append rows (list (cons "D" (mto-table-item-cells it idx))))))

  ;; chot subtotal he cuoi
  (if curCat
    (setq rows (append rows
      (list (cons "S" (list "" (strcat "Subtotal " curCat) "" ""
                            (mto-num->str subQty) (mto-num->str subLen) "" "" ""))))))

  ;; grand total
  (setq rows (append rows
    (list (cons "G" (list "" "TONG CONG" "" ""
                          (mto-num->str (mto-db-total-net db))
                          (mto-num->str (mto-db-total-length db)) "" "" "")))))
  rows)

;; Vi tri goc (goc trai-duoi) cua o [row][col]
;; pt = (x y), row 0 la dong dau (tren cung)
(defun mto-table-cell-point (pt row col / x y i w rows)
  (setq x (car pt))
  (setq i 0)
  (while (< i col)
    (setq x (+ x (mto-table-col-width i)))
    (setq i (1+ i)))
  (setq y (- (cadr pt) (* row *MTO-TABLE-ROW-H*)))
  (list x y))

;; ------------------------------------------------------------
;; 3. BACKEND 1: GRID TEXT + LINE (entmake) -- luon chay duoc
;; ------------------------------------------------------------

;; Mo ta so entity grid se tao (khong tao) -- de test logic
;; LUU Y: chi dem o CO NOI DUNG, khop dung voi hanh vi cua mto-table-draw-grid
;; (o rong khong ve TEXT).
;; Tra ve: (TEXT-COUNT . LINE-COUNT)
(defun mto-table-grid-entities (rows / nRows textCount lineCount)
  (setq nRows (length rows))
  (setq textCount 0)
  (foreach r rows
    (foreach c (cdr r)
      (if (and c (/= c ""))
        (setq textCount (1+ textCount)))))
  ;; duong ke: 1 ngang moi dong + 1 duoi cung, 1 doc moi cot + 1 phai cung
  (setq lineCount (+ (1+ nRows) (1+ (length (mto-table-keys)))))
  (cons textCount lineCount))

(defun mto-tbl-mktext (layer x y s h / ent)
  (entmake (list '(0 . "TEXT") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x y 0.0))
                 (cons 1 (if s s ""))
                 (cons 40 h)))
  (entlast))

(defun mto-tbl-mkline (layer x1 y1 x2 y2)
  (entmake (list '(0 . "LINE") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x1 y1 0.0))
                 (cons 11 (list x2 y2 0.0))))
  (entlast))

(defun mto-table-draw-grid (rows pt layer / tw nRows r rowIdx colIdx p cells n txt)
  (setq tw (mto-table-total-width))
  (setq nRows (length rows))

  ;; duong ngang
  (setq rowIdx 0)
  (while (<= rowIdx nRows)
    (mto-tbl-mkline layer
      (car pt) (- (cadr pt) (* rowIdx *MTO-TABLE-ROW-H*))
      (+ (car pt) tw) (- (cadr pt) (* rowIdx *MTO-TABLE-ROW-H*)))
    (setq rowIdx (1+ rowIdx)))

  ;; duong doc
  (setq colIdx 0)
  (setq n (length (mto-table-keys)))
  (while (<= colIdx n)
    (setq p (mto-table-cell-point pt 0 colIdx))
    (mto-tbl-mkline layer
      (car p) (cadr pt)
      (car p) (- (cadr pt) (* nRows *MTO-TABLE-ROW-H*)))
    (setq colIdx (1+ colIdx)))

  ;; chu trong o
  (setq rowIdx 0)
  (setq n 0)
  (foreach r rows
    (setq cells (cdr r))
    (setq colIdx 0)
    (foreach c cells
      (setq p (mto-table-cell-point pt rowIdx colIdx))
      ;; CAT noi dung cho vua chieu rong cot (tranh chu de len cot ben canh),
      ;; le trai *MTO-TABLE-PAD-X*, chan chu cach day o *MTO-TABLE-PAD-Y*
      (setq txt (mto-table-cell-draw c colIdx))
      (if (and txt (/= txt ""))
        (progn
          (mto-tbl-mktext layer
                          (+ (car p) *MTO-TABLE-PAD-X*)
                          (- (cadr p) *MTO-TABLE-PAD-Y*)
                          txt
                          *MTO-TABLE-TXT-H*)
          (setq n (1+ n))))
      (setq colIdx (1+ colIdx)))
    (setq rowIdx (1+ rowIdx)))
  n)

;; ------------------------------------------------------------
;; 4. BACKEND 2: NATIVE TABLE qua ActiveX (co the khong co)
;; ------------------------------------------------------------

;; ActiveX co san khong? (accoreconsole: KHONG)
(defun mto-table-activex-available-p ( / r)
  ;; BAT BUOC: nap COM truoc khi dung vla-*/vlax-* (neu khong se "no function definition")
  (if (not (member 'vlax-get-acad-object (atoms-family 1)))
    (vl-catch-all-apply 'vl-load-com (list)))
  (setq r (vl-catch-all-apply 'vlax-get-acad-object (list)))
  (if (vl-catch-all-error-p r) nil (if r t nil)))

;; Chuyen MOI gia tri o thanh CHUOI.
;; vla-SetText YEU CAU chuoi; truyen nil/so -> loi (tung gay bang RONG).
(defun mto-table-cell->str (c)
  (cond
    ((null c) "")
    ((= (type c) 'STR) c)
    ((= (type c) 'INT) (itoa c))
    ((= (type c) 'REAL) (mto-num->str c))
    (t (vl-princ-to-string c))))

;; Mang chieu rong tung cot (vla-AddTable YEU CAU MANG, khong phai 1 so)
;; LUU Y: vlax-make-safearray / safearray-put-element co the nem exception COM
;; -> phai boc vl-catch-all-apply de khong lam sap AutoCAD (e0434352).
(defun mto-table-colwidth-array ( / n r)
  (setq n (length *MTO-TABLE-COLS*))
  (setq r (vl-catch-all-apply
    '(lambda ( / a j)
       (setq a (vlax-make-safearray vlax-vbDouble (cons 0 (1- n))))
       (setq j 0)
       (foreach c *MTO-TABLE-COLS*
         (vlax-safearray-put-element a j (float (cdr c)))
         (setq j (1+ j)))
       a)))
  (if (vl-catch-all-error-p r)
    (progn
      (princ (strcat "\n[TABLE] Khong tao duoc mang chieu rong cot: "
                     (vl-catch-all-error-message r)))
      nil)
    r))

;; Thu tao native table. Tra ve table-object neu THANH CONG THAT SU, nil neu khong.
;;
;; LUU Y QUAN TRONG: truoc day ham nay boc vl-catch-all-apply quanh vla-SetText
;; nhung KHONG kiem tra ket qua -> loi bi nuot am tham -> bang tao ra nhung
;; TOAN BO O RONG. Nay: (a) chuan hoa cell thanh chuoi, (b) ColWidths la mang,
;; (c) sau khi set thi DOC LAI o (0,0) de xac nhan that su co du lieu.
(defun mto-table-add-native (rows pt layer / acad doc ms nRows nCols tbl r rowIdx colIdx cells txt chk)
  (if (not (mto-table-activex-available-p))
    nil
    (progn
      (setq r (vl-catch-all-apply
        '(lambda ( / ms tbl)
           (setq ms (vla-get-ModelSpace
                      (vla-get-ActiveDocument (vlax-get-acad-object))))
           (setq nRows (length rows))
           (setq nCols (length (mto-table-keys)))
           ;; AddTable(InsertionPoint, NumRows, NumColumns, RowHeight, ColWidths[])
           (setq tbl (vla-AddTable ms
                                   (vlax-3d-point (car pt) (cadr pt) 0.0)
                                   nRows nCols
                                   *MTO-TABLE-ROW-H*
                                   (mto-table-colwidth-array)))
           ;; gan layer cho bang (neu co)
           (if (and layer (/= layer ""))
             (vl-catch-all-apply 'vla-put-Layer (list tbl layer)))
           ;; do du lieu vao tung o
           (setq rowIdx 0)
           (foreach rr rows
             (setq cells (cdr rr))
             (setq colIdx 0)
             (foreach c cells
               (setq txt (mto-table-cell->str c))
               (vl-catch-all-apply 'vla-SetText (list tbl rowIdx colIdx txt))
               (setq colIdx (1+ colIdx)))
             (setq rowIdx (1+ rowIdx)))
           ;; cap nhat hien thi
           (vl-catch-all-apply 'vla-Update (list tbl))
           tbl)))
      (if (vl-catch-all-error-p r)
        (progn (princ (strcat "\n[NATIVE] Loi tao bang: "
                              (vl-catch-all-error-message r)))
               nil)
        (progn
          (setq tbl r)
          ;; XAC NHAN THAT: doc lai o (0,0) - phai co chu
          (setq chk (vl-catch-all-apply 'vla-GetText (list tbl 0 0)))
          (if (or (vl-catch-all-error-p chk) (null chk) (= (mto-str-trim chk) ""))
            (progn
              (princ "\n[NATIVE] Bang tao ra nhung O RONG -> xoa va dung GRID.")
              (vl-catch-all-apply 'vla-Delete (list tbl))
              nil)
            tbl))))))

;; ------------------------------------------------------------
;; 5. COMMAND
;; ------------------------------------------------------------

(defun c:MTOTABLE ( / db rows pt layer useNative n mode)
  (mto-ui-start "MTOTABLE" "Ve bang khoi luong len ban ve")
  (setq db (mto-db-load))
  (if (mto-db-empty-p db)
    (princ "\nDB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.")
    (progn
      (setq pt (getpoint "\nChon diem goc bang (goc trai-tren): "))
      (if (null pt)
        (princ "\nDa huy.")
        (progn
          (setq layer (mto-str-trim (getstring T "\nLayer cho bang <MTO-TABLE>: ")))
          (if (= layer "") (setq layer "MTO-TABLE"))
          (if (not (tblsearch "LAYER" layer))
            (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                           '(100 . "AcDbLayerTableRecord")
                           (cons 2 layer) '(70 . 0) '(62 . 3) '(6 . "Continuous"))))

          (setq rows (mto-table-build-rows db))
          (setq mode (if (mto-table-activex-available-p) "NATIVE" "GRID"))

          (if (= mode "NATIVE")
            (progn
              (setq useNative (mto-table-add-native rows pt layer))
              (if useNative
                (princ "\nDa tao bang NATIVE (ActiveX Table) - co the sua bang TABLEEDIT.")
                (progn
                  (setq n (mto-table-draw-grid rows pt layer))
                  (princ "\nNative khong dung duoc -> da tao bang dang GRID (TEXT + LINE).")))) 
            (progn
              (setq n (mto-table-draw-grid rows pt layer))
              (princ "\nKhong co ActiveX -> da tao bang dang GRID (TEXT + LINE).")))

          (princ (strcat "\nSo dong: " (itoa (length rows))))
          (princ (strcat "\nLayer: " layer))
          (princ (strcat "\nChe do: " mode))))))
  (princ))

;; ============================================================
;; TU KIEM TRA BANG NATIVE (ActiveX Table)
;;
;; Lenh MTOTESTNATIVE tao mot bang mau tai goc (0,0), doc lai TUNG O
;; va doi chieu voi du lieu gui vao. Dung de kiem chung bang KHONG RONG.
;; Kiem tra xong tu xoa bang mau.
;; ============================================================
(defun c:MTOTESTNATIVE ( / rows tbl i n cells ok fail txt want got)
  (mto-ui-start "MTOTESTNATIVE" "Tu kiem tra bang NATIVE co du lieu")

  (if (not (mto-table-activex-available-p))
    (progn
      (princ "\nKHONG co ActiveX (dang chay accoreconsole?) -> bo qua.")
      (princ "\nTrong AutoCAD day du, lenh nay se kiem tra bang NATIVE."))
    (progn
      ;; Du lieu mau co DU truong hop: chuoi, so, NIL
      (setq rows (list
        (cons "H" (list "STT" "HE" "LOAI" "TEN" "SL" "DAI" "DV" "LAYER" "GHI CHU"))
        (cons "D" (list "1" "ELV" "CAM" "SE.DOME CAMERA" "51" "" "cai" "CCTV" nil))
        (cons "D" (list "2" "Other" "Cable" "Camera Cable" "5" "1286.9135" "mm" "Cable" nil))))

      (princ "\nDang tao bang mau tai (0,0) ...")
      (setq tbl (mto-table-add-native rows (list 0.0 0.0) "MTO-TESTNATIVE"))

      (if (null tbl)
        (progn
          (princ "\nKET QUA: THAT BAI - khong tao duoc bang NATIVE.")
          (princ "\n  -> MTOTABLE se tu dong dung GRID (van co bang, chi khac kieu)."))
        (progn
          (setq ok 0 fail 0)
          (setq i 0)
          (foreach rr rows
            (setq cells (cdr rr))
            (setq n 0)
            (foreach c cells
              (setq want (mto-table-cell->str c))
              (setq got (vl-catch-all-apply 'vla-GetText (list tbl i n)))
              (if (vl-catch-all-error-p got)
                (setq got "<LOI>")
                (setq got (mto-table-cell->str got)))
              (if (= want got)
                (setq ok (1+ ok))
                (progn
                  (setq fail (1+ fail))
                  (if (< fail 6)
                    (princ (strcat "\n  LECH o [" (itoa i) "," (itoa n) "]: gui='"
                                   want "' nhan='" got "'")))))
              (setq n (1+ n)))
            (setq i (1+ i)))

          (princ (strcat "\n\nKET QUA: " (itoa ok) " o DUNG / " (itoa fail) " o LECH"))
          (if (= fail 0)
            (princ "\n=> BANG NATIVE HOAT DONG TOT (o co du lieu, khong rong).")
            (princ "\n=> BANG NATIVE CO VAN DE - bao lai de kiem tra."))

          (vl-catch-all-apply 'vla-Delete (list tbl))
          (princ "\n(Da xoa bang mau.)")))))
  (princ))

(princ "\nmto-table.lsp loaded.")
(princ)
