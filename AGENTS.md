# DSH CONTINUOUS EXECUTION GOAL — MTO (BÓC TÁCH KHỐI LƯỢNG)

Workspace này là nơi dsh chạy **MASTER GOAL** của dự án MTO. AGENTS.md này quy định GOAL
mà mọi session dsh (web, CLI, Telegram) phải tuân theo khi làm việc trong workspace này.

## MASTER GOAL (nguồn sự thật — đọc đầu mỗi phiên)

- **Master Goal:** xây bộ công cụ AutoCAD chuyên nghiệp **ưu tiên AutoLISP** phục vụ bóc
  tách khối lượng 3 hệ: **Điện · Nước · Điện nhẹ/ELV**. Kiến trúc: **LISP-first → LISP +
  AutoCAD Table → .NET wrapper/UI khi cần.** Không chuyển logic nhận dạng/đếm sang .NET chỉ
  vì UI thuận tiện.
- File quyết định **làm gì**:
  - `MTOPlugin/docs/agent-progress/MASTER_STATUS.md` — **nguồn sự thật trạng thái hiện tại**
    (Phase · Task · Trạng thái · số test PASS · NHẬT KÝ CHECKPOINT). Cập nhật SAU MỖI task.
  - `MTOPlugin/docs/agent-progress/TASK_INDEX.md` + `TASK-*.md` — nhật ký từng task
    (mỗi task 1 file; đọc file TASK của mục ĐANG LÀM trước khi thực thi).
  - `MTOPlugin/SPEC.md` · `MTOPlugin/README.md` · `MTOPlugin/QUICKSTART.md` ·
    `MTOPlugin/docs/ARCHITECTURE.md` · `MTOPlugin/docs/CHECKLIST.md` — đặc tả và hướng dẫn.
  - Audit cuối: `MTOPlugin/docs/agent-progress/FINAL_AUDIT.md` (đối chiếu 19 mục MASTER GOAL).
- Nguyên tắc: **MASTER GOAL quyết định PHẢI LÀM GÌ; GOAL (file này) quyết định PHẢI LÀM
  NHƯ THẾ NÀO.**

## Bắt đầu mỗi phiên (bắt buộc)

0. Đọc lần lượt để tái lập bối cảnh:
   1. File này (GOAL).
   2. `MTOPlugin/docs/agent-progress/MASTER_STATUS.md` (§1 MASTER GOAL · §4 TIẾN ĐỘ TỔNG ·
      §5 KNOWN ISSUES/BLOCKERS · §6 NHẬT KÝ CHECKPOINT).
   3. File `TASK_INDEX.md` + file TASK của mục ĐANG LÀM (nếu có).
1. Xác định **task kế tiếp** trong lộ trình (theo §4 TIẾN ĐỘ TỔNG; task chưa phải DONE,
   ưu tiên không vướng BLOCKER §5). Tiếp tục đúng task đó, tuyệt đối không tự nhảy task
   khác.
2. Tạo danh sách TODOs bằng `todo_write` (xem mục "To-dos") rồi mới thực thi.

## Cách làm việc (quy tắc chung)

- Chạy **liên tục từng task của master goal** như công nhân: chọn task → lập TODO →
  thực hiện → **test trên AutoCAD thật (accoreconsole headless)** → cập nhật MASTER_STATUS
  (§4 + §6) → báo cáo tiến độ → chuyển task kế tiếp.
- **Cổng chất lượng bắt buộc trước mọi test run** (theo §4): ① LINT cú pháp
  (`check-lisp-syntax.ps1`) ② LOAD-CHECK (`mto-qload`) ③ TEST headless (so khớp PASS/FAIL).
  Không báo "xong" nếu chưa qua đủ 3 cổng.
- Test phải chạy thật trên `accoreconsole.exe` (AutoCAD 2023, ACADVER 24.2) — **không giả
  mạo PASS**; console xuất UTF-16LE → LISP ghi kết quả ra file, PowerShell đọc file.
