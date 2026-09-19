;;; ============================================================
;;; mto-selfup.lsp -- MODULE CAP NHAT MTOPro (thuan AutoLISP)
;;;
;;; Phan QUYET DINH cua he thong cap nhat. Phan THAO TAC NANG
;;; (tai file, giai nen, swap) do bootstrap updater (EXE) lam - vi
;;; AutoLISP KHONG co HTTP va KHONG co SHA256.
;;;
;;; Nguyen tac:
;;;   - Chi THUAN LISP, testable headless tren accoreconsole.
;;;   - KHONG BAO GIO cham vao USER DATA (config/, *.dwg, *.mtocfg).
;;;   - Moi loi deu tra ve gia tri an toan (khong crash AutoCAD).
;;;
;;; Lenh: MTOVERSION · MTOUPGRADECHECK · MTOUPGRADE
;;; ============================================================

;; ------------------------------------------------------------
;; 1. HANG SO
;; ------------------------------------------------------------

(setq *MTO-UPD-KEEP-BACKUPS* 3)

;; Thu muc / file trong <MTOPro>
(setq *MTO-UPD-DIR-STAGING* "staging")
(setq *MTO-UPD-DIR-BACKUP*  "backup")
(setq *MTO-UPD-DIR-LOGS*    "logs")
(setq *MTO-UPD-LOGFILE*     "logs/update.log")
(setq *MTO-UPD-MARKER*      "staging/pending-activation.json")
(setq *MTO-UPD-CONFIG*      "config/update.json")
(setq *MTO-UPD-MANIFEST*    "manifest.json")

