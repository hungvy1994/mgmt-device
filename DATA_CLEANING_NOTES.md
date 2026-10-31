# Asset import review

Generated from `BAO CAO THEO DOI SERVER (HR+SA).xlsx`, sheet `TỔNG HỢP `.

## Output files

- `asset_import.csv`: 847 unique assets. UTF-8 with BOM for Excel compatibility.
- `asset_history_import.csv`: 729 lifecycle events. One row per event, not one row per multiline Excel cell.
- `scripts/clean_asset_workbook.py`: reproducible transformation script.

## Cleaning decisions

- The source has 848 rows and 847 unique asset IDs. `FW-BD51-10` is an exact duplicate at source rows 166 and 167; one row is retained and marked in `review_flags`.
- `Datacenter` is retained as both `datacenter` and `current_location`. The five observed values are `ODS`, `VNPT Tân Thuận`, `CMC Tân Thuận`, `CMC Quận 9`, and `Kho`.
- `IP` is split into `ip_address` when it is an IPv4 address and `ip_or_type_raw` for the original overloaded value. `asset_type` is normalized from values such as `disk`, `server`, `switch`, `cáp`, `card mạng`, and `fỉewall`.
- `Tình trạng sử dụng` is mapped to `usage_status` codes while the original cleaned wording remains in `usage_status_label`.
- `V/W/X/Y` is expanded into `usage_stage_2`, `usage_stage_3`, and later events. The source row and source columns remain on every event for auditability.
- No missing parent device, location, usage object, or date was guessed. These rows carry review flags, including unknown handover locations.

## Fields currently available to import

The asset file includes the asset ID, name, type, category, IP, cluster, datacenter, current location, parent reference, capacity, replacement target, status, usage start, handover date, invoice, purchase price, supplier, warranty, description, source row, and review flags.

The history file includes asset ID, event sequence, event type, event date, location, usage object, declared transition count, source columns, source row, and review flags.

## Items needing approval before production import

1. **Parent relationship:** 388 `parent_reference` values are labels such as `VNPT1`, `ClusterX1`, `SW storage J6 -> J3`, or `Node 103.15.49.144`, not an asset ID. The page should support both `parent_asset_id` and `attachment_target_label`, then allow an operator to resolve labels to real devices.
2. **History completeness:** 104 source rows do not have equal numbers of date/location/object lines. There are 38 events without a location and 59 without a usage object. The history screen should show incomplete events and require review rather than silently filling values.
3. **Usage start date:** 531 assets have no `Ngày bắt đầu sử dụng`. The detail page needs an explicit `unknown/not recorded` state instead of displaying a fake date.
4. **Import flow:** The current page concept only imports a single asset CSV. It should offer separate `Assets` and `Lifecycle events` imports, with a preview, row-level validation, duplicate handling, and a downloadable error CSV.
5. **Location model:** `Datacenter` is a site-level value, while historical `Nơi đặt Server` may contain a sequence such as `ODS -> Kho -> CMC`. Add structured `site_id`, `room_id`, `rack_id`, and `position` fields for future movements; keep the source text as `location_label`.
6. **Business status:** Keep separate states for `in_use`, `in_use_needs_replacement`, `in_stock`, `broken`, `degraded`, `pending_disposal`, and `retired`. This is more faithful than a single active/inactive flag.
7. **Date policy:** Dates with both day and month at most 12 were interpreted as Vietnamese `dd/mm/yyyy`; values that cannot be interpreted that way, such as `10/28/2024`, were interpreted as `mm/dd/yyyy`. The import preview should display these dates before confirmation.

## Recommended import order

1. Import `asset_import.csv` and resolve duplicate or flagged master records.
2. Resolve `parent_reference` values to `parent_asset_id` where possible.
3. Import `asset_history_import.csv` with incomplete events visible in a review queue.
4. Recalculate current location from the latest approved event for assets whose source history is complete.
## How `index.html` consumes this data