- Mọi thay đổi phải tuân theo quyết định kiến trúc ở `MASTER_STATUS.md §3` (vị trí LISP,
  prefix `MTO*`, data model phẳng, lưu trữ `*MTO-DATA*` + file EDN-like, ngôn ngữ tài liệu
  tiếng Việt **không dấu** trong code/comment). Không xóa/rewrite nhánh .NET hiện có.
- Nếu có lỗi hoặc đổi kế hoạch, cập nhật lại TODO và MASTER_STATUS để phản ánh trạng thái thật.

## To-dos (bắt buộc — luôn hiển thị trên màn hình)

- Mỗi khi bắt đầu turn / task / nhiệm vụ dài, **phải gọi `todo_write`** để tạo hoặc cập
  nhật danh sách TODOs:
  - Trước khi thực thi: gửi toàn bộ danh sách bước với `status: "pending"`.
  - Khi bắt đầu làm một bước: đánh dấu `"in_progress"` (gửi lại toàn bộ danh sách —
    whole-list replacement).
  - Khi xong một bước: `"completed"` và tiếp tục bước kế.
  - Cập nhật lại TODO ngay khi có lỗi hoặc đổi kế hoạch.
- Không có vai trò nào được phép bỏ qua `todo_write`.

## Báo cáo tiến độ qua Telegram (bắt buộc — mỗi task 2 lần)

Gọi tool **`notify`** của dsh-notifier để gửi báo cáo qua Telegram cho user. Báo cáo bằng
tiếng Việt, ngắn gọn, súc tích. **Mỗi task trong master goal = đúng 2 bản tin**: 1 khi
bắt đầu, 1 khi hoàn thành. Không báo cáo spam ngoài 2 mốc này (trừ khi user hỏi hoặc có
chặn/đổi kế hoạch đáng kể).

### 1. Khi BẮT ĐẦU một task (trước khi thực thi)

Gửi 1 bản tin dạng:

```
🛠 Bắt đầu task <TÊN/TASK-ID>
Đang làm: <việc cụ thể sắp làm>
Thuộc: <PHASE + task> trong master goal
```

### 2. Khi HOÀN THÀNH một task (sau khi test xong / đóng)

Gửi 1 bản tin dạng:

```
✅ Vừa hoàn thành <TÊN/TASK-ID>: <việc đã xong gọn 1 dòng>
Tiến độ task: <done/total task> (task trong đợt/phạm vi đang làm)
Tiến độ master goal: <x/y mục> — lấy số mới nhất từ MASTER_STATUS §4 sau khi cập nhật
```

- **`done`/`total` task**: đếm task đã hoàn thành trong **đợt/phạm vi đang triển khai**
  (ví dụ: PHASE 1 có N task, xong đến đâu thì `x/N`).
- **`x/y mục`**: đọc thẳng số liệu trong `MTOPlugin/docs/agent-progress/MASTER_STATUS.md`
  §4 **sau khi đã cập nhật** trạng thái task vừa xong (kèm số test PASS nếu có), không báo
  cáo số cũ.
- Nếu task để lại chặn/việc kế tiếp cần user biết, có thể thêm 1 dòng cuối ngắn gọn.

## Khi goal bị disarmed / vòng lặp dừng

- Nếu vòng lặp tự động dừng vì goal `activation: "disarmed"`: **không** sửa plugin
  `.dsh-agent-teams` để lách. Chờ user gửi một lượt trực tiếp, rồi dùng `update_goal` với
  `action="resume"` (đúng goal_id + revision) để khôi phục.
- Giảm thiệt hại khi vòng lặp đứt: luôn backup state + checkpoint cuối mỗi lượt (mọi
  file LISP/test chạy xong đều lưu kết quả), chia lệnh nhỏ, ghi log rõ ràng.

## Tiêu chí hoàn thành một phiên

- Task đã lên todo hoàn tất và được xác minh (LINT + LOAD-CHECK + test headless thật, số
  PASS/FAIL ghi rõ).
- MASTER_STATUS (§4 + §6) / TASK-*.md cập nhật đúng trạng thái task.
- Báo cáo Telegram cho user về tiến độ.