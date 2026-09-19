;;; ============================================================
;;; mto-select.lsp -- MTO: chon vung / loc doi tuong (TASK-001)
;;;
;;; Muc tieu: nguoi dung chon VUNG (Window/Crossing/Polygon) va MTO chi
;;; boc du lieu TRONG VUNG DO (khong bat buoc scan toan bo ban ve).
;;;
;;; Phan logic thuan (testable headless):
;;;   mto-sel-build-filter      -- tao DXF filter list
;;;   mto-sel-valid-mode-p      -- kiem tra mode ssget
;;;   mto-sel-normalize-list    -- parse chuoi "A,B,C" -> list
;;;   mto-sel-ss->handles       -- selection set -> danh sach handle
;;;   mto-sel-ss->types         -- selection set -> dem theo loai
;;;   mto-sel-ss->layers        -- selection set -> dem theo layer
;;;   mto-sel-ss-summary        -- tom tat (tong, theo loai, theo layer)
;;;
;;; Phan tuong tac (command):
;;;   MTOSEL -- chon vung theo che do nguoi dung nhap
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. LOGIC THUAN
;; ------------------------------------------------------------

;; Chuan hoa chuoi nguoi dung nhap thanh list sach
;; "text, mtext ; insert" -> ("TEXT" "MTEXT" "INSERT")
(defun mto-sel-normalize-list (s / parts out p)
  (setq out '())
  (if (and s (/= (mto-str-trim s) ""))
    (progn
      ;; thay ';' bang ','
      (setq s (vl-string-translate ";" "," s))
      (foreach p (mto-str-split s ",")
        (setq p (mto-str-up p))
        (if (/= p "") (setq out (append out (list p)))))))
  out)

;; Mode ssget hop le
(defun mto-sel-valid-mode-p (m)
  (if (null m) nil
    (member (mto-str-up m) '("W" "C" "WP" "CP" "F" "X" "I" "A"))))

;; Tao DXF filter list tu entity types + layers
;; entityTypes: list chuoi ("TEXT" "MTEXT")
;; layers:      list chuoi ("EL-*" "P-*")
(defun mto-sel-build-filter (entityTypes layers / f)
  (setq f '())
  (if entityTypes
    (setq f (append f (list (cons 0 (mto-str-join entityTypes ","))))))
  (if layers
    (setq f (append f (list (cons 8 (mto-str-join layers ","))))))
  (if f f nil))

;; ------------------------------------------------------------
;; 2. THAO TAC TREN SELECTION SET
;; ------------------------------------------------------------

;; Danh sach handle
(defun mto-sel-ss->handles (ss / i n e h lst)
  (setq lst '() i 0 n (if ss (sslength ss) 0))
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (progn
        (setq h (cdr (assoc 5 (entget e))))
        (if h (setq lst (append lst (list h))))))
    (setq i (1+ i)))
  lst)

;; Danh sach entity name (de dung cho cac buoc sau)
(defun mto-sel-ss->enames (ss / i n lst)
  (setq lst '() i 0 n (if ss (sslength ss) 0))
  (while (< i n)
    (setq lst (append lst (list (ssname ss i))))
    (setq i (1+ i)))
  lst)

;; Dem theo loai: alist ((TYPE . count) ...)
;; LUU Y: KHONG duoc dat ten bien local la `t` (T la symbol true cua AutoLISP,
;; bind vao se loi "incorrect object to bind: T").
(defun mto-sel-ss->types (ss / i n e ety lst pair)
  (setq lst '() i 0 n (if ss (sslength ss) 0))
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (progn
        (setq ety (mto-str-up (cdr (assoc 0 (entget e)))))
        (setq pair (assoc ety lst))
        (if pair
          (setq lst (subst (cons ety (1+ (cdr pair))) pair lst))
          (setq lst (append lst (list (cons ety 1)))))))
    (setq i (1+ i)))
  lst)

;; Dem theo layer: alist ((LAYER . count) ...)
(defun mto-sel-ss->layers (ss / i n e l lst pair)
  (setq lst '() i 0 n (if ss (sslength ss) 0))
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (progn
        (setq l (cdr (assoc 8 (entget e))))
        (setq pair (assoc l lst))
        (if pair
          (setq lst (subst (cons l (1+ (cdr pair))) pair lst))
          (setq lst (append lst (list (cons l 1)))))))
    (setq i (1+ i)))
  lst)

;; Tom tat: (TOTAL . n) + TYPES + LAYERS
(defun mto-sel-ss-summary (ss)
  (list
    (cons 'TOTAL (if ss (sslength ss) 0))
    (cons 'TYPES (mto-sel-ss->types ss))
    (cons 'LAYERS (mto-sel-ss->layers ss))))

;; ------------------------------------------------------------
;; 3. LAY HANDLE THEO DIEU KIEN (dung cho cac module khac)
;; ------------------------------------------------------------

;; Lay handle cua tat ca doi tuong khop filter (toan ban ve)
(defun mto-sel-all-handles (entityTypes layers / filter ss)
  (setq filter (mto-sel-build-filter entityTypes layers))
  (setq ss (if filter (ssget "_X" filter) (ssget "_X")))
  (mto-sel-ss->handles ss))

;; ------------------------------------------------------------
;; 4. PHAN TUONG TAC (command)
;; ------------------------------------------------------------

(defun mto-sel-ask-mode ( / m)
  (initget "W C WP CP F")
  (setq m (getkword "\nChe do chon [Window(W)/Crossing(C)/WindowPolygon(WP)/CrossPolygon(CP)/Fence(F)] <W>: "))
  (if (null m) "W" m))

(defun mto-sel-ask-list (msg / s)
  (setq s (getstring T (strcat "\n" msg " (phan cach bang ',' hoac ';', Enter = tat ca): ")))
  (mto-sel-normalize-list s))

;; Chon theo 2 diem (W / C / F)
(defun mto-sel-pick-two-points (mode filter / p1 p2 ss)
  (setq p1 (getpoint "\nChon diem thu nhat: "))
  (if (null p1) nil
    (progn
      (setq p2 (getcorner p1 "\nChon diem doi dien: "))
      (if (null p2) nil
        (progn
          (setq ss (if filter
                     (ssget mode (list p1 p2) filter)
                     (ssget mode (list p1 p2))))
          ss)))))

;; Chon theo polygon (WP / CP)
(defun mto-sel-pick-polygon (mode filter / pts p ss)
  (setq pts '())
  (princ "\nChon cac dinh polygon (Enter de ket thuc):")
  (while (setq p (getpoint "\nDinh: "))
    (setq pts (append pts (list p))))
  (if (< (length pts) 3)
    (progn (princ "\nCan it nhat 3 dinh.") nil)
    (progn
      (setq ss (if filter
                 (ssget mode pts filter)
                 (ssget mode pts)))
      ss)))

(defun c:MTOSEL ( / mode types layers filter ss sum)
  (mto-ui-start "MTOSEL" "Chon vung + loc theo layer / loai doi tuong")
  (setq mode   (mto-sel-ask-mode))
  (setq types  (mto-sel-ask-list "Loai doi tuong (vd: TEXT,MTEXT,INSERT,LINE,LWPOLYLINE)"))
  (setq layers (mto-sel-ask-list "Layer (ho tro wildcard *, vd: EL-*)"))
  (setq filter (mto-sel-build-filter types layers))

  (princ (strcat "\nFilter: "
                 (if filter (vl-princ-to-string filter) "(khong co)")))

  (setq ss
    (cond
      ((member mode '("W" "C" "F")) (mto-sel-pick-two-points mode filter))
      ((member mode '("WP" "CP"))   (mto-sel-pick-polygon mode filter))
      (t nil)))

  (if (null ss)
    (princ "\nKhong chon duoc doi tuong nao.")
    (progn
      (setq sum (mto-sel-ss-summary ss))
      (princ (strcat "\n--- KET QUA CHON VUNG ---"))
      (princ (strcat "\nTong doi tuong: " (itoa (cdr (assoc 'TOTAL sum)))))
      (princ "\nTheo loai:")
      (foreach p (cdr (assoc 'TYPES sum))
        (princ (strcat "\n  " (car p) ": " (itoa (cdr p)))))
      (princ "\nTheo layer:")
      (foreach p (cdr (assoc 'LAYERS sum))
        (princ (strcat "\n  " (car p) ": " (itoa (cdr p)))))
      ;; luu handle vao phien
      (setq *MTO-LAST-SELECTION* (mto-sel-ss->handles ss))
      (princ (strcat "\nDa luu " (itoa (length *MTO-LAST-SELECTION*))
                     " handle vao *MTO-LAST-SELECTION*."))))
  (princ))

(princ "\nmto-select.lsp loaded.")
(princ)
