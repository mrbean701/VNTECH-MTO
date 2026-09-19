;;; ============================================================
;;; test-subtotal.lsp -- Test cases cho mto-subtotal.lsp (TASK-014)
;;; ============================================================

(defun mto-run-tests (out-path / it it2 it3 db grp groups summary res rules minNet)

  (mto-test-reset)

  ;; ---------- 1. deduction co ban ----------

  (setq it (mto-item-new "Electrical" "Tray" "Cable tray"))
  (setq it (mto-item-add-auto it 100))
  (setq it (mto-item-add-length it 120))
  (setq it (mto-item-recalc it))
  (mto-assert-close "ded: ban dau NETQTY = QTY"
    100.0 (mto-item-get it 'NETQTY) 0.0001)

  (setq it (mto-sub-set-deduction it 10))
  (mto-assert-close "ded: dat DEDUCTION = 10"
    10.0 (mto-item-get it 'DEDUCTION) 0.0001)
  (mto-assert-close "ded: NETQTY = QTY - DED = 90"
    90.0 (mto-item-get it 'NETQTY) 0.0001)

  (setq it (mto-sub-add-deduction it 5))
  (mto-assert-close "ded: cong don -> DED = 15"
    15.0 (mto-item-get it 'DEDUCTION) 0.0001)
  (mto-assert-close "ded: NETQTY = 85"
    85.0 (mto-item-get it 'NETQTY) 0.0001)

  ;; am -> hoan lai
  (setq it (mto-sub-add-deduction it -5))
  (mto-assert-close "ded: am -> DED = 10 (hoan lai)"
    10.0 (mto-item-get it 'DEDUCTION) 0.0001)

  ;; ---------- 2. clamp ----------

  (setq it (mto-sub-set-deduction it -50))
  (setq it (mto-sub-clamp-deduction it))
  (mto-assert-close "clamp: DED am -> 0"
    0.0 (mto-item-get it 'DEDUCTION) 0.0001)
  (mto-assert-close "clamp: NETQTY ve QTY"
    100.0 (mto-item-get it 'NETQTY) 0.0001)

  (setq it (mto-sub-set-deduction it 500))
  (setq it (mto-sub-clamp-deduction it))
  (mto-assert-close "clamp: DED > QTY -> = QTY"
    100.0 (mto-item-get it 'DEDUCTION) 0.0001)
  (mto-assert-close "clamp: NETQTY khong am"
    0.0 (mto-item-get it 'NETQTY) 0.0001)

  ;; dat lai de dung cho cac test sau
  (setq it (mto-sub-set-deduction it 10))

  ;; ---------- 3. du lieu nhieu nhom ----------

  (setq it2 (mto-item-new "Electrical" "DB" "DB 100A"))
  (setq it2 (mto-item-add-auto it2 5))
  (setq it2 (mto-item-set it2 'LAYER "EL-DB"))
  (setq it2 (mto-sub-set-deduction it2 1))

  (setq it3 (mto-item-new "Plumbing" "Pipe" "Pipe DN25"))
  (setq it3 (mto-item-add-auto it3 20))
  (setq it3 (mto-item-add-length it3 50))
  (setq it3 (mto-item-set it3 'LAYER "PL-PIPE"))
  (mto-item-recalc it3)

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))
  (setq db (mto-db-merge-item db it2))
  (setq db (mto-db-merge-item db it3))
  (mto-assert-equal "db: 3 dong"
    3 (mto-db-count db))

  ;; ---------- 4. group theo CATEGORY ----------

  (setq groups (mto-sub-group db 'CATEGORY))
  (mto-assert-equal "group: 2 he"
    2 (length groups))

  (setq grp (assoc "Electrical" groups))
  (mto-assert-true "group: co nhom Electrical" grp)
  ;; Electrical: it (QTY 100, DED 10, NET 90) + it2 (QTY 5, DED 1, NET 4)
  (mto-assert-close "group Electrical: QTY = 105"
    105.0 (mto-sub-total-of grp 'QTY) 0.0001)
  (mto-assert-close "group Electrical: DED = 11"
    11.0 (mto-sub-deduction-of grp) 0.0001)
  (mto-assert-close "group Electrical: NET = 94"
    94.0 (mto-sub-net-of grp) 0.0001)
  (mto-assert-close "group Electrical: COUNT = 2"
    2.0 (mto-sub-total-of grp 'COUNT) 0.0001)

  (setq grp (assoc "Plumbing" groups))
  (mto-assert-close "group Plumbing: QTY = 20"
    20.0 (mto-sub-total-of grp 'QTY) 0.0001)
  (mto-assert-close "group Plumbing: DED = 0"
    0.0 (mto-sub-deduction-of grp) 0.0001)
  (mto-assert-close "group Plumbing: LEN = 50"
    50.0 (mto-sub-total-of grp 'LEN) 0.0001)

  ;; ---------- 5. group theo LAYER (generic, khong hard-code) ----------

  (setq groups (mto-sub-group db 'LAYER))
  (mto-assert-true "group LAYER: hoat dong voi khoa khac"
    (>= (length groups) 2))

  ;; ---------- 6. summary + grand total ----------

  (setq summary (mto-sub-summary db 'CATEGORY))
  (mto-assert-true "summary: tra ve (GROUPS . GRAND)" summary)
  (setq groups (car summary))
  (mto-assert-equal "summary: 2 nhom"
    2 (length groups))
  ;; grand: NET = 94 + 20 = 114
  (mto-assert-close "summary: grand NET = 114"
    114.0 (cdr (assoc 'QTY (cdr summary))) 0.0001)
  (mto-assert-close "summary: grand LEN = 170"
    170.0 (cdr (assoc 'LEN (cdr summary))) 0.0001)
  (mto-assert-close "summary: grand COUNT = 3"
    3.0 (cdr (assoc 'COUNT (cdr summary))) 0.0001)

  ;; ---------- 7. ap dung deduction hang loat theo rules ----------

  (setq rules (list (cons "Electrical" 5.0)))
  (setq res (mto-sub-apply-deductions db 'CATEGORY rules))
  (mto-assert-equal "apply-deductions: 2 dong Electrical"
    2 (cdr res))

  ;; LUU Y: ham tra ve DB MOI (item immutable) -> phai dung (car res)
  (setq db (car res))

  ;; kiem tra da cong them 5 VA clamp co tac dung
  (setq summary (mto-sub-summary db 'CATEGORY))
  (setq grp (assoc "Electrical" (car summary)))
  ;; it : QTY=100, DED 10+5 = 15  (khong bi clamp)
  ;; it2: QTY=5,   DED  1+5 = 6 -> CLAMP ve 5 (khong de NETQTY am)
  ;; => tong DED Electrical = 15 + 5 = 20
  (mto-assert-close "apply-deductions: DED = 20 (co clamp)"
    20.0 (mto-sub-deduction-of grp) 0.0001)

  ;; xac nhan clamp: khong dong nao co NETQTY am
  (setq minNet 999999.0)
  (foreach x (car summary)
    (if (< (mto-sub-net-of x) minNet) (setq minNet (mto-sub-net-of x))))
  (mto-assert-true "apply-deductions: khong nhom nao co NETQTY am"
    (>= minNet 0.0))

  ;; rule khong khop -> 0
  (setq rules (list (cons "KHONGCO" 5.0)))
  (setq res (mto-sub-apply-deductions db 'CATEGORY rules))
  (mto-assert-equal "apply-deductions: khong khop -> 0"
    0 (cdr res))

  ;; ---------- 8. DB rong ----------

  (mto-assert-equal "group: db rong -> nil"
    nil (mto-sub-group '() 'CATEGORY))

  (setq summary (mto-sub-summary '() 'CATEGORY))
  (mto-assert-equal "summary rong: 0 nhom"
    0 (length (car summary)))
  (mto-assert-close "summary rong: grand NET = 0"
    0.0 (cdr (assoc 'QTY (cdr summary))) 0.0001)

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-subtotal.lsp loaded.")
(princ)