;; APPLICATION files - duoc phep ghi de khi kich hoat
(setq *MTO-UPD-APP-PATHS* '("lisp" "docs" "tools" "dll" "version.json"))

;; USER DATA - TUYET DOI KHONG duoc ghi de/xoa
(setq *MTO-UPD-USER-DATA* '("config"))

;; Field bat buoc cua manifest
(setq *MTO-UPD-MARKER-KEYS*
  (list "staged_version" "staged_at" "requires_restart" "reason"))

(setq *MTO-UPD-MANIFEST-REQUIRED*
  '("product" "version" "release_date" "package" "sha256"
    "minimum_version" "minimum_autocad" "mandatory" "release_notes"))

;; Cac action
;; "UPDATE" | "NOOP" | "MANDATORY" | "BLOCKED-MINVER" | "ERROR"

;; ------------------------------------------------------------
;; 2. DUONG DAN
;; ------------------------------------------------------------

;; Thu muc goc cai dat (chua lisp/, config/, version.json)
(defun mto-upd-root ( / base)
  (setq base *MTO-HOME*)
  (if (or (null base) (= base ""))
    (progn
      (setq base (vl-filename-directory (findfile "mto-loader.lsp")))
      ;; <root>/lisp -> <root>
      (if base (setq base (vl-filename-directory base)))))
  base)

;; Duong dan tuyet doi tu duong dan tuong doi trong <root>
(defun mto-upd-path (rel / r)
  (setq r (mto-upd-root))
  (if (and r (/= r "")) (strcat r "/" rel) nil))

;; ------------------------------------------------------------
;; 3. JSON PHANG (dung chung cho version.json va manifest.json)
;;
;; RANG BUOC: file phai la object PHANG, moi field 1 dong.
;; AutoLISP khong co JSON parser nen doc theo dong.
;; ------------------------------------------------------------

;; Dong `line` co chua key o dang  "key" : ... khong?
(defun mto-upd-json-key-p (line key / pat p rest)
  (if (or (null line) (null key)) nil
    (progn
      (setq pat (strcat "\"" key "\""))
      (setq p (vl-string-search pat line))
      (if (null p) nil
        (progn
          (setq rest (vl-string-left-trim " \t" (substr line (+ p (strlen pat) 1))))
          (and (> (strlen rest) 0) (= (substr rest 1 1) ":")))))))

;; Gia tri tren dong (bo dau phay cuoi, bo dau " bao ngoai neu la chuoi)
(defun mto-upd-json-value (line / p v q)
  (setq p (vl-string-search ":" line))
  (if (null p) nil
    (progn
      (setq v (vl-string-trim " \t\r\n" (substr line (+ p 2))))
      (if (and (> (strlen v) 0) (= (substr v (strlen v) 1) ","))
        (setq v (vl-string-trim " \t\r\n" (substr v 1 (1- (strlen v))))))
      (if (and (> (strlen v) 1) (= (substr v 1 1) "\""))
        (progn
          (setq q (vl-string-search "\"" (substr v 2)))
          (if q (substr v 2 q) (substr v 2)))
        v))))

;; Doc 1 key tu file JSON phang -> chuoi hoac nil
(defun mto-upd-json-get (path key / f line found sz)
  (setq found nil)
  (if (or (null path) (null key) (= path "")) nil
    (progn
      (setq sz (vl-catch-all-apply 'vl-file-size (list path)))
      (if (or (vl-catch-all-error-p sz) (null sz))
        nil
        (progn
          (setq f (open path "r"))
          (if (null f) nil
            (progn
              (while (and (null found) (setq line (read-line f)))
                (if (mto-upd-json-key-p line key)
                  (setq found (mto-upd-json-value line))))
              (close f)
              found)))))))

;; Doc TAT CA field -> alist ((KEY . "value") ...)
(defun mto-upd-json-read (path / f line out p k v sz)
  (setq out '())
  (setq sz (vl-catch-all-apply 'vl-file-size (list path)))
  (if (or (vl-catch-all-error-p sz) (null sz))
    nil
    (progn
      (setq f (open path "r"))
      (if (null f) nil
        (progn
          (while (setq line (read-line f))
            (setq p (vl-string-search "\"" line))
            (if p
              (progn
                (setq k (substr line (+ p 2)))
                (setq p (vl-string-search "\"" k))
                (if p
                  (progn
                    (setq k (substr k 1 (1- p)))
                    (if (mto-upd-json-key-p line k)
                      (progn
                        (setq v (mto-upd-json-value line))
                        (if (and v (/= v "")) (setq out (append out (list (cons k v))))))))))))
          (close f)
          out)))))

;; ------------------------------------------------------------
;; 4. PHIEN BAN (semver)
;; ------------------------------------------------------------

;; "1.2.3" -> (1 2 3). Tra nil neu khong hop le.
(defun mto-upd-semver->list (s / parts out ok p one)
  (if (or (null s) (= s "")) nil
    (progn
      (setq out '())
      (setq ok t)
      (setq parts (mto-str-split s "."))
      (foreach one parts
        (if (and ok (mto-str-num-p one))
          (setq out (append out (list (atoi one))))
          (setq ok nil)))
      (if (and ok (= (length out) 3)) out nil))))

;; So sanh 2 semver: tra -1 (a<b) / 0 (=) / 1 (a>b). nil neu khong hop le.
(defun mto-upd-semver-compare (a b / la lb i n res)
  (setq la (mto-upd-semver->list a))
  (setq lb (mto-upd-semver->list b))
  (if (or (null la) (null lb)) nil
    (progn
      (setq i 0)
      (setq n 3)
      (setq res 0)
      (while (and (< i n) (= res 0))
        (cond
          ((< (nth i la) (nth i lb)) (setq res -1))
          ((> (nth i la) (nth i lb)) (setq res 1)))
        (setq i (1+ i)))
      res)))

;; remote co moi hon local khong?
(defun mto-upd-newer-p (remote local / c)
  (setq c (mto-upd-semver-compare remote local))
  (if c (= c 1) nil))

;; ------------------------------------------------------------
;; 5. MANIFEST
;; ------------------------------------------------------------

;; Manifest co du field bat buoc khong? Tra (T . nil) hoac (nil . "ly do")
(defun mto-upd-manifest-valid-p (m / miss k v)
  (if (null m) (cons nil "manifest rong")
    (progn
      (setq miss '())
      (foreach k *MTO-UPD-MANIFEST-REQUIRED*
        (setq v (cdr (assoc k m)))
        (if (or (null v) (= v "")) (setq miss (append miss (list k)))))
      (if miss
        (cons nil (strcat "thieu field: " (mto-str-join miss ", ")))
        (progn
          ;; sha256 phai la 64 ky tu hex
          (setq v (cdr (assoc "sha256" m)))
          (if (/= (strlen v) 64)
            (cons nil (strcat "sha256 phai 64 ky tu, dang co " (itoa (strlen v))))
            ;; version phai la semver hop le
            (if (null (mto-upd-semver->list (cdr (assoc "version" m))))
              (cons nil "version khong phai semver (MAJOR.MINOR.PATCH)")
              (cons t nil))))))))

;; mandatory?
(defun mto-upd-mandatory-p (m / v)
  (setq v (mto-str-up (if (cdr (assoc "mandatory" m)) (cdr (assoc "mandatory" m)) "")))
  (or (= v "TRUE") (= v "1") (= v "YES")))

;; ------------------------------------------------------------
;; 6. NGUON CAP NHAT (UpdateSource)
;; ------------------------------------------------------------

;; Nguon co hop le khong? Chi cho HTTPS (tru localhost) hoac duong dan cuc bo.
;; Tra (T . nil) hoac (nil . "ly do")
(defun mto-upd-source-valid-p (src / s low)
  (if (or (null src) (= src ""))
    (cons nil "updateSource rong")
    (progn
      (setq s src)
      (setq low (mto-str-down s))
      (cond
        ((mto-str-prefix-p low "https://") (cons t nil))
        ;; cho phep localhost/127.0.0.1 voi http (chi de TEST noi bo)
        ((and (mto-str-prefix-p low "http://")
              (or (mto-str-search low "localhost")
                  (mto-str-search low "127.0.0.1")))
         (cons t nil))
        ((mto-str-prefix-p low "http://") (cons nil "CHI cho phep HTTPS (http:// bi tu choi)"))
        ((mto-str-prefix-p low "file://") (cons t nil))
        ;; duong dan cuc bo (o dia / UNC)
        ((or (mto-str-search s ":") (mto-str-prefix-p s "\\\\")) (cons t nil))
        (t (cons nil (strcat "khong nhan dang duoc nguon: " src)))))))

;; Bo credential khoi URL truoc khi ghi log (user:pass@host)
(defun mto-upd-strip-credential (url / p a b q)
  (if (or (null url) (= url "")) url
    (progn
      (setq p (vl-string-search "://" url))
      (if (null p) url
        (progn
          (setq a (+ p 3))
          (setq b (vl-string-search "@" (substr url a)))
          (if (null b) url
            (progn
              (setq b (+ a b))
              ;; tim dau "/" sau host de ghep lai
              (setq q (vl-string-search "/" (substr url (+ b 1))))
              (if p
                (strcat "https://***@" (substr url (+ b 1) q) (substr url (+ b 1 q)))
                (strcat "https://***@" (substr url (+ b 1)))))))))))

;; ------------------------------------------------------------
;; 7. QUYET DINH CAP NHAT (ham loi - testable)
;;
;; Tra ve alist: ((ACTION . "...") (REASON . "...") (VERSION . "x.y.z"))
;; ------------------------------------------------------------
(defun mto-upd-decide (local-ver manifest acadver / mv vv valid minv cmp)
  (if (null manifest)
    (list (cons 'ACTION "ERROR") (cons 'REASON "khong lay duoc manifest") (cons 'VERSION ""))
    (progn
      (setq valid (mto-upd-manifest-valid-p manifest))
      (if (null (car valid))
        (list (cons 'ACTION "ERROR") (cons 'REASON (cdr valid)) (cons 'VERSION ""))
        (progn
          (setq mv (cdr (assoc "version" manifest)))
          (setq minv (cdr (assoc "minimum_version" manifest)))
          ;; 1) minimum_version: ban hien tai phai >= min
          (setq cmp (mto-upd-semver-compare local-ver minv))
          (cond
            ((null cmp)
             (list (cons 'ACTION "ERROR") (cons 'REASON "phien ban khong hop le") (cons 'VERSION mv)))
            ((= cmp -1)
             (list (cons 'ACTION "BLOCKED-MINVER")
                   (cons 'REASON (strcat "ban hien tai " local-ver
                                         " cu hon minimum_version " minv
                                         " - can cap nhat tuan tu"))
                   (cons 'VERSION mv)))
            (t
             ;; 2) so sanh phien ban
             (setq cmp (mto-upd-semver-compare mv local-ver))
             (cond
               ((= cmp 0)
                (list (cons 'ACTION "NOOP") (cons 'REASON "da la ban moi nhat") (cons 'VERSION mv)))
               ((= cmp -1)
                (list (cons 'ACTION "NOOP")
                      (cons 'REASON (strcat "ban local " local-ver " moi hon remote " mv))
                      (cons 'VERSION mv)))
               (t
                (if (mto-upd-mandatory-p manifest)
                  (list (cons 'ACTION "MANDATORY")
                        (cons 'REASON (strcat "BAN BAT BUOC: " mv " - phai cap nhat de tiep tuc"))
                        (cons 'VERSION mv))
                  (list (cons 'ACTION "UPDATE")
                        (cons 'REASON (strcat "co ban moi " mv))
                        (cons 'VERSION mv))))))))))))

;; ------------------------------------------------------------
;; 8. BACKUP BOOKKEEPING
;; ------------------------------------------------------------

;; Danh sach thu muc backup hien co (ten = phien ban)
(defun mto-upd-backup-list ( / dir out)
  (setq out '())
  (setq dir (mto-upd-path *MTO-UPD-DIR-BACKUP*))
  (if dir
    (foreach n (vl-directory-files dir "*" -1)
      (if (and (/= n ".") (/= n "..") (mto-upd-semver->list n))
        (setq out (append out (list n))))))
  out)

;; Sap xep tang dan theo semver (dung cho prune)
(defun mto-upd-sort-versions (lst / arr i j tmp n)
  (setq arr lst)
  (setq n (length arr))
  (setq i 0)
  (while (< i n)
    (setq j 0)
    (while (< j (- n 1))
      (if (= (mto-upd-semver-compare (nth j arr) (nth (+ j 1) arr)) 1)
        (progn
          (setq tmp (nth j arr))
          (setq arr (mto-subst-nth j (nth (+ j 1) arr) arr))
          (setq arr (mto-subst-nth (+ j 1) tmp arr)))
        nil)
      (setq j (1+ j)))
    (setq i (1+ i)))
  arr)

;; Danh sach backup CAN XOA de chi giu `keep` ban moi nhat (TEST-08)
(defun mto-upd-backups-to-delete (lst keep / sorted n excess out i)
  (setq out '())
  (setq sorted (mto-upd-sort-versions lst))
  (setq n (length sorted))
  (if (> n keep)
    (progn
      (setq excess (- n keep))
      (setq i 0)
      (while (< i excess)
        (setq out (append out (list (nth i sorted))))
        (setq i (1+ i)))))
  out)

;; ------------------------------------------------------------
;; 9. MARKER (kich hoat o session ke - khi payload co DLL)
;; ------------------------------------------------------------

(defun mto-upd-marker-write (ver requires-restart reason / p f)
  (setq p (mto-upd-path *MTO-UPD-MARKER*))
  (if (null p) nil
    (progn
      (mto-upd-mkdir (mto-upd-path *MTO-UPD-DIR-STAGING*))
      (setq f (open p "w"))
      (if (null f) nil
        (progn
          (write-line "{" f)
          (write-line (strcat "  \"staged_version\": \"" (if ver ver "") "\",") f)
          (write-line (strcat "  \"staged_at\": \"" (mto-upd-now) "\",") f)
          (write-line (strcat "  \"requires_restart\": \"" (if requires-restart "true" "false") "\",") f)
          (write-line (strcat "  \"reason\": \"" (if reason reason "") "\"") f)
          (write-line "}" f)
          (close f)
          t)))))

(defun mto-upd-marker-read ( / p)
  (setq p (mto-upd-path *MTO-UPD-MARKER*))
  (if p (mto-upd-json-load p *MTO-UPD-MARKER-KEYS*) nil))

;; ------------------------------------------------------------
;; 10. LOG
;; ------------------------------------------------------------

(defun mto-upd-log (msg / p f)
  (setq p (mto-upd-path *MTO-UPD-LOGFILE*))
  (if p
    (progn
      (mto-upd-mkdir (mto-upd-path *MTO-UPD-DIR-LOGS*))
      (setq f (open p "a"))
      (if f
        (progn
          (write-line (strcat (mto-upd-now) " | " *MTO-VERSION* " | " msg) f)
          (close f)
          t)))))

;; ------------------------------------------------------------
;; 11. VERIFY (goi certutil - khong dong bo, chi tra lenh)
;; ------------------------------------------------------------

;; Lenh tinh SHA256 cua file (chay bang startapp)
(defun mto-upd-sha256-cmd (file)
  (strcat "certutil -hashfile \"" file "\" SHA256"))

;; Lenh tai file tu URL (https)
(defun mto-upd-download-cmd (url dest)
  (strcat "certutil -urlcache -f -split \"" url "\" \"" dest "\""))

;; Kiem tra cau truc payload sau khi giai nen (TEST-07)
;; Tra (T . nil) hoac (nil . "ly do")
(defun mto-upd-payload-valid-p (dir expected-ver / lispdir vf v ver n)
  (if (or (null dir) (= dir ""))
    (cons nil "thu muc payload rong")
    (if (not (vl-file-directory-p dir))
      (cons nil (strcat "khong ton tai: " dir))
      (progn
        (setq lispdir (strcat dir "/lisp"))
        (if (not (vl-file-directory-p lispdir))
          (cons nil "thieu thu muc lisp/")
          (progn
            (setq n (length (vl-directory-files lispdir "*.lsp" 1)))
            (if (< n 1)
              (cons nil "thu muc lisp/ khong co file .lsp nao")
              (progn
                (setq vf (strcat dir "/version.json"))
                (setq v (mto-upd-json-get vf "version"))
                (if (null v)
                  (cons nil "thieu version.json hoac khong doc duoc")
                  (if (and expected-ver (/= expected-ver "")
                           (/= (mto-str-trim v) (mto-str-trim expected-ver)))
                    (cons nil (strcat "version.json (" v ") khong khop manifest (" expected-ver ")"))
                    (cons t nil)))))))))))

;; Duong dan payload co chua .. hoac tuyet doi (chong zip-slip)?
(defun mto-upd-unsafe-path-p (p)
  (if (or (null p) (= p "")) t
    (or (mto-str-search p "..")
        (mto-str-prefix-p p "/")
        (mto-str-prefix-p p "\\")
        (and (> (strlen p) 1) (= (substr p 2 1) ":")))))

;; ------------------------------------------------------------
;; 12. CONFIG update.json
;; ------------------------------------------------------------

;; Doc config; thieu file -> dung mac dinh AN TOAN (enabled=0)
;; Lay 1 khoa trong alist config, co gia tri mac dinh
(defun mto-upd-cfg-get (m k dflt / v)
  (setq v (if m (cdr (assoc k m)) nil))
  (if (and v (/= v "")) v dflt))

;; Doc config; thieu file -> dung mac dinh AN TOAN (enabled=false)
(defun mto-upd-config ( / p m)
  (setq p (mto-upd-path *MTO-UPD-CONFIG*))
  (setq m (if p (mto-upd-json-load p *MTO-UPD-MARKER-KEYS*) nil))
  (list
    (cons 'ENABLED    (mto-upd-cfg-get m "enabled" "false"))
    (cons 'CHANNEL    (mto-upd-cfg-get m "channel" "stable"))
    (cons 'CHECKONSTARTUP (mto-upd-cfg-get m "checkOnStartup" "false"))
    (cons 'INTERVAL   (mto-upd-cfg-get m "checkIntervalHours" "24"))
    (cons 'SOURCE     (mto-upd-cfg-get m "updateSource" ""))
    (cons 'KEEP       (mto-upd-cfg-get m "keepBackups" "3"))))

;; ------------------------------------------------------------
;; 13. TIEN ICH NOI BO
;; ------------------------------------------------------------

;; Tao thu muc (khong loi neu da co)
(defun mto-upd-mkdir (dir)
  (if (and dir (/= dir "") (not (vl-file-directory-p dir)))
    (vl-catch-all-apply 'vl-mkdir (list dir))))

(defun mto-upd-now ( / d)
  (setq d (rtos (getvar "CDATE") 2 0))
  (strcat (substr d 1 4) "-" (substr d 5 2) "-" (substr d 7 2) " "
          (substr d 10 2) ":" (substr d 12 2) ":" (substr d 14 2)))

;; ------------------------------------------------------------
;; 14. LENH
;; ------------------------------------------------------------

(defun c:MTOVERSION ( / mkr cfg)
  (mto-ui-start "MTOVERSION" "Xem phien ban / cap nhat gan nhat")
  (princ (strcat "\nPhien ban dang chay : " *MTO-VERSION*))
  (setq cfg (mto-upd-config))
  (princ (strcat "\nNguon cap nhat      : "
                 (if (= (cdr (assoc 'SOURCE cfg)) "") "(chua cau hinh)" (cdr (assoc 'SOURCE cfg)))))
  (princ (strcat "\nKenh (channel)      : " (cdr (assoc 'CHANNEL cfg))))
  (princ (strcat "\nTu dong kiem tra    : " (cdr (assoc 'ENABLED cfg))
                 " / checkOnStartup=" (cdr (assoc 'CHECKONSTARTUP cfg))))
  (setq mkr (mto-upd-marker-read))
  (if mkr
    (princ (strcat "\nCO BAN CHO KICH HOAT: " (cdr (assoc "staged_version" mkr))
                   " (can khoi dong lai AutoCAD: " (cdr (assoc "requires_restart" mkr)) ")"))
    (princ "\nKhong co ban nao dang cho kich hoat."))
  (princ (strcat "\nThu muc cai dat     : " (mto-upd-root)))
  (princ (strcat "\nSo ban backup       : " (itoa (length (mto-upd-backup-list)))
                 " (giu toi da " (itoa *MTO-UPD-KEEP-BACKUPS*) ")"))
  (mto-ui-end "MTOVERSION"))

(defun c:MTOUPGRADECHECK ( / cfg src valid msrc man dec)
  (mto-ui-start "MTOUPGRADECHECK" "Kiem tra ban moi (khong tai)")
  (setq cfg (mto-upd-config))
  (setq src (cdr (assoc 'SOURCE cfg)))
  (if (= src "")
    (princ "\nChua cau hinh nguon cap nhat (config/update.json -> updateSource).")
    (progn
      (setq valid (mto-upd-source-valid-p src))
      (if (null (car valid))
        (progn
          (princ (strcat "\nNGUON KHONG HOP LE: " (cdr valid)))
          (mto-upd-log (strcat "CHECK-ERROR | " (cdr valid))))
        (progn
          (princ (strcat "\nNguon: " (mto-upd-strip-credential src)))
          (setq msrc (mto-upd-manifest-url src))
          (setq man (mto-upd-json-read msrc))
          (if (null man)
            (progn
              (princ (strcat "\nKhong doc duoc manifest: " msrc))
              (princ "\n(Neu la nguon mang: can bootstrap updater de tai ve.)")
              (mto-upd-log "CHECK | khong doc duoc manifest"))
            (progn
              (setq dec (mto-upd-decide *MTO-VERSION* man (getvar "ACADVER")))
              (princ (strcat "\nPhien ban remote : " (cdr (assoc 'VERSION dec))))
              (princ (strcat "\nKet qua          : " (cdr (assoc 'ACTION dec))))
              (princ (strcat "\nLy do            : " (cdr (assoc 'REASON dec))))
              (mto-upd-log (strcat "CHECK | " (cdr (assoc 'ACTION dec))
                                   " | remote=" (cdr (assoc 'VERSION dec))))))))))
  (mto-ui-end "MTOUPGRADECHECK"))

;; Duong dan manifest tu nguon (bo dau / cuoi)
(defun mto-upd-manifest-url (src / s)
  (setq s (mto-str-trim src))
  (while (and (> (strlen s) 0) (= (substr s (strlen s) 1) "/"))
    (setq s (substr s 1 (1- (strlen s)))))
  (strcat s "/" *MTO-UPD-MANIFEST*))

(defun c:MTOUPGRADE ( / arg cfg src valid man dec)
  (mto-ui-start "MTOUPGRADE" "Kiem tra + tai + cai ban moi")
  (setq arg (mto-str-up (mto-str-trim
              (getstring T "\nTuy chon [ROLLBACK/STATUS] <Enter = cap nhat>: "))))
  (cond
    ((= arg "ROLLBACK")
     (princ "\n=== ROLLBACK ===")
     (princ (strcat "\nBan backup hien co: "
                    (if (mto-upd-backup-list)
                      (mto-str-join (mto-upd-backup-list) ", ")
                      "(khong co)")))
     (princ "\nHUONG DAN: chay bootstrap updater de rollback:")
     (princ "\n  <MTOPro>\\tools\\UpdaterApp.exe --rollback")
     (princ "\n(Chi rollback duoc khi AutoCAD da dong.)"))
    ((= arg "STATUS")
     (c:MTOVERSION))
    (t
     (setq cfg (mto-upd-config))
     (setq src (cdr (assoc 'SOURCE cfg)))
     (if (= src "")
       (princ "\nChua cau hinh nguon cap nhat.")
       (progn
         (setq valid (mto-upd-source-valid-p src))
         (if (null (car valid))
           (princ (strcat "\nNGUON KHONG HOP LE: " (cdr valid)))
           (progn
             (setq man (mto-upd-manifest-load (mto-upd-manifest-url src)))
             (setq dec (mto-upd-decide *MTO-VERSION* man (getvar "ACADVER")))
             (princ (strcat "\nKet qua: " (cdr (assoc 'ACTION dec))))
             (princ (strcat "\nLy do  : " (cdr (assoc 'REASON dec))))
             (if (member (cdr (assoc 'ACTION dec)) '("UPDATE" "MANDATORY"))
               (progn
                 (princ "\n\n=== CAN BOOTSTRAP UPDATER DE TAI VA KICH HOAT ===")
                 (princ "\nAutoLISP khong co HTTP/SHA256. Chay:")
                 (princ (strcat "\n  " (mto-upd-path "tools/UpdaterApp.exe")
                                " --source \"" (mto-upd-strip-credential src) "\""))
                 (princ (strcat "\n  (hoac tai tay: " (mto-upd-manifest-url src) ")"))
                 (princ "\nSau khi updater xong: khoi dong lai AutoCAD."))
               (princ (strcat "\nKhong can cap nhat: " (cdr (assoc 'REASON dec)))))))))))
  (mto-ui-end "MTOUPGRADE"))

;; ------------------------------------------------------------
;; 3b. LOAD NHIEU KEY (dung mto-upd-json-get da kiem chung)
;;
;; mto-upd-json-read (quet moi dong) tra nil tren accoreconsole
;; -> thay bang cach goi json-get cho tung key da biet.
;; ------------------------------------------------------------
(defun mto-upd-json-load (path keys / out k v)
  (setq out '())
  (foreach k keys
    (setq v (mto-upd-json-get path k))
    (if (and v (/= v ""))
      (setq out (append out (list (cons k v))))))
  out)

;; Manifest day du (theo danh sach field bat buoc)
(defun mto-upd-manifest-load (path)
  (mto-upd-json-load path *MTO-UPD-MANIFEST-REQUIRED*))

(princ "\nmto-selfup.lsp loaded.")
(princ)
