;;; ============================================================
;;; test-find.lsp -- Test cases cho mto-find.lsp (TASK-010)
;;; Tao entity THAT, xoa THAT de test resolve/zoom
;;; ============================================================

(defun mto-t10-mklayer (name)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  name)

(defun mto-t10-line (layer x1 y1 x2 y2)
  (mto-t10-mklayer layer)
  (entmake (list '(0 . "LINE") '(100 . "AcDbEntity")
                 (cons 8 layer)
                 (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0))))
  (entlast))

(defun mto-t10-h (en) (cdr (assoc 5 (entget en))))

(defun mto-t10-clean (layer / ss i n e)
  (setq ss (ssget "_X" (list (cons 8 layer))))
  (if ss
    (progn
      (setq i 0 n (sslength ss))
      (while (< i n)
        (setq e (ssname ss i))
        (if e (entdel e))
        (setq i (1+ i)))))
  (princ))

(defun mto-run-tests (out-path / e1 e2 h1 h2 db it it2 it3 idx res hits h alive)

  (mto-test-reset)

  (mto-t10-clean "MTO-T10")

  ;; ---------- 1. resolve handle ----------

  (setq e1 (mto-t10-line "MTO-T10" 0 0 100 0))
  (setq e2 (mto-t10-line "MTO-T10" 0 10 100 10))
  (setq h1 (mto-t10-h e1))
  (setq h2 (mto-t10-h e2))

  (mto-assert-true "resolve: handle song -> tra ename"
    (mto-find-resolve h1))
  (mto-assert-equal "resolve: nil -> nil"
    nil (mto-find-resolve nil))
  (mto-assert-equal "resolve: rong -> nil"
    nil (mto-find-resolve ""))
  (mto-assert-equal "resolve: handle khong ton tai -> nil"
    nil (mto-find-resolve "ZZZZZZZZ"))

  ;; xoa that -> resolve phai tra nil (dung logic handent+entget)
  (entdel e2)
  (mto-assert-equal "resolve: sau khi xoa -> nil"
    nil (mto-find-resolve h2))
  (mto-assert-true "resolve: doi tuong khong xoa van resolve"
    (mto-find-resolve h1))

  ;; ---------- 2. alive handles ----------

  (setq it (mto-item-new "Electrical" "Wire" "Wire run"))
  (setq it (mto-item-add-handle it h1))
  (setq it (mto-item-add-handle it h2))
  (setq it (mto-item-recalc it))

  (setq alive (mto-find-alive-handles it))
  (mto-assert-equal "alive: con 1 handle song"
    1 (length alive))
  (mto-assert-equal "alive: dung la h1"
    h1 (car alive))

  ;; ---------- 3. index ----------

  (setq it2 (mto-item-new "ELV" "CAM" "Camera Dome"))
  (setq it2 (mto-item-set it2 'UNIT "cai"))
  (setq it2 (mto-blk-apply-manual it2 4))
  (setq it3 (mto-item-new "Plumbing" "Valve" "Valve DN25"))
  (setq it3 (mto-item-set it3 'UNIT "cai"))
  (setq it3 (mto-blk-apply-manual it3 2))

  (setq db (mto-db-new))
  (setq db (mto-db-merge-item db it))
  (setq db (mto-db-merge-item db it2))
  (setq db (mto-db-merge-item db it3))

  (setq idx (mto-find-build-index db))
  (mto-assert-equal "index: 3 dong"
    3 (length idx))
  (mto-assert-equal "index: STT bat dau tu 1"
    1 (car (car idx)))

  ;; STT 1 = Electrical (sap xep theo CATEGORY)
  (mto-assert-equal "by-index: STT 1 la Electrical"
    "Electrical" (mto-item-get (mto-find-by-index db 1) 'CATEGORY))

  (mto-assert-equal "by-index: STT 2 la ELV"
    "ELV" (mto-item-get (mto-find-by-index db 2) 'CATEGORY))

  (mto-assert-equal "by-index: STT 99 -> nil"
    nil (mto-find-by-index db 99))

  ;; ---------- 4. matches / search ----------

  (mto-assert-true "matches: khop theo NAME"
    (mto-find-matches-p it2 "camera"))
  (mto-assert-true "matches: khop khong phan biet hoa/thuong"
    (mto-find-matches-p it2 "CAMERA"))
  (mto-assert-true "matches: khop theo TYPE"
    (mto-find-matches-p it3 "valve"))
  (mto-assert-true "matches: khop theo CATEGORY"
    (mto-find-matches-p it3 "plumbing"))
  (mto-assert-true "matches: khop theo HANDLE"
    (mto-find-matches-p it h1))
  (mto-assert-true "matches: khong khop -> nil"
    (not (mto-find-matches-p it2 "khong-co-gi-khop")))

  (setq hits (mto-find-search db "camera"))
  (mto-assert-equal "search: 'camera' -> 1 dong"
    1 (length hits))

  (setq hits (mto-find-search db "a"))
  (mto-assert-true "search: 'a' -> nhieu dong"
    (>= (length hits) 2))

  (setq hits (mto-find-search db ""))
  (mto-assert-equal "search: rong -> nil"
    nil hits)

  (setq hits (mto-find-search db "zzzz"))
  (mto-assert-equal "search: khong tim thay -> nil"
    nil hits)

  ;; ---------- 5. zoom THAT (khong dung ActiveX) ----------

  (mto-assert-true "zoom: handle song -> T"
    (mto-find-zoom-handle h1))
  (mto-assert-equal "zoom: handle chet -> nil"
    nil (mto-find-zoom-handle h2))
  (mto-assert-equal "zoom: handle khong ton tai -> nil"
    nil (mto-find-zoom-handle "ZZZZZZZZ"))

  ;; zoom item: chon handle con song
  (setq h (mto-find-zoom-item it))
  (mto-assert-equal "zoom-item: tra ve handle con song (h1)"
    h1 h)

  ;; item toan handle chet -> nil
  (setq it4 (mto-item-new "Electrical" "Dead" "Dead item"))
  (setq it4 (mto-item-add-handle it4 h2))
  (mto-assert-equal "zoom-item: toan handle chet -> nil"
    nil (mto-find-zoom-item it4))

  ;; ---------- 6. select ----------

  (mto-assert-true "select: handle song -> T"
    (mto-find-select-handle h1))
  (mto-assert-equal "select: handle chet -> nil"
    nil (mto-find-select-handle h2))

  ;; ---------- 7. khong crash khi DB rong ----------

  (mto-assert-equal "search: db rong -> nil"
    nil (mto-find-search '() "abc"))
  (mto-assert-equal "index: db rong -> nil"
    nil (mto-find-build-index '()))

  ;; don dep
  (mto-t10-clean "MTO-T10")

  ;; ---------- Ghi ket qua ----------
  (mto-write-results out-path)
  (princ))

(princ "\ntest-find.lsp loaded.")
(princ)
