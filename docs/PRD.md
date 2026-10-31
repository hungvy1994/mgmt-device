# PRD — mgmt-device (Device Management)

| | |
|---|---|
| **Status** | Approved (scope) — 2026-09-09 |
| **Owner** | vydh · Đặng Hùng Vỹ · `vydh@matbao.com` |
| **Team** | `sa` — System Administrator |
| **Phase** | 1–2 · Discovery → iMVP |
| **Nguồn dữ liệu** | `BAO CAO THEO DOI SERVER (HR+SA).xlsx`, sheet `TỔNG HỢP` |

## 1. Tổng quan

Device Management là hệ thống quản lý tài sản hạ tầng của Mắt Bão: biết mỗi thiết bị đang ở đâu,
thuộc cụm nào, tình trạng ra sao và đã đi qua những vị trí nào. Bản đầu tiên tập trung
dựng **mô hình vị trí Site → Phòng máy → Rack → Thiết bị** — phần mà sổ Excel hiện tại
hoàn toàn chưa có.

## 2. Bối cảnh & vấn đề

Toàn bộ 847 tài sản hiện được theo dõi trong một file Excel dùng chung giữa HR và SA.
Bóc tách file này ra cho thấy các vấn đề không thể sửa bằng cách sửa Excel:

| Vấn đề | Số liệu |
|---|---|
| Vị trí chỉ ghi tới mức site, không có phòng máy / rack / vị trí U | 5 site, 0 rack |
| Lịch sử vòng đời nhét nhiều dòng trong một ô, thiếu dòng tương ứng | 104 dòng lệch, 175/729 sự kiện có cờ |
| "Thiết bị cha" ghi bằng nhãn cụm, không phải mã tài sản | 388/394 chưa khớp |
| Thiếu ngày bắt đầu sử dụng | 531/847 |
| Trạng thái viết tự do, 14 cách viết cho 8 trạng thái thật | `Đang sử dụng` / `đang sử dụng` / `đã hanh lý`… |

Hệ quả: không trả lời được nhanh "thiết bị X đang nằm rack nào", không biết rack còn trống
bao nhiêu U, không đối soát được khi kiểm kê.

## 3. Mục tiêu & phi mục tiêu

**Mục tiêu (iMVP)**
- G1 — Khai báo được cấu trúc vị trí Site → Phòng máy → Rack, kèm số U của rack.
- G2 — Gán thiết bị vào rack và vị trí U; nhìn được rack còn trống bao nhiêu.
- G3 — Mỗi lần đổi vị trí sinh một sự kiện có thời điểm và người thực hiện, truy vết được.
- G4 — Dữ liệu 847 tài sản hiện có nạp được vào mô hình mới mà không mất cờ review.

**Phi mục tiêu (iMVP)**
- Không làm module kiểm kê / khấu hao tài sản (thuộc kế toán).
- Không tích hợp monitoring hay CMDB tự động phát hiện thiết bị.
- Không làm hàng đợi review dữ liệu và không mở rộng nhập liệu ngoài phạm vi vị trí — đưa vào backlog.

## 4. Người dùng

| Persona | Ai | Cần gì |
|---|---|---|
| **SA / vận hành hạ tầng** (chính) | Team `sa` | Biết thiết bị nằm rack nào, còn chỗ trống ở đâu, thiết bị nào sắp phải thay |
| HR / hành chính (phụ, chỉ đọc) | Team `hr` | Hóa đơn, giá mua, nhà cung cấp, hạn bảo hành |
| Manager (phụ, chỉ đọc) | `manager` | Tổng quan theo site, tỉ lệ vận hành, số tài sản cần xử lý |

Bản iMVP chỉ phục vụ persona chính; hai persona phụ chỉ được tính đến ở mức không chặn đường (RBAC đọc).

## 5. User journeys

**J1 — Khai báo rack mới**
SA mở *Vị trí & Rack* → chọn site `ODS` → thêm phòng máy `Server room A` → thêm rack `R-07`, 42U → rack hiện trong danh sách với 42U trống.

**J2 — Gán thiết bị vào rack**
SA mở hồ sơ `SVR-KHO-030` → *Đổi vị trí* → chọn site/phòng/rack + vị trí U → hệ thống chặn nếu khoảng U đã có thiết bị khác → lưu, sinh sự kiện `Chuyển vị trí`.

**J3 — Xem sơ đồ rack**
SA mở rack `R-07` → thấy sơ đồ 42U, thiết bị nào chiếm U nào, khoảng trống liên tục còn lại → quyết định lắp máy mới vào đâu.

**J4 — Truy vết**
SA mở hồ sơ thiết bị → timeline đầy đủ: nhận về → giai đoạn 1..5 → vị trí hiện tại, kèm cờ review với sự kiện thiếu dữ liệu.

## 6. Yêu cầu chức năng

| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| F1 | CRUD Site (5 site hiện có: ODS, Kho, VNPT Tân Thuận, CMC Tân Thuận, CMC Quận 9) | Must |
| F2 | CRUD Phòng máy thuộc site | Must |
| F3 | CRUD Rack thuộc phòng máy, khai báo chiều cao U | Must |
| F4 | Gán / gỡ thiết bị vào rack tại vị trí U, chặn chồng lấn U | Must |
| F5 | Sơ đồ rack trực quan: U đã dùng / trống, click mở hồ sơ thiết bị | Must |
| F6 | Mỗi thay đổi vị trí sinh `asset_event` kèm thời điểm + người thực hiện | Must |
| F7 | Linh kiện gắn vào thiết bị chính kế thừa vị trí khi thiết bị chính di chuyển | Should |
| F8 | Nạp 847 tài sản + 729 sự kiện hiện có, ánh xạ `datacenter` → `site` | Must |
| F9 | Thiết bị chưa gán rack vẫn hiển thị, ở trạng thái "chỉ biết đến mức site" | Must |
| F10 | Xuất CSV danh sách tài sản kèm vị trí đầy đủ | Should |