- `scripts/build_data.py` packs both CSV files into `data/mgmt-device-data.js` as
  `window.MGMT_DEVICE_DATA = { meta, assetRows, historyRows }`. The rows keep the exact
  CSV column names; empty cells are dropped. Re-run it after regenerating the CSVs:
  `python3 scripts/build_data.py`.
- The page maps CSV columns to screen records in JavaScript (`mapAssetRow` /
  `mapHistoryRow`). The same two functions handle the bundled dataset and any file
  a user imports on the `Nhập / Xuất` screen, so an import of `asset_import.csv`
  reproduces the bundled state exactly.
- Nothing on screen is hard-coded any more: metrics, status distribution, recent
  events, filters, site list and cluster list are all computed from the loaded rows.
- Unresolved items from the list above stay visible instead of being hidden:
  missing `usage_start_date` renders as `Chưa ghi nhận`, `review_flags` render as
  chips on the row and in the detail drawer, and an unresolved `parent_reference`
  is shown as a label with a note that it does not match an asset ID.
- Rack and room are not in the source data. The `Vị trí & Cụm` screen therefore
  aggregates by site only; racks created by hand are listed but carry no asset count.

## Audit 2026-09-09 — đối chiếu lại XLSX ↔ CSV

Rà soát toàn bộ 848 dòng nguồn × 25 cột với hai file CSV. Kết quả: **4 lỗi thật đã sửa**
trong `scripts/clean_asset_workbook.py`, hai file CSV và `data/mgmt-device-data.js` đã sinh lại.

| # | Lỗi | Ảnh hưởng | Cách sửa |
|---|---|---|---|
| 1 | Cột **T** (`Đối tượng sử dụng`, giai đoạn đầu) bị mất hoàn toàn. Header của T và X giống hệt nhau nên `{header: index}` chỉ giữ cột X → mọi event `usage_stage_1` lấy nhầm nội dung cột X. | 315/315 event giai đoạn 1 sai đối tượng sử dụng; 12/15 giá trị của T (`MBO`, `Hosting`, `CloudServer`, `Email`, `Backup 1`, `MBIN & MBCA`…) không xuất hiện ở bất kỳ đâu trong output | Header trùng giữ lần xuất hiện đầu; các cột giai đoạn chuyển đổi truy cập bằng chữ cái cột (`by_letter`) |
| 2 | Cột **I** (`Ngày hết bảo hành`) lưu dạng số serial Excel ở 11 dòng → `parse_date` trả rỗng | mất 11 ngày hết bảo hành (`46602` = 2027-08-03, `47333` = 2029-08-03) | `parse_date` hiểu serial Excel (epoch 1899-12-30), giới hạn 1954–2064 |
| 3 | `description` luôn nối `"Cụm: "` kể cả khi cột Cụm rỗng | 316 mô tả có đuôi `\| Cụm: ` thừa | chỉ nối khi có cụm |
| 4 | Cột **J** (`Tình trạng bàn giao`) bị bỏ hẳn khỏi output | mất 87 giá trị; che mất 11 dòng ghi "Đã bàn giao" nhưng không có ngày bàn giao | thêm cột `handover_status` + cờ `handover_date_missing` |

Đồng thời gộp từ vựng `asset_category` về `component` / `server` (trước đó lẫn lộn
`component` / `linh kiện` / `server` cho cùng hai khái niệm).

### Đã đối chiếu và ĐÚNG

- 848 dòng nguồn → 847 mã tài sản duy nhất, không thiếu/thừa mã nào; `FW-BD51-10` trùng ở dòng 166/167.
- 13 trường ánh xạ 1:1 (mã, tên, hóa đơn, giá, NCC, bảo hành, cụm, datacenter, nơi gắn, dung lượng, nơi thay thế, tình trạng bàn giao) khớp tuyệt đối sau khi sửa.
- `asset_name` = cột B, thiếu thì lấy cột M, thiếu nữa thì lấy mã — đúng ở cả 847 dòng.
- `ip_address` chỉ điền khi cột N là IPv4; giá trị gốc luôn giữ ở `ip_or_type_raw`.
- 98 ngày dạng chữ ở cột S parse đúng hết; không có ngày nào bị hiểu nhầm dd/mm ↔ mm/dd.
- 14 cách viết tình trạng sử dụng → 8 mã trạng thái, chữ nguyên văn giữ ở `usage_status_label`.
- Số event mỗi dòng = bàn giao (K) + giai đoạn đầu (S/T) + số dòng của V/W/X — khớp 729 event.

