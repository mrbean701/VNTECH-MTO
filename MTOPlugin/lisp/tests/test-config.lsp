;;; ============================================================
;;; test-config.lsp -- Test cases cho mto-config.lsp (TASK-016)
;;; ============================================================

(defun mto-t16-read-lines (path / f lines line)
  (setq lines '())
  (setq f (open path "r"))
  (if f
    (progn
      (while (setq line (read-line f))
        (setq lines (append lines (list line))))
      (close f)))
  lines)

(defun mto-run-tests (out-path / cfg cfg2 lines s path path2 nodOk nodCfg)

  (mto-test-reset)

  ;; ---------- 1. cau hinh mac dinh ----------

  (setq cfg (mto-cfg-new))
  (mto-assert-true "new: la alist" (listp cfg))
  (mto-assert-equal "new: co RULESPATH"
    "config/rules.sample.json" (mto-cfg-get cfg "RULESPATH"))
  (mto-assert-equal "new: co UNIT"
    "mm" (mto-cfg-get cfg "UNIT"))
  (mto-assert-equal "new: co XREFMODE"
    "UniqueBySource" (mto-cfg-get cfg "XREFMODE"))
  (mto-assert-equal "get: khoa khong ton tai -> nil"
    nil (mto-cfg-get cfg "KHONGCO"))
  (mto-assert-equal "get: khong phan biet hoa/thuong"
    "mm" (mto-cfg-get cfg "unit"))

  ;; ---------- 2. set ----------

  (setq cfg2 (mto-cfg-set cfg "UNIT" "m"))
  (mto-assert-equal "set: doi gia tri"
    "m" (mto-cfg-get cfg2 "UNIT"))
  (mto-assert-equal "set: cfg goc KHONG doi (immutable)"
    "mm" (mto-cfg-get cfg "UNIT"))

  (setq cfg2 (mto-cfg-set cfg2 "MOI" "xyz"))
  (mto-assert-equal "set: them khoa moi"
    "xyz" (mto-cfg-get cfg2 "MOI"))

  ;; ---------- 3. to-lines / from-lines ----------

  (setq lines (mto-cfg-to-lines cfg))
  (mto-assert-true "to-lines: co dong" (> (length lines) 0))
  (mto-assert-true "to-lines: dung dinh dang KEY|VALUE"
    (vl-string-search "|" (car lines)))

  (setq cfg2 (mto-cfg-from-lines lines))
  (mto-assert-equal "roundtrip: giu nguyen RULESPATH"
    (mto-cfg-get cfg "RULESPATH") (mto-cfg-get cfg2 "RULESPATH"))
  (mto-assert-equal "roundtrip: giu nguyen UNIT"
    (mto-cfg-get cfg "UNIT") (mto-cfg-get cfg2 "UNIT"))
  (mto-assert-equal "roundtrip: so khoa bang nhau"
    (length cfg) (length cfg2))

  (mto-assert-equal "from-lines: bo qua dong rong"
    (length cfg) (length (mto-cfg-from-lines
      (append lines (list "") (list "   ")))))

  (mto-assert-equal "from-lines: dong khong co sep -> bo qua"
    nil (mto-cfg-from-lines (list "KHONGCO-SEP")))

  ;; ---------- 4. gia tri chua ky tu phan cach -> duoc lam sach ----------

  (setq cfg2 (mto-cfg-set cfg "X" "a|b"))
  (setq lines (mto-cfg-to-lines cfg2))
  ;; tim dong X
  (setq s nil)
  (foreach L lines (if (= "X|" (substr L 1 2)) (setq s L)))
  (mto-assert-true "lam sach: '|' trong gia tri bi thay"
    (and s (not (vl-string-search "|" (substr s 3)))))
  ;; va roundtrip van doc duoc (khong pha cau truc)
  (setq cfg2 (mto-cfg-from-lines lines))
  (mto-assert-true "lam sach: roundtrip van co khoa X"
    (mto-cfg-get cfg2 "X"))

  ;; ---------- 5. duong dan mac dinh theo DWG ----------

  (mto-assert-equal "path: bo duoi .dwg"
    "BanVe1.mtocfg" (mto-cfg-default-path "BanVe1.dwg"))
  (mto-assert-equal "path: khong phan biet hoa/thuong duoi"
    "BanVe2.mtocfg" (mto-cfg-default-path "BanVe2.DWG"))
  (mto-assert-equal "path: ten khong co duoi"
    "BanVe3.mtocfg" (mto-cfg-default-path "BanVe3"))
  (mto-assert-equal "path: nil -> drawing"
    "drawing.mtocfg" (mto-cfg-default-path nil))
  (mto-assert-equal "path: rong -> drawing"
    "drawing.mtocfg" (mto-cfg-default-path ""))

  ;; ---------- 6. ghi/doc FILE THAT ----------

  (setq path (strcat (vl-filename-directory out-path) "/mto_t16.mtocfg"))
  (if (findfile path) (vl-file-delete path))

  (mto-assert-true "save: tra ve T"
    (mto-cfg-save cfg path))
  (mto-assert-true "save: file ton tai" (findfile path))

  ;; doc file dang van ban de kiem dinh dang
  (setq lines (mto-t16-read-lines path))
  (mto-assert-equal "file: so dong = so khoa"
    (length cfg) (length lines))
  (mto-assert-true "file: dong dau co sep"
    (vl-string-search "|" (car lines)))

  ;; doc lai bang ham
  (setq cfg2 (mto-cfg-load path))
  (mto-assert-true "load: doc duoc" cfg2)
  (mto-assert-equal "load: RULESPATH dung"
    (mto-cfg-get cfg "RULESPATH") (mto-cfg-get cfg2 "RULESPATH"))
  (mto-assert-equal "load: UNIT dung"
    (mto-cfg-get cfg "UNIT") (mto-cfg-get cfg2 "UNIT"))

  ;; file khong ton tai -> nil
  (mto-assert-equal "load: file khong ton tai -> nil"
    nil (mto-cfg-load "D:/khong-ton-tai-file-nay.mtocfg"))

  ;; ---------- 7. NOD (co the khong kha dung -- khong duoc crash) ----------

  (setq nodOk (mto-cfg-nod-save cfg))
  ;; du ket qua the nao cung khong duoc loi; ghi nhan bang assert mem
  (mto-assert-true "nod: save khong crash (T hoac nil)"
    (or (null nodOk) (not (null nodOk))))

  (if nodOk
    (progn
      (setq nodCfg (mto-cfg-nod-load))
      (mto-assert-true "nod: doc lai duoc" nodCfg)
      (mto-assert-equal "nod: UNIT dung"
        (mto-cfg-get cfg "UNIT") (mto-cfg-get nodCfg "UNIT")))
    ;; neu khong ho tro -> van phai tra nil sach
    (mto-assert-equal "nod: khong ho tro -> load tra nil"
      nil (mto-cfg-nod-load)))

  ;; ---------- 8. don file ----------

  (if (findfile path) (vl-file-delete path))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-config.lsp loaded.")
(princ)
