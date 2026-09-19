;;; ============================================================
;;; mto-text.lsp -- MTO: nhan dang thiet bi bang noi dung TEXT/MTEXT (TASK-002)
;;;
;;; Muc tieu: doc TEXT/MTEXT, tach PREFIX (MCB/ELCB/DB/AP/CAM/FACP...)
;;; de gom nhom theo PREFIX -> CATEGORY -> TYPE -> QUANTITY,
;;; thay vi gop tat ca TEXT thanh mot nhom.
;;;
;;; Logic thuan (testable headless):
;;;   mto-text-strip-mtext          -- bo format code cua MTEXT
;;;   mto-text-content              -- lay noi dung tu entity
;;;   mto-text-extract-prefix       -- token dau, tach theo space/-/_
;;;   mto-text-match-known-prefix   -- khop prefix dai nhat + kiem ranh gioi
;;;   mto-text-category-for-prefix  -- tra bang prefix -> category
;;;   mto-text-classify             -- entity TEXT/MTEXT -> item
;;;   mto-text-scan-ss              -- selection set -> db
;;;
;;; Command: MTOTEXT
;;; ============================================================

(vl-load-com)

;; ------------------------------------------------------------
;; 1. BANG PREFIX MAC DINH (co the mo rong tu config)
;; ------------------------------------------------------------

