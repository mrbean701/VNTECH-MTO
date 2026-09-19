;;; ============================================================
;;; test-formula.lsp -- Test cases cho mto-formula.lsp (TASK-013)
;;; ============================================================

(defun mto-run-tests (out-path / p v run it it2 db res rules)

  (mto-test-reset)

  ;; ---------- 1. chuan hoa phep toan ----------

  (mto-assert-equal "op: 'x' -> nhan"        "*" (mto-formula-op-normalize "x"))
  (mto-assert-equal "op: 'X' -> nhan"        "*" (mto-formula-op-normalize "X"))
  (mto-assert-equal "op: '*' -> nhan"        "*" (mto-formula-op-normalize "*"))
  (mto-assert-equal "op: ':' -> chia"        "/" (mto-formula-op-normalize ":"))
  (mto-assert-equal "op: '/' -> chia"        "/" (mto-formula-op-normalize "/"))
  (mto-assert-equal "op: '+' -> cong"        "+" (mto-formula-op-normalize "+"))
  (mto-assert-equal "op: '-' -> tru"         "-" (mto-formula-op-normalize "-"))
  (mto-assert-equal "op: 'abc' -> nil"       nil (mto-formula-op-normalize "abc"))
  (mto-assert-true  "op-p: 'x' la phep toan" (mto-formula-op-p "x"))
  (mto-assert-true  "op-p: 'LEN' khong phai" (not (mto-formula-op-p "LEN")))

  ;; ---------- 2. parse ----------

  (setq p (mto-formula-parse "LEN * 1.05"))
  (mto-assert-equal "parse: 3 phan tu"      3 (length p))
  (mto-assert-equal "parse: a = LEN"        "LEN" (nth 0 p))
  (mto-assert-equal "parse: op = *"         "*"   (nth 1 p))
  (mto-assert-equal "parse: b = 1.05"       "1.05" (nth 2 p))

  (setq p (mto-formula-parse "SL x 2"))
  (mto-assert-equal "parse: 'x' thanh '*'"  "*" (nth 1 p))
  (mto-assert-equal "parse: b = 2"          "2" (nth 2 p))

  (setq p (mto-formula-parse "QTY + 5"))
  (mto-assert-equal "parse: cong"           "+" (nth 1 p))

  (setq p (mto-formula-parse "LEN / 2"))
  (mto-assert-equal "parse: chia"           "/" (nth 1 p))

  (setq p (mto-formula-parse "LEN - 3"))
  (mto-assert-equal "parse: tru"            "-" (nth 1 p))

  ;; nhieu khoang trang
  (setq p (mto-formula-parse "   LEN    *    2   "))
  (mto-assert-equal "parse: nhieu space van dung" 3 (length p))
  (mto-assert-equal "parse: a dung"         "LEN" (nth 0 p))
  (mto-assert-equal "parse: b dung"         "2"   (nth 2 p))

  ;; sai dinh dang
  (mto-assert-equal "parse: 1 token -> nil"
    nil (mto-formula-parse "LEN"))
  (mto-assert-equal "parse: 2 token -> nil"
    nil (mto-formula-parse "LEN *"))
  (mto-assert-equal "parse: 4 token -> nil"
    nil (mto-formula-parse "LEN * 2 * 3"))
  (mto-assert-equal "parse: toan tu sai -> nil"
    nil (mto-formula-parse "LEN abc 2"))
  (mto-assert-equal "parse: rong -> nil"
    nil (mto-formula-parse ""))
  (mto-assert-equal "parse: nil -> nil"
    nil (mto-formula-parse nil))

  ;; ---------- 3. lookup ----------

  (mto-assert-close "lookup: so nguyen"   5.0    (mto-formula-lookup "5" nil) 0.0001)
  (mto-assert-close "lookup: so thap phan" 1.05  (mto-formula-lookup "1.05" nil) 0.0001)
  (mto-assert-equal "lookup: bien khong ton tai -> nil"
    nil (mto-formula-lookup "KHONGBIET" nil))

  (setq v (list (cons "LEN" 120.0) (cons "SL" 10.0)))
  (mto-assert-close "lookup: bien LEN"     120.0 (mto-formula-lookup "LEN" v) 0.0001)
  (mto-assert-close "lookup: bien chu thuong"
    120.0 (mto-formula-lookup "len" v) 0.0001)

  ;; ---------- 4. eval ----------

  (setq v (list (cons "LEN" 120.0) (cons "SL" 10.0)))
  (mto-assert-close "eval: LEN * 1.05 = 126"
    126.0 (mto-formula-eval (mto-formula-parse "LEN * 1.05") v) 0.0001)

  (mto-assert-close "eval: SL + 5 = 15"
    15.0 (mto-formula-eval (mto-formula-parse "SL + 5") v) 0.0001)

  (mto-assert-close "eval: LEN - 20 = 100"
    100.0 (mto-formula-eval (mto-formula-parse "LEN - 20") v) 0.0001)

  (mto-assert-close "eval: LEN / 4 = 30"
    30.0 (mto-formula-eval (mto-formula-parse "LEN / 4") v) 0.0001)

  (mto-assert-equal "eval: chia cho 0 -> nil (an toan)"
    nil (mto-formula-eval (mto-formula-parse "LEN / 0") v))

  (mto-assert-equal "eval: bien thieu -> nil"
    nil (mto-formula-eval (mto-formula-parse "KHONGCO * 2") v))

  (mto-assert-equal "eval: parsed nil -> nil"
    nil (mto-formula-eval nil v))

  ;; ---------- 5. run (Formula / Input / Result / Explanation) ----------

  (setq run (mto-formula-run "LEN * 1.05" v))
  (mto-assert-true  "run: tra ket qua"   run)
  (mto-assert-close "run: result = 126"
    126.0 (car run) 0.0001)
  (mto-assert-true  "run: explanation chua cong thuc"
    (vl-string-search "LEN * 1.05" (cdr run)))
  (mto-assert-true  "run: explanation chua ket qua"
    (vl-string-search "126" (cdr run)))

  (mto-assert-equal "run: cong thuc sai -> nil"
    nil (mto-formula-run "LEN abc 2" v))
  (mto-assert-equal "run: thieu bien -> nil"
    nil (mto-formula-run "KHONGCO * 2" v))

  ;; ---------- 6. vars cua item ----------

  (setq it (mto-item-new "Electrical" "Tray" "Cable tray"))
  (setq it (mto-item-add-auto it 10))
  (setq it (mto-item-add-length it 120))
  (setq it (mto-item-set it 'DEDUCTION 5.0))
  (setq it (mto-item-recalc it))

  (setq v (mto-formula-vars-of-item it))
  (mto-assert-close "vars: SL = QTY = 10"   10.0  (cdr (assoc "SL" v)) 0.0001)
  (mto-assert-close "vars: LEN = 120"      120.0  (cdr (assoc "LEN" v)) 0.0001)
  (mto-assert-close "vars: DED = 5"          5.0  (cdr (assoc "DED" v)) 0.0001)
  (mto-assert-close "vars: NETQTY = 5"       5.0  (cdr (assoc "NETQTY" v)) 0.0001)

  ;; ---------- 7. apply-item ----------

  (setq res (mto-formula-apply-item it "LEN * 1.05" nil))
  (mto-assert-true "apply: tra ket qua" res)
  (setq it2 (car res))
  (mto-assert-equal "apply: luu FORMULA"
    "LEN * 1.05" (mto-item-get it2 'FORMULA))
  (mto-assert-close "apply: luu FORMULA-VALUE = 126"
    126.0 (mto-item-get it2 'FORMULA-VALUE) 0.0001)
  (mto-assert-true "apply: luu FORMULA-EXPLAIN"
    (mto-item-get it2 'FORMULA-EXPLAIN))
  ;; khong ghi de NETQTY khi apply-net = nil
  (mto-assert-close "apply: NETQTY KHONG doi (apply-net=nil)"
    5.0 (mto-item-get it2 'NETQTY) 0.0001)

  ;; apply-net = T -> ghi vao NETQTY
  (setq res (mto-formula-apply-item it "LEN * 1.05" t))
  (setq it2 (car res))
  (mto-assert-close "apply-net: NETQTY = 126"
    126.0 (mto-item-get it2 'NETQTY) 0.0001)

  (mto-assert-equal "apply: cong thuc sai -> nil"
    nil (mto-formula-apply-item it "SAI DINH DANG" nil))

  ;; ---------- 8. apply-db theo rules ----------

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))

  (setq it3 (mto-item-new "Plumbing" "Pipe" "Pipe DN25"))
  (setq it3 (mto-item-add-length it3 50))
  (setq it3 (mto-item-recalc it3))
  (setq db (mto-db-merge-item db it3))

  ;; rule theo NAME
  (setq rules (list (cons "Cable tray" "LEN * 1.10")))
  (setq res (mto-formula-apply-db db rules nil))
  (mto-assert-equal "apply-db: 1 dong duoc ap dung"
    1 (cdr (assoc 'APPLIED res)))
  (mto-assert-equal "apply-db: 0 that bai"
    0 (cdr (assoc 'FAILED res)))

  ;; rule theo TYPE
  (setq rules (list (cons "Pipe" "LEN + 5")))
  (setq res (mto-formula-apply-db db rules nil))
  (mto-assert-equal "apply-db: rule theo TYPE"
    1 (cdr (assoc 'APPLIED res)))

  ;; rule khong khop -> 0
  (setq rules (list (cons "KHONGCO" "LEN * 2")))
  (setq res (mto-formula-apply-db db rules nil))
  (mto-assert-equal "apply-db: khong khop -> 0"
    0 (cdr (assoc 'APPLIED res)))

  ;; rule sai dinh dang -> dem vao FAILED
  (setq rules (list (cons "Cable tray" "SAI CU PHAP")))
  (setq res (mto-formula-apply-db db rules nil))
  (mto-assert-equal "apply-db: cong thuc sai -> FAILED = 1"
    1 (cdr (assoc 'FAILED res)))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-formula.lsp loaded.")
(princ)
