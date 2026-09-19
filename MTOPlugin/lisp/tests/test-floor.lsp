;;; ============================================================
;;; test-floor.lsp -- Test cases cho mto-floor.lsp (TASK-015)
;;; ============================================================

(defun mto-run-tests (out-path / it it2 it3 db res rules lst flt groups)

  (mto-test-reset)

  ;; ---------- 1. set / get ----------

  (setq it (mto-item-new "Electrical" "Light" "Den LED"))
  (setq it (mto-item-add-auto it 10))
  (setq it (mto-item-set it 'LAYER "EL-LIGHT-T1"))
  (setq it (mto-item-recalc it))

  (mto-assert-equal "set: FLOOR ban dau rong"
    "" (mto-floor-of-item it))

  (setq it (mto-floor-set it "T1" "Zone-A" "P101"))
  (mto-assert-equal "set: FLOOR"  "T1"     (mto-floor-of-item it))
  (mto-assert-equal "set: ZONE"   "Zone-A" (mto-zone-of-item it))
  (mto-assert-equal "set: AREA"   "P101"   (mto-area-of-item it))

  ;; nil -> ""
  (setq it2 (mto-floor-set (mto-item-new "ELV" "CAM" "Cam") nil nil nil))
  (mto-assert-equal "set: nil -> rong" "" (mto-floor-of-item it2))

  ;; ---------- 2. wildcard match layer ----------

  (mto-assert-true "match: EL-* khop EL-LIGHT-T1"
    (mto-floor-match-p "EL-LIGHT-T1" "EL-*"))
  (mto-assert-true "match: EL-LIGHT-* khop"
    (mto-floor-match-p "EL-LIGHT-T1" "EL-LIGHT-*"))
  (mto-assert-true "match: khong phan biet hoa/thuong"
    (mto-floor-match-p "el-light-t1" "EL-*"))
  (mto-assert-true "match: PL-* KHONG khop EL-"
    (not (mto-floor-match-p "EL-LIGHT-T1" "PL-*")))
  (mto-assert-true "match: '?' khop 1 ky tu"
    (mto-floor-match-p "EL1" "EL?"))
  (mto-assert-true "match: nil -> nil"
    (not (mto-floor-match-p nil "EL-*")))

  ;; ---------- 3. find-rule ----------

  (setq rules (list (cons "EL-LIGHT-*" "T1") (cons "EL-*" "T2")))
  (mto-assert-equal "rule: pattern cu the thang"
    "T1" (mto-floor-find-rule "EL-LIGHT-T1" rules))
  (mto-assert-equal "rule: pattern tong quat"
    "T2" (mto-floor-find-rule "EL-SOCKET-T2" rules))
  (mto-assert-equal "rule: khong khop -> nil"
    nil (mto-floor-find-rule "PL-PIPE-T1" rules))

  ;; ---------- 4. assign by layer ----------

  (setq it  (mto-item-new "Electrical" "Light" "Den T1"))
  (setq it  (mto-item-set it 'LAYER "EL-LIGHT-T1"))
  (setq it  (mto-item-add-auto it 10))
  (setq it  (mto-item-add-length it 50))
  (setq it  (mto-item-recalc it))

  (setq it2 (mto-item-new "Electrical" "Socket" "O cam T2"))
  (setq it2 (mto-item-set it2 'LAYER "EL-SOCKET-T2"))
  (setq it2 (mto-item-add-auto it2 20))
  (setq it2 (mto-item-recalc it2))

  (setq it3 (mto-item-new "Plumbing" "Pipe" "Ong T1"))
  (setq it3 (mto-item-set it3 'LAYER "PL-PIPE-T1"))
  (setq it3 (mto-item-add-length it3 80))
  (setq it3 (mto-item-recalc it3))

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))
  (setq db (mto-db-merge-item db it2))
  (setq db (mto-db-merge-item db it3))

  (setq rules (list (cons "EL-LIGHT-*" "T1")
                    (cons "EL-SOCKET-*" "T2")
                    (cons "PL-*" "T1")))
  (setq res (mto-floor-assign-by-layer db rules "Zone-A" ""))
  (setq db (car res))
  (mto-assert-equal "assign-by-layer: gan 3 dong"
    3 (cdr res))

  (mto-assert-equal "assign: it -> T1"
    "T1" (mto-floor-of-item (mto-find-by-index db 1)))
  (mto-assert-equal "assign: it2 -> T2"
    "T2" (mto-floor-of-item (mto-find-by-index db 2)))
  (mto-assert-equal "assign: it3 -> T1"
    "T1" (mto-floor-of-item (mto-find-by-index db 3)))
  (mto-assert-equal "assign: ZONE duoc gan"
    "Zone-A" (mto-zone-of-item (mto-find-by-index db 1)))

  ;; layer khong khop -> khong gan
  (setq rules (list (cons "KHONGCO-*" "TX")))
  (setq res (mto-floor-assign-by-layer db rules nil nil))
  (mto-assert-equal "assign: khong khop -> 0"
    0 (cdr res))

  ;; ---------- 5. assign by handles (vung chon) ----------

  (setq it4 (mto-item-new "ELV" "CAM" "Camera vuon"))
  (setq it4 (mto-item-add-handle it4 "HANDLE-A"))
  (setq it4 (mto-item-add-handle it4 "HANDLE-B"))
  (setq db (mto-db-merge-item db it4))

  (setq res (mto-floor-assign-by-handles db (list "HANDLE-A") "T3" "Zone-B" "P301"))
  (setq db (car res))
  (mto-assert-equal "assign-by-handles: 1 dong"
    1 (cdr res))

  ;; camera theo handle
  (setq cam nil)
  (foreach x db (if (= (mto-item-get x 'NAME) "Camera vuon") (setq cam x)))
  (mto-assert-equal "assign-by-handles: FLOOR = T3"
    "T3" (mto-floor-of-item cam))
  (mto-assert-equal "assign-by-handles: AREA = P301"
    "P301" (mto-area-of-item cam))

  ;; handle khong khop -> 0
  (setq res (mto-floor-assign-by-handles db (list "HANDLE-ZZZ") "T9" nil nil))
  (mto-assert-equal "assign-by-handles: khong khop -> 0"
    0 (cdr res))

  ;; ---------- 6. floor list / filter / unassigned ----------

  (setq lst (mto-floor-list db))
  (mto-assert-equal "list: 3 tang (T1,T2,T3)"
    3 (length lst))
  (mto-assert-equal "list: sap xep"
    '("T1" "T2" "T3") lst)

  (setq flt (mto-floor-filter db "T1"))
  (mto-assert-equal "filter: T1 -> 2 dong"
    2 (length flt))

  (setq flt (mto-floor-filter db "T2"))
  (mto-assert-equal "filter: T2 -> 1 dong"
    1 (length flt))

  (setq flt (mto-floor-filter db "T9"))
  (mto-assert-equal "filter: T9 -> 0 dong"
    0 (length flt))

  (mto-assert-equal "unassigned: 0 dong"
    0 (mto-floor-unassigned db))

  ;; them item chua gan -> unassigned = 1
  (setq it5 (mto-item-new "Electrical" "Fan" "Quat chua gan"))
  (setq it5 (mto-item-add-auto it5 3))
  (setq it5 (mto-item-recalc it5))
  (setq db (mto-db-merge-item db it5))
  (mto-assert-equal "unassigned: 1 dong sau khi them"
    1 (mto-floor-unassigned db))

  ;; ---------- 7. subtotal theo FLOOR ----------

  (setq groups (mto-floor-subtotal db))
  ;; T1 (2 dong), T2 (1), T3 (1), "" (1) -> 4 nhom
  (mto-assert-equal "subtotal: 4 nhom"
    4 (length groups))

  (setq g (assoc "T1" groups))
  (mto-assert-true "subtotal: co nhom T1" g)
  ;; T1: Den T1 NET=10 + Ong T1 NET=0 (chi co LEN) = 10
  (mto-assert-close "subtotal T1: NET = 10"
    10.0 (mto-sub-net-of g) 0.0001)
  (mto-assert-close "subtotal T1: LEN = 130 (50+80)"
    130.0 (mto-sub-total-of g 'LEN) 0.0001)

  (setq g (assoc "T2" groups))
  (mto-assert-close "subtotal T2: NET = 20"
    20.0 (mto-sub-net-of g) 0.0001)

  ;; nhom chua gan ton tai
  (setq g (assoc "" groups))
  (mto-assert-true "subtotal: co nhom chua gan" g)

  ;; ---------- 8. set-all ----------

  (setq db2 (mto-floor-set-all db "T9" "Z9" "A9"))
  (mto-assert-equal "set-all: moi dong deu T9"
    0 (mto-floor-unassigned db2))
  (mto-assert-equal "set-all: floor list chi con T9"
    '("T9") (mto-floor-list db2))
  (mto-assert-equal "set-all: so dong khong doi"
    (mto-db-count db) (mto-db-count db2))

  ;; ---------- 9. DB rong ----------

  (mto-assert-equal "list: db rong -> nil"
    nil (mto-floor-list '()))
  (mto-assert-equal "unassigned: db rong -> 0"
    0 (mto-floor-unassigned '()))
  (mto-assert-equal "subtotal: db rong -> nil"
    nil (mto-floor-subtotal '()))

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-floor.lsp loaded.")
(princ)
