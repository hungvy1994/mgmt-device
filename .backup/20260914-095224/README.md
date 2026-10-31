# mgmt-device — Atlas Ops

Hệ thống quản lý tài sản hạ tầng Mắt Bão: thiết bị đang ở đâu, thuộc cụm nào, tình trạng ra sao
và đã đi qua những vị trí nào. Nguồn dữ liệu ban đầu là sổ theo dõi server dùng chung HR + SA.

| | |
|---|---|
| Team | `sa` — System Administrator |
| Owner | Đặng Hùng Vỹ (`vydh@matbao.com`) |
| Phase | 1–2 · Discovery → iMVP |
| Tài liệu | [docs/PRD.md](docs/PRD.md) · [docs/ARCH.md](docs/ARCH.md) · [docs/PLAN.md](docs/PLAN.md) · [docs/DEPLOY.md](docs/DEPLOY.md) · [DATA_CLEANING_NOTES.md](DATA_CLEANING_NOTES.md) |

## Hiện trạng

Bản đang có là **prototype tĩnh**: một file `index.html` chạy trên dữ liệu thật đã bóc từ Excel.
Chưa có backend, chưa có database, thao tác sửa/xóa chỉ nằm trong bộ nhớ trình duyệt.

Số liệu đang nạp: **847 tài sản** · **729 sự kiện vòng đời** · 5 site · 16 loại thiết bị ·
404 bản ghi và 175 sự kiện còn cờ cần review.

## Chạy

**Đầy đủ (page + database + API), khuyến nghị:**

```bash
cp .env.example .env             # đổi POSTGRES_PASSWORD trước khi chạy ngoài máy cá nhân
docker compose up -d --build     # db + api + web
docker compose run --rm seed     # nạp 2 file CSV vào Postgres, chạy lại được nhiều lần
# → http://localhost:8080        (API docs: http://localhost:8080/api/docs)
```

Nạp đè dữ liệu: `docker compose run --rm -e SEED_FORCE=1 seed`. Dừng: `docker compose down`
(thêm `-v` nếu muốn xóa luôn dữ liệu trong database). Chi tiết cấu hình, sao lưu, rollback và
xử lý sự cố: [docs/DEPLOY.md](docs/DEPLOY.md).

**Chỉ xem giao diện, không cần database:**

```bash
python3 -m http.server 8080      # hoặc mở thẳng index.html bằng trình duyệt
```

Trang tự dò `/api/data`: có database thì đọc từ Postgres, không có thì dùng `data/atlas-data.js`.
Tài khoản quản trị do `seed` tạo từ `.env` (`ADMIN_USERNAME`, `ADMIN_PASSWORD`). Bỏ trống
`ADMIN_PASSWORD` thì mật khẩu được sinh ngẫu nhiên và in ra một lần khi chạy `seed` — chép lại ngay.
Không có database thì trang chạy chế độ xem offline, nói rõ trên màn đăng nhập là không có xác thực.

## Cấu trúc thư mục

```
mgmt-device/
├── index.html                              # SPA tĩnh: Tổng quan / Tài sản / Vị trí & Cụm / Nhập-Xuất
├── data/atlas-data.js                      # dữ liệu đóng gói (window.ATLAS_DATA) — generated
├── asset_import.csv                        # 847 tài sản      — generated
├── asset_history_import.csv                # 729 sự kiện      — generated
├── BAO CAO THEO DOI SERVER (HR+SA).xlsx    # nguồn gốc, không sửa tay
├── scripts/
│   ├── clean_asset_workbook.py             # XLSX → 2 file CSV
│   └── build_data.py                       # 2 file CSV → data/atlas-data.js
├── docker-compose.yml                      # db + api + web + seed
├── db/schema.sql                           # schema Postgres, tự chạy khi tạo database
├── api/                                    # FastAPI: /api/data, import & export CSV
├── web/nginx.conf                          # phục vụ trang tĩnh + proxy /api/
├── docs/                                   # PRD · ARCH · PLAN
└── DATA_CLEANING_NOTES.md                  # quyết định làm sạch + điểm cần duyệt
```

## Sinh lại dữ liệu

