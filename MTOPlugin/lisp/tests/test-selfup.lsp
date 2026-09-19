;;; ============================================================
;;; test-selfup.lsp -- Test cho module cap nhat (mto-selfup.lsp)
;;;
;;; Bao phu: TEST-01..11, TEST-13, TEST-16 (cua UPDATE_ARCHITECTURE.md)
;;; Chay: .\run-tests.ps1 -TestFile test-selfup.lsp
;;;
;;; Nguyen tac: KHONG gia PASS. Moi test kiem gia tri THAT tra ve tu ham.
;;; ============================================================

;; Ghi 1 file JSON phang de test parse
(defun ts-write (path lines / f)
  (setq f (open path "w"))
  (if f (progn (foreach l lines (write-line l f)) (close f) t) nil))

(defun ts-manifest-lines (ver sha mand / l)
  (setq l (list
    "{"
    (strcat "  \"product\": \"MTOPro\",")
    (strcat "  \"version\": \"" ver "\",")
    "  \"release_date\": \"2026-10-01\","
    "  \"package\": \"package.zip\","
    (strcat "  \"sha256\": \"" sha "\",")
    "  \"minimum_version\": \"1.0.0\","
    "  \"minimum_autocad\": \"24.0\","
    (strcat "  \"mandatory\": \"" mand "\",")
    "  \"release_notes\": \"fix loi bang NATIVE\""
    "}"))
  l)