(setq *MTO-PREFIX-TABLE*
  (list
    ;; --- Dien ---
    '("MCB"      . "Electrical")
    '("MCCB"     . "Electrical")
    '("ELCB"     . "Electrical")
    '("RCBO"     . "Electrical")
    '("RCD"      . "Electrical")
    '("MDB"      . "Electrical")
    '("SDB"      . "Electrical")
    '("DB"       . "Electrical")
    '("CB"       . "Electrical")
    '("CONTACTOR". "Electrical")
    '("RELAY"    . "Electrical")
    '("LIGHT"    . "Electrical")
    '("LED"      . "Electrical")
    '("LAMP"     . "Electrical")
    '("SOCKET"   . "Electrical")
    '("SWITCH"   . "Electrical")
    '("FAN"      . "Electrical")
    '("TRAY"     . "Electrical")
    '("CONDUIT"  . "Electrical")
    ;; --- Dien nhe / ELV ---
    '("AP"       . "ELV")
    '("CAM"      . "ELV")
    '("CCTV"     . "ELV")
    '("NVR"      . "ELV")
    '("DVR"      . "ELV")
    '("FACP"     . "ELV")
    '("SMOKE"    . "ELV")
    '("HEAT"     . "ELV")
    '("MCP"      . "ELV")
    '("SIREN"    . "ELV")
    '("STROBE"   . "ELV")
    '("SPEAKER"  . "ELV")
    '("AMP"      . "ELV")
    '("LAN"      . "ELV")
    '("DATA"     . "ELV")
    '("RJ45"     . "ELV")
    '("PATCH"    . "ELV")
    '("RACK"     . "ELV")
    '("UPS"      . "ELV")
    '("PDU"      . "ELV")
    '("ODF"      . "ELV")
    '("ACC"      . "ELV")
    ;; --- Nuoc ---
    '("PUMP"     . "Plumbing")
    '("VALVE"    . "Plumbing")
    '("PIPE"     . "Plumbing")
    '("WC"       . "Plumbing")
    '("LAV"      . "Plumbing")
    '("SINK"     . "Plumbing")
    '("URINAL"   . "Plumbing")
    '("SHOWER"   . "Plumbing")
    '("TANK"     . "Plumbing")
    '("GATE"     . "Plumbing")
    '("BALL"     . "Plumbing")
    '("CHECK"    . "Plumbing")
    '("PRV"      . "Plumbing")
    '("FD"       . "Plumbing")))

;; ------------------------------------------------------------
;; 2. LOGIC THUAN
;; ------------------------------------------------------------

;; Bo format code cua MTEXT: {\fArial|b0;...}, \A1;, \P, \~, {, }
(defun mto-text-strip-mtext (s / i n out c nxt)
  (if (or (null s) (= s "")) ""
    (progn
      (setq i 1 n (strlen s) out "")
      (while (<= i n)
        (setq c (substr s i 1))
        (cond
          ;; gap backslash -> format code
          ((= c "\\")
           (progn
             (setq i (1+ i))
             (if (<= i n)
               (progn
                 (setq nxt (substr s i 1))
                 (if (member nxt '("P" "p"))
                   ;; \P = xuong dong -> khoang trang
                   (setq out (strcat out " "))
                   ;; cac code khac: bo qua den dau ';'
                   (while (and (<= i n) (/= (substr s i 1) ";"))
                     (setq i (1+ i))))))))
          ;; bo ngoac nhon
          ((member c '("{" "}")) nil)
          ;; ky tu thuong
          (t (setq out (strcat out c))))
        (setq i (1+ i)))
      (mto-str-trim out))))

;; Lay noi dung text tu entity (TEXT hoac MTEXT)
(defun mto-text-content (en / d s)
  (setq d (entget en))
  (setq s (cdr (assoc 1 d)))
  (setq s (mto-text-strip-mtext s))
  s)

;; Loai entity la text?
(defun mto-text-entity-p (en / ty)
  (setq ty (mto-str-up (cdr (assoc 0 (entget en)))))
  (or (= ty "TEXT") (= ty "MTEXT") (= ty "ATTDEF")))

;; Tach token dau tien, tach them theo '-' va '_'
;; "MCB-20A" -> "MCB" ; "MCB 20A" -> "MCB" ; "MCB20A" -> "MCB20A"
(defun mto-text-extract-prefix (s / tok p)
  (setq tok (mto-str-first-token (mto-str-up s)))
  (if (= tok "") ""
    (progn
      ;; tach theo '-'
      (setq p (vl-string-search "-" tok))
      (if p (setq tok (substr tok 1 p)))
      ;; tach theo '_'
      (setq p (vl-string-search "_" tok))
      (if p (setq tok (substr tok 1 p)))
      tok)))

;; Kiem tra ranh gioi sau prefix: het chuoi, hoac ky tu phan cach, hoac chu so
(defun mto-text-boundary-p (s prefix / c)
  (if (<= (strlen s) (strlen prefix)) t
    (progn
      (setq c (substr s (1+ (strlen prefix)) 1))
      (or (= c " ") (= c "-") (= c "_") (= c ":") (= c ".")
          (and (>= (ascii c) 48) (<= (ascii c) 57))))))

;; Khop prefix DAI NHAT trong bang (tranh "ELCB" bi nhan thanh "E")
;; prefixList: danh sach chuoi prefix
(defun mto-text-match-known-prefix (s prefixList / up best)
  (setq up (mto-str-up (mto-str-trim s)) best nil)
  (foreach p prefixList
    (setq p (mto-str-up p))
    (if (and (>= (strlen up) (strlen p))
             (= (substr up 1 (strlen p)) p)
             (mto-text-boundary-p up p))
      (if (or (null best) (> (strlen p) (strlen best)))
        (setq best p))))
  best)

;; Danh sach prefix tu bang
(defun mto-text-prefix-list (/ out)
  (setq out '())
  (foreach pr *MTO-PREFIX-TABLE*
    (setq out (append out (list (car pr)))))
  out)

;; Tra category theo prefix
(defun mto-text-category-for-prefix (pfx / pr res)
  (setq res *MTO-CAT-OTHER*)
  (if pfx
    (foreach pr *MTO-PREFIX-TABLE*
      (if (= (mto-str-up (car pr)) (mto-str-up pfx))
        (setq res (cdr pr)))))
  res)

;; Nhan dang prefix cua mot chuoi text: uu tien bang prefix, fallback token dau
(defun mto-text-recognize-prefix (s / known)
  (setq known (mto-text-match-known-prefix s (mto-text-prefix-list)))
  (if known known (mto-text-extract-prefix s)))

;; ------------------------------------------------------------
;; 3. TAO ITEM TU TEXT
;; ------------------------------------------------------------

(defun mto-text-classify (en / content pfx cat h it)
  (setq content (mto-text-content en))
  (setq pfx     (mto-text-recognize-prefix content))
  (setq cat     (mto-text-category-for-prefix pfx))
  (setq h       (cdr (assoc 5 (entget en))))

  (setq it (mto-item-new cat pfx content))
  (setq it (mto-item-set it 'PREFIX pfx))
  (setq it (mto-item-set it 'DESCRIPTION content))
  (setq it (mto-item-set it 'LAYER (cdr (assoc 8 (entget en)))))
  (setq it (mto-item-set it 'SOURCETYPE *MTO-SRC-TEXT*))
  (setq it (mto-item-set it 'SOURCEOBJECT content))
  (setq it (mto-item-set it 'UNIT *MTO-UNIT-PCS*))
  (setq it (mto-item-add-handle it h))
  (setq it (mto-item-add-auto it 1))
  (mto-item-recalc it))

;; Quet selection set text -> db
(defun mto-text-scan-ss (ss db / i n e it added skipped)
  (setq i 0 n (if ss (sslength ss) 0) added 0 skipped 0)
  (while (< i n)
    (setq e (ssname ss i))
    (if e
      (if (mto-text-entity-p e)
        (progn
          (setq it (mto-text-classify e))
          (setq db (mto-db-merge-item db it))
          (setq added (1+ added)))
        (setq skipped (1+ skipped))))
    (setq i (1+ i)))
  (list (cons 'DB db) (cons 'ADDED added) (cons 'SKIPPED skipped)))

;; ------------------------------------------------------------
;; 4. COMMAND
;; ------------------------------------------------------------

(defun c:MTOTEXT ( / types layers filter ss res db)
  (mto-ui-start "MTOTEXT" "Nhan dang TEXT / MTEXT theo prefix")
  (setq types (mto-sel-normalize-list
                (getstring T "\nLoai text [TEXT,MTEXT] <TEXT,MTEXT>: ")))
  (if (null types) (setq types '("TEXT" "MTEXT")))
  (setq layers (mto-sel-normalize-list
                 (getstring T "\nLayer (wildcard *, Enter = tat ca): ")))
  (setq filter (mto-sel-build-filter types layers))

  (setq ss (if filter (ssget filter) (ssget)))
  (if (null ss)
    (princ "\nKhong chon duoc text nao.")
    (progn
      (setq res (mto-text-scan-ss ss (mto-db-load)))
      (setq db (cdr (assoc 'DB res)))
      (mto-db-save db)
      (princ (strcat "\nDa xu ly " (itoa (cdr (assoc 'ADDED res))) " text"
                     ", bo qua " (itoa (cdr (assoc 'SKIPPED res)))
                     " doi tuong khong phai text."))
      (princ (strcat "\nTong so dong trong DB: " (itoa (mto-db-count db))))))
  (princ))

(princ "\nmto-text.lsp loaded.")
(princ)
