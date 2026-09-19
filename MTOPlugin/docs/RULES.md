# Bộ quy tắc bóc tách khối lượng (Rule Set)

Bộ quy tắc là dữ liệu nghiệp vụ do **Phòng Dự án** quản lý. IT chỉ cung cấp
công cụ nhập/lưu/kiểm tra/áp dụng. Plugin **không** tự đặt tên vật tư hay
suy diễn ý nghĩa M&E.

Trạng thái khuyến nghị: chạy QC thật chính thức thì **Active**; khi xây dựng
dùng **Draft** để không bị áp dụng nhầm.

## Vị trí file

- Mẫu: `config/rules.sample.json`
- Người dùng tự tạo bản cho dự án của mình (đặt cạnh file xuất hoặc lưu vào vị trí thoả thuận).

## Cấu trúc

```jsonc
{
  "name": "MTO Rules M&E",
  "version": " ",
  "description": "Mo ta",
  "rules": [ { ... } ]
}
```

### Trường của một quy tắc

| Trường | Bắt buộc | Mô tả |
|---|---|---|
| `code` | x | Mã quy tắc duy nhất và phiên bản để truy vết (VD `R-DIEN-001`). |
| `version` | x | Phiên bản quy tắc. |
| `systemCode` | x | Mã hệ M&E (HE-DIEN, HE-NUOC, HE-HVAC, HE-PCCC). |
| `materialCode` | x | Mã vật tư/công việc. |
| `materialName` | x | Tên vật tư/công việc. |
| `specification` |   | Quy cách (VD "PVC D20"). |
| `unit` | x | Đơn vị tính (cai, m, ...). |
| `calculation` | x | Cách tính: `Count`, `SumLength`, `SumLengthTimesFactor`, `SumLengthCeilingStep`, `SumAttributeValue`. |
| `factor` |   | Hệ số (khi dùng `SumLengthTimesFactor`). |
| `ceilingStep` |   | Bước làm tròn lên (khi dùng `SumLengthCeilingStep`). |
| `sumAttribute` |   | Tên attribute khi dùng `SumAttributeValue`. |
| `priority` |   | Ưu tiên: số lớn được ưu tiên khi vật tư trùng nhiều quy tắc. |
| `status` | x | `Active` / `Draft` / `Paused`. |
| `approvedBy` |   | Người xác nhận (Kỹ sư M&E). |
| `conditions` | x | Mảng điều kiện nhận dạng. |

### Ý nghĩa điều kiện (conditions)

Tất cả điều kiện trong một mục được **AND** với nhau. Hỗ trợ:

- `layers`: danh sách phân cách `;`, wildcard `*` `?`. VD `EL-CABLE;EL-*`
- `blockNames`: tên block (wildcard) `BANGDIEN_*;CBD*`
- `effectiveBlockNames`: tên block động (dynamic) đang hoạt động
- `entityKind`: `block` | `geometry`
- `geometryKinds`: `Line;Polyline;Polyline2D;Polyline3D;Arc;Circle`
- `attributes`: `KEY=VALUE;KEY2=VALUE2` (prefix `~` để phủ định: `~TYPE=GLOBE`)
- `colorIndexes`: `1;2;3`
- `linetypes`: tên kiểu đường
- `blockNameRegex`, `layerRegex`: biểu thức chính quy
- `requireDynamicBlock`: `true` để chỉ áp dụng dynamic block

Ví dụ quy tắc đếm van khóa DN25 có attribute:

```json
{
  "code": "R-NUOC-002",
  "systemCode": "HE-NUOC",
  "materialCode": "VL-NUOC-002",
  "materialName": "Van khoa",
  "specification": "DN25",
  "unit": "cai",
  "calculation": "Count",
  "status": "Active",
  "conditions": [
    {
      "entityKind": "block",
      "blockNames": "VAN*",
      "attributes": "SIZE=DN25;TYPE=GATE"
    }
  ]
}
```

## Nguyên tắc

- Một đối tượng khớp nhiều quy tắc => quy tắc có `priority` cao hơn thắng.
- Đối tượng không khớp => vào sheet `CHUA_PHAN_LOAI` (không tự gán).
- Lỗi trên 1 đối tượng không làm dừng toàn bộ lượt quét; được ghi `CANH_BAO_LOI`.