**Business rules**
- BR1 — Một vị trí U trong một rack chỉ chứa một thiết bị tại một thời điểm.
- BR2 — Xóa rack còn thiết bị → chặn, yêu cầu chuyển thiết bị đi trước.
- BR3 — Không suy đoán dữ liệu thiếu: mọi trường trống hiển thị là `Null` mờ, không thay bằng câu chữ giả.
- BR4 — `parent_asset_id` (đã khớp mã) và `attachment_target_label` (nhãn cụm) không được trộn.
- BR5 — Giữ nguyên 8 trạng thái nghiệp vụ, không gộp về active/inactive.

## 7. Yêu cầu phi chức năng

| Hạng mục | Ngưỡng |
|---|---|
| Hiệu năng | p95 < 500ms với 847 tài sản; danh mục phân trang server-side khi > 5.000 bản ghi |
| Bảo mật | SSO nội bộ, session 8h, RBAC theo team, audit log mọi thay đổi vị trí |
| Dữ liệu | Không mất `review_flags`, `source_row`, `source_column` khi import — phải truy được về dòng Excel gốc |
| Rollback | < 1 phút (Coolify rollback + migration reversible) |
| i18n | Chuỗi UI đặt biến i18n tiếng Việt; wording do BA duyệt, DEV không tự chế |
| Tài liệu | ARCH / PRD / README / CLAUDE + API.md trước Gate 2 |

## 8. Data model & nguồn dữ liệu

Xem chi tiết trong [ARCH.md](./ARCH.md) mục 3. Tóm tắt:

- Bảng **mới**: `site`, `room`, `rack`, `placement`.
- Bảng **kế thừa từ CSV**: `asset` (26 cột), `asset_event` (10 cột), `supplier`.
- Ánh xạ nạp lần đầu: `datacenter` → `site`; `room`/`rack` để trống, do SA khai báo bổ sung.
- Nguồn gốc và các quyết định làm sạch: [DATA_CLEANING_NOTES.md](../DATA_CLEANING_NOTES.md).

## 9. Rủi ro & giả định

| # | Rủi ro / giả định | Xử lý |
|---|---|---|
| R1 | Vị trí rack thật hiện chỉ nằm trong đầu người vận hành, không có tài liệu | Phải có đợt khảo sát và nhập tay; iMVP cần màn nhập nhanh |
| R2 | Quản lý rack bắt buộc phải **ghi** dữ liệu, nên không thể dừng ở trang tĩnh | Bản đích cần Postgres + API ngay từ iMVP — đây là hệ quả kỹ thuật của phạm vi đã chọn |
| R3 | 388 nhãn cụm chưa khớp mã thiết bị cha | Không chặn iMVP; giữ hai cột tách bạch, xử lý ở backlog |
| R4 | File Excel vẫn được cập nhật song song trong lúc chuyển đổi | Chốt ngày đóng băng file, sau đó hệ thống là nguồn sự thật duy nhất |
| R5 | Chưa xác nhận ai được sửa dữ liệu ngoài team SA | Mặc định iMVP: chỉ `sa` được ghi, các team khác đọc |

**Giả định cần xác nhận:** R2 và R5 do tôi suy ra từ phạm vi đã chọn, chưa được duyệt riêng.

## 10. Tiêu chí nghiệm thu (iMVP)

- [ ] Khai báo được đủ 5 site, ít nhất 1 phòng máy và 1 rack có sơ đồ U hoạt động.
- [ ] Gán được thiết bị vào U, chặn chồng lấn (BR1), chặn xóa rack còn thiết bị (BR2).
- [ ] Nạp đủ 847 tài sản + 729 sự kiện, đối chiếu số liệu khớp với CSV: 605 `in_use`, 165 `in_stock`, 404 bản ghi có cờ review.
- [ ] Tài sản thiếu ngày hiển thị `Null`, không có ngày bịa.
- [ ] Mỗi lần đổi vị trí sinh sự kiện truy vết được người + thời điểm.
- [ ] Xuất CSV mở lại được bằng Excel (UTF-8 BOM) và khớp với dữ liệu trên màn hình.

## Roadmap

| Phase | Nội dung | Trạng thái |
|---|---|---|
| 1 · Discovery | Bóc dữ liệu Excel → CSV, mockup, PRD/ARCH | ✅ xong 2026-09-09 |
| 2 · iMVP | Mô hình vị trí Site→Phòng→Rack + gán thiết bị + persistence | ⏳ tiếp theo |
| Gate 1 | Manager duyệt giá trị nghiệp vụ + tính khả thi | ⏸️ |
| 3 · Productize | Next.js + FastAPI + Postgres, CI, test, security | ⏸️ |
| Gate 2 | Duyệt xuất xưởng | ⏸️ |
| 4 · Production | Deploy Coolify `mgmt-device.sa.dev.matbao.ai` | ⏸️ |

**Backlog (ngoài iMVP):** hàng đợi review 404 bản ghi + 175 sự kiện · gán mã thiết bị cha cho
388 nhãn cụm · quyền đọc cho HR/kế toán · cảnh báo hết bảo hành (64/76 thiết bị đã quá hạn).