Ba file `asset_import.csv`, `asset_history_import.csv`, `data/atlas-data.js` đều là output —
đừng sửa tay, sửa ở script rồi chạy lại:

```bash
pip install openpyxl                        # dependency duy nhất của bước 1
python3 scripts/clean_asset_workbook.py     # XLSX → CSV
python3 scripts/build_data.py               # CSV  → data/atlas-data.js
```

Trang cũng import CSV được lúc chạy (màn **Nhập / Xuất**) bằng đúng hàm map với data đóng gói,
nên nạp lại `asset_import.csv` sẽ tái tạo chính xác state ban đầu.

## Quy ước dữ liệu (bắt buộc giữ)

- **Không bịa dữ liệu thiếu.** Trường trống hiển thị là `Null` mờ, không thay bằng câu chữ giả.
- **Không nuốt cờ review.** `review_flags` hiện thành chip trên dòng và trong hồ sơ chi tiết.
- **Không trộn cha-con giả.** 388 `parent_reference` là nhãn cụm, giữ riêng khỏi `parent_asset_id`.
- **Giữ đủ 8 trạng thái nghiệp vụ**, không gộp về active/inactive.
- **Truy được về dòng Excel gốc** qua `source_row` / `source_column`.

## Chọn và sửa nhiều tài sản

Bảng danh mục có cột chọn: tick từng dòng, tick ô đầu bảng để chọn cả trang, hoặc bấm
**"Chọn tất cả N kết quả đang lọc"** để chọn toàn bộ tài sản khớp bộ lọc hiện tại.

Thanh thao tác hiện ra cho phép **sửa 16 trường** hoặc **xóa** hàng loạt. Trường nào để
"Giữ nguyên" (hoặc bỏ trống) thì không đụng tới:

| Nhóm | Trường |
|---|---|
| Phân loại | Trạng thái · Loại thiết bị |
| Vị trí & quan hệ | Site/Datacenter · Cụm · Thiết bị cha (mã) hoặc nhãn cụm |
| Kỹ thuật | Dung lượng / cấu hình · Nơi thay thế |
| Vòng đời | Ngày bắt đầu sử dụng · Ngày bàn giao · Tình trạng bàn giao |
| Mua sắm | Số hóa đơn · Giá mua · Mã NCC · Tên NCC · Bảo hành (tháng) · Ngày hết bảo hành |

Ô "Thiết bị cha" khớp mã tài sản thì ghi vào `parent_asset_id`; không khớp thì ghi vào
`attachment_label` như nhãn cụm — không ép thành quan hệ cha-con giả. Thiết bị không tự làm cha
của chính nó. Có database thì ghi thẳng vào Postgres
qua `/api/assets/bulk-update` và `/api/assets/bulk-delete`; không có thì chỉ đổi trong trình duyệt.

Đổi trạng thái bằng tay sẽ **xóa** `usage_status_label` (chữ nguyên văn trong sổ Excel) về trống,
vì sổ không còn nói gì về giá trị mới — giao diện hiển thị `Null` thay vì gán nhãn danh mục vào đó.

## Nhập / xuất CSV

| | Có database | Không có database |
|---|---|---|
| Nhập | Màn **Nhập / Xuất** đẩy file lên `/api/import/assets` hoặc `/api/import/history`, upsert vào Postgres | chỉ đổi trong bộ nhớ trình duyệt, tải lại trang là mất |
| Xuất | `/api/export/assets.csv`, `/api/export/history.csv` — toàn bộ dữ liệu trong database | xuất từ dữ liệu đang nạp trên trình duyệt |

Khóa: `asset_id` (tài sản), `asset_id + event_sequence` (lịch sử). File xuất có UTF-8 BOM,
mở thẳng bằng Excel, và trùng khít với `asset_import.csv` khi chưa sửa gì.

## Bước tiếp theo

iMVP là mô hình vị trí Site → Phòng máy → Rack (xem `docs/PLAN.md`). Việc này cần lưu trữ thật,
nên sẽ chuyển sang stack chuẩn AI Factory: Next.js + FastAPI + Postgres + Docker Compose,
deploy qua Coolify tại `mgmt-device.sa.dev.matbao.ai`.