### Còn tồn tại (không phải lỗi pipeline)

- **6 dòng** khai `Số lần chuyển đổi` = 2 nhưng chỉ có 1 dòng chuyển đổi trong V/W/X. Cột Y có hai
  cách hiểu (có tính giai đoạn đầu hay không) nên giữ nguyên giá trị khai báo, không tự suy.
- Sau khi sửa vẫn còn thiếu tại nguồn: 531 tài sản không có ngày bắt đầu sử dụng, 760 không có
  ngày hết bảo hành, 136 event không có đối tượng sử dụng, 109 event không có vị trí.
  Những chỗ này hiển thị là `Null` mờ trên giao diện, không thay bằng câu chữ giả.

## Cập nhật 14/09/2026 — đưa về chuẩn dữ liệu hiện tại

`scripts/clean_asset_workbook.py` sinh lại hai file CSV cho khớp `ASSET_COLUMNS` /
`HISTORY_COLUMNS` của API:

- Thêm cột `rack`, `rack_unit` (tài sản) và `notes` (lịch sử). Thiếu cột nào thì nhập
  vào là mất cột đó, và bản xuất ra không còn round-trip được.
- **Suy vị trí rack từ mã tài sản.** Mã dạng `LOẠI-RACK-U` (`SW-AQ53-32` → rack AQ53 U32;
  `SVR-J3-4344` → rack J3, thiết bị 2U bắt đầu ở U43). Kiểm chứng trước khi nhận: 118/118
  trường hợp khớp rack đã khai có `Datacenter` trùng khớp site của rack, đuôi 2 số đều nằm
  trong chiều cao rack, đuôi 4 số đều là cặp U liền kề. Điều kiện nhận một token làm mã rack:
  token phải có chữ cái (loại `2TB`, `240`, `10`), mọi thiết bị mang token đó phải cùng một
  datacenter, và token không trùng tên site (`SVR-KHO-30` là thiết bị ở Kho, `KHO` không
  phải rack). Hai thiết bị rơi vào cùng một U thì bỏ cả hai.
  Kết quả: **126 tài sản** ở 9 rack (AQ53, AQ54, BD51, J3–J6, M08, P7).
  Mọi dòng suy được đều mang cờ `rack_from_asset_code` — đây là suy luận, không phải sổ ghi.
- **`description` bỏ phần đã có cột riêng.** Trước đây nhồi `asset_name | tên thứ hai |
  Cụm: X`, tức nhân bản hai cột đã tồn tại (531 dòng lặp cụm, 782 dòng lặp tên). Giờ chỉ giữ
  tên thứ hai khi nó khác `asset_name`; 635/847 dòng còn trống, đúng vì sổ không có gì thêm.

### Đã kiểm và loại bỏ

Sheet **ODS** (bảng HR theo dõi mua sắm, 456 dòng, 209 có mã tài sản) **không bù được ô nào**:
209/209 mã đã có đủ hoá đơn / giá / NCC / bảo hành ở sheet TỔNG HỢP. Khác biệt duy nhất là
`Ngày hết bảo hành` ghi dạng số serial Excel ở ODS — cùng giá trị, khác cách viết.
Hai sheet `Xử lý` và `Đổ dữ liệu` chỉ chứa chữ menu của add-in, không có dữ liệu.

### Chưa xử lý, cố ý

- `M08` (9 tài sản) và rack `M8` người dùng đã khai gần như chắc là một, nhưng sửa mã cho
  khớp là đoán chồng lên đoán — để nguyên theo đúng chữ trong mã, cờ đã nói rõ là suy ra.
- 109 sự kiện không có vị trí và 388 nhãn thiết bị cha chưa khớp mã: sổ gốc không có,
  không bịa ra.