(defun mto-run-tests (out-path / tmp mf m sha64 sha_short dec lv)

  (mto-test-reset)
  (setq tmp (vl-filename-mktemp "mtoselfup.json"))
  (setq sha64 "a3f5b7c9d1e2f4a6b8c0d2e4f6a8b0c2d4e6f8a0b1c3d5e7f9a1b2c3d4e5f6a7")
  (setq sha_short "abc123")

  ;; ---------- TEST-01: version fallback khi file thieu ----------
  (mto-assert-true "selfup-01: mto-version-read tra chuoi khong rong"
    (and (mto-version-read)
         (> (strlen (mto-version-read)) 0)))
  (mto-assert-equal "selfup-01: fallback hang so = 1.0.0"
    "1.0.0" *MTO-VERSION-FALLBACK*)

  ;; ---------- TEST-02: parse manifest day du field ----------
  (ts-write tmp (ts-manifest-lines "1.1.0" sha64 "false"))
  (setq mf (mto-upd-manifest-load tmp))
  (mto-assert-true "selfup-02: doc duoc manifest (alist khong rong)"
    (> (length mf) 5))
  (mto-assert-equal "selfup-02: field product doc dung"
    "MTOPro" (cdr (assoc "product" mf)))
  (mto-assert-equal "selfup-02: field version doc dung"
    "1.1.0" (cdr (assoc "version" mf)))

  ;; ---------- TEST-03: so sanh semver ----------
  (mto-assert-equal "selfup-03: 1.1.0 > 1.0.0" 1 (mto-upd-semver-compare "1.1.0" "1.0.0"))
  (mto-assert-equal "selfup-03: 1.0.0 = 1.0.0" 0 (mto-upd-semver-compare "1.0.0" "1.0.0"))
  (mto-assert-equal "selfup-03: 0.9.0 < 1.0.0" -1 (mto-upd-semver-compare "0.9.0" "1.0.0"))
  (mto-assert-equal "selfup-03: 1.0.10 > 1.0.9" 1 (mto-upd-semver-compare "1.0.10" "1.0.9"))
  (mto-assert-true "selfup-03: semver sai dinh dang -> nil"
    (null (mto-upd-semver->list "1.0")))
  (mto-assert-true "selfup-03: mto-upd-newer-p dung"
    (mto-upd-newer-p "1.2.0" "1.1.9"))

  ;; ---------- TEST-04: mandatory chan / optional hoi ----------
  (setq dec (mto-upd-decide "1.0.0"
              (mto-upd-manifest-load (progn (ts-write tmp (ts-manifest-lines "1.2.0" sha64 "true")) tmp))
              "24.2"))
  (mto-assert-equal "selfup-04: mandatory=true -> MANDATORY"
    "MANDATORY" (cdr (assoc 'ACTION dec)))
  (ts-write tmp (ts-manifest-lines "1.2.0" sha64 "false"))
  (setq dec (mto-upd-decide "1.0.0" (mto-upd-manifest-load tmp) "24.2"))
  (mto-assert-equal "selfup-04: mandatory=false -> UPDATE"
    "UPDATE" (cdr (assoc 'ACTION dec)))

  ;; ---------- TEST-05: loi nguon -> graceful (khong crash) ----------
  (mto-assert-true "selfup-05: doc manifest khong ton tai -> nil (khong crash)"
    (null (mto-upd-manifest-load "Z:/khong/ton/tai/manifest.json")))
  (setq dec (mto-upd-decide "1.0.0" nil "24.2"))
  (mto-assert-equal "selfup-05: manifest nil -> ACTION=ERROR"
    "ERROR" (cdr (assoc 'ACTION dec)))

  ;; ---------- TEST-06: SHA256 phai 64 hex ----------
  (ts-write tmp (ts-manifest-lines "1.1.0" sha_short "false"))
  (setq dec (mto-upd-decide "1.0.0" (mto-upd-manifest-load tmp) "24.2"))
  (mto-assert-equal "selfup-06: sha256 ngan -> ERROR (tu choi)"
    "ERROR" (cdr (assoc 'ACTION dec)))
  (mto-assert-true "selfup-06: manifest hop le khi sha256 du 64 ky tu"
    (car (mto-upd-manifest-valid-p
           (mto-upd-manifest-load (progn (ts-write tmp (ts-manifest-lines "1.1.0" sha64 "false")) tmp)))))

  ;; ---------- TEST-07: cau truc payload ----------
  (mto-assert-true "selfup-07: payload rong -> tu choi"
    (null (car (mto-upd-payload-valid-p "" "1.0.0"))))
  (mto-assert-true "selfup-07: thu muc khong ton tai -> tu choi"
    (null (car (mto-upd-payload-valid-p "Z:/khong/co" "1.0.0"))))
  (mto-assert-true "selfup-07: chong zip-slip (.. bi tu choi)"
    (mto-upd-unsafe-path-p "../evil.lsp"))
  (mto-assert-true "selfup-07: duong dan tuyet doi bi tu choi"
    (mto-upd-unsafe-path-p "C:/Windows/x.lsp"))

  ;; ---------- TEST-08: backup giu KEEP_BACKUPS=3 ----------
  (mto-assert-equal "selfup-08: KEEP_BACKUPS = 3" 3 *MTO-UPD-KEEP-BACKUPS*)
  (mto-assert-equal "selfup-08: 5 ban -> xoa 2 ban cu nhat (giu 3)"
    '("1.0.0" "1.0.1")
    (mto-upd-backups-to-delete '("1.0.3" "1.0.0" "1.0.2" "1.0.1" "1.0.4") 3))
  (mto-assert-true "selfup-08: 2 ban (<= keep) -> khong xoa gi"
    (null (mto-upd-backups-to-delete '("1.0.0" "1.0.1") 3)))

  ;; ---------- TEST-09: chuoi quyet dinh UPDATE ----------
  (ts-write tmp (ts-manifest-lines "2.0.0" sha64 "false"))
  (setq dec (mto-upd-decide "1.0.0" (mto-upd-manifest-load tmp) "24.2"))
  (mto-assert-equal "selfup-09: 1.0.0 -> 2.0.0 = UPDATE"
    "UPDATE" (cdr (assoc 'ACTION dec)))
  (mto-assert-equal "selfup-09: version dich dung"
    "2.0.0" (cdr (assoc 'VERSION dec)))

  ;; ---------- TEST-10: local moi hon remote -> NOOP ----------
  (setq dec (mto-upd-decide "2.0.0" (mto-upd-manifest-load tmp) "24.2"))
  (mto-assert-equal "selfup-10: local moi hon -> NOOP (khong ha cap)"
    "NOOP" (cdr (assoc 'ACTION dec)))
  ;; minimum_version chan
  (setq mf (mto-upd-manifest-load (progn (ts-write tmp (ts-manifest-lines "3.0.0" sha64 "false")) tmp)))
  (setq dec (mto-upd-decide "0.5.0" mf "24.2"))
  (mto-assert-equal "selfup-10: local cu hon minimum_version -> BLOCKED-MINVER"
    "BLOCKED-MINVER" (cdr (assoc 'ACTION dec)))
  ;; cung phien ban
  (setq mf (mto-upd-manifest-load (progn (ts-write tmp (ts-manifest-lines "1.0.0" sha64 "false")) tmp)))
  (setq dec (mto-upd-decide "1.0.0" mf "24.2"))
  (mto-assert-equal "selfup-10: cung phien ban -> NOOP"
    "NOOP" (cdr (assoc 'ACTION dec)))

  ;; ---------- TEST-11: USER DATA khong nam trong danh sach app ----------
  (mto-assert-true "selfup-11: config KHONG co trong APP-PATHS"
    (null (member "config" *MTO-UPD-APP-PATHS*)))
  (mto-assert-true "selfup-11: user-data co 'config'"
    (member "config" *MTO-UPD-USER-DATA*))
  (mto-assert-true "selfup-11: rules.json khong bi ghi de (khong co trong app-paths)"
    (null (member "config/rules.json" *MTO-UPD-APP-PATHS*)))
  (mto-assert-true "selfup-11: version.json LA app file (duoc phep cap nhat)"
    (member "version.json" *MTO-UPD-APP-PATHS*))

  ;; ---------- TEST-13: marker kich hoat session ke ----------
  (mto-assert-true "selfup-13: ghi marker thanh cong"
    (mto-upd-marker-write "1.5.0" t "payload contains dll"))
  (setq mf (mto-upd-marker-read))
  (mto-assert-true "selfup-13: doc lai marker"
    (not (null mf)))
  (mto-assert-equal "selfup-13: staged_version dung"
    "1.5.0" (cdr (assoc "staged_version" mf)))
  (mto-assert-equal "selfup-13: requires_restart = true"
    "true" (cdr (assoc "requires_restart" mf)))

  ;; ---------- TEST-16: log khong credential + HTTPS enforced ----------
  (mto-assert-equal "selfup-16: strip user:pass khoi URL"
    "https://***@host.local/path"
    (mto-upd-strip-credential "https://user:pass@host.local/path"))
  (mto-assert-true "selfup-16: HTTPS duoc chap nhan"
    (car (mto-upd-source-valid-p "https://update.congty.local/mto")))
  (mto-assert-true "selfup-16: HTTP (khong phai localhost) BI TU CHOI"
    (null (car (mto-upd-source-valid-p "http://update.congty.local/mto"))))
  (mto-assert-true "selfup-16: HTTP localhost duoc phep (de test noi bo)"
    (car (mto-upd-source-valid-p "http://localhost:8080/mto")))
  (mto-assert-true "selfup-16: nguon rong -> tu choi"
    (null (car (mto-upd-source-valid-p ""))))

  ;; ---------- TEST-22 (TASK-022): doc config update.json ----------
  (setq mf (mto-upd-config))
  (mto-assert-equal "selfup-22: config thieu file -> enabled mac dinh false"
    "false" (cdr (assoc 'ENABLED mf)))
  (mto-assert-equal "selfup-22: config thieu file -> keepBackups mac dinh 3"
    "3" (cdr (assoc 'KEEP mf)))
  (mto-assert-equal "selfup-22: config thieu file -> channel stable"
    "stable" (cdr (assoc 'CHANNEL mf)))
  (mto-assert-equal "selfup-22: config thieu file -> source rong"
    "" (cdr (assoc 'SOURCE mf)))
  ;; Ghi config that roi doc lai
  (setq cf (vl-filename-mktemp "mtocfg.json"))
  (ts-write cf (list "{"
                     "  \"enabled\": \"true\","
                     "  \"channel\": \"stable\","
                     "  \"checkOnStartup\": \"true\","
                     "  \"checkIntervalHours\": \"12\","
                     "  \"updateSource\": \"https://update.noibo.local/mto\","
                     "  \"keepBackups\": \"5\""
                     "}"))
  (setq gf (mto-upd-json-load cf (list "enabled" "channel" "checkOnStartup" "checkIntervalHours" "updateSource" "keepBackups")))
  (mto-assert-equal "selfup-22: doc config that -> enabled true"
    "true" (cdr (assoc "enabled" gf)))
  (mto-assert-equal "selfup-22: doc config that -> interval 12"
    "12" (cdr (assoc "checkIntervalHours" gf)))
  (mto-assert-equal "selfup-22: doc config that -> source dung"
    "https://update.noibo.local/mto" (cdr (assoc "updateSource" gf)))
  (mto-assert-equal "selfup-22: doc config that -> keepBackups 5"
    "5" (cdr (assoc "keepBackups" gf)))
  (if (findfile cf) (vl-file-delete cf))

  ;; ---------- Don file tam ----------
  (if (findfile tmp) (vl-file-delete tmp))

  (mto-write-results out-path)
  (princ))

(princ "\ntest-selfup.lsp loaded.")
(princ)
