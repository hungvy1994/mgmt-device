# CLAUDE.md — mgmt-device (Atlas Ops)

Context cho AI agent làm việc trong project này. Đọc trước khi sửa bất kỳ file nào.

## Project

Quản lý tài sản hạ tầng Mắt Bão. Team `sa`, owner `vydh`. Phase 1–2 (Discovery → iMVP).
Chi tiết: `docs/PRD.md`, `docs/ARCH.md`, `docs/PLAN.md`.

## Stack

**Hiện tại:** HTML/CSS/JS thuần trong một file `index.html` (không framework, không CDN,
không build step) + hai script Python (`openpyxl` + stdlib) để bóc dữ liệu.

**Đích (chuẩn AI Factory):** Next.js + FastAPI + Postgres + Docker Compose, deploy Coolify.
Version linh hoạt nhưng phải scan CVE (`npm audit` / `pip-audit`). Lệch khỏi bộ công nghệ này
→ phải xin duyệt qua MCP `request_tech_exception`, không tự quyết.

## File nào là generated — đừng sửa tay

| File | Sinh bởi |
|---|---|
| `asset_import.csv` | `scripts/clean_asset_workbook.py` |
| `asset_history_import.csv` | `scripts/clean_asset_workbook.py` |
| `data/atlas-data.js` | `scripts/build_data.py` |

Sửa logic ở script rồi chạy lại. `BAO CAO THEO DOI SERVER (HR+SA).xlsx` là nguồn gốc, không sửa.

## Quy tắc dữ liệu — quan trọng nhất

Dữ liệu nguồn là sổ Excel chép tay, nhiều chỗ thiếu. Nguyên tắc xuyên suốt: **hiện ra chỗ thiếu,
không lấp bằng giá trị đoán.**

- Trường không có dữ liệu hiển thị là `Null` (mờ, chữ monospace nghiêng) — không thay bằng câu chữ
  kiểu "Chưa ghi nhận" và tuyệt đối không điền giá trị suy đoán. Hồ sơ chi tiết hiện đủ mọi trường,
  trường trống vẫn có mặt với giá trị `Null` thay vì bị ẩn.
- `review_flags` (404 tài sản, 175 sự kiện) phải hiển thị, không được lọc bỏ cho "sạch giao diện".
- `parent_asset_id` (khớp mã) và `attachment_target_label` / `parentLabel` (nhãn cụm) là hai thứ
  khác nhau — 388/394 giá trị chưa khớp mã. Không ép thành quan hệ cha-con.
- Giữ đủ 8 trạng thái: `in_use`, `in_use_needs_replacement`, `in_stock`, `not_in_use`,
  `degraded`, `broken`, `pending_disposal`, `retired`.
- `source_row` / `source_column` phải đi theo mọi bản ghi để truy về dòng Excel gốc.
- Số liệu hiển thị luôn tính từ dữ liệu đang nạp, **không hardcode** (bản mockup đầu tiên từng
  hiển thị 1.284 tài sản trong khi thật chỉ có 847 — không lặp lại).

## Convention code

- `index.html`: CSS trong `<style>` đầu file, JS trong một IIFE cuối file. Giữ nguyên cấu trúc này
  đến khi tách sang Next.js — đừng thêm framework/CDN vào bản tĩnh.
- Map CSV → record chỉ ở `mapAssetRow` / `mapHistoryRow`. Dùng chung cho data đóng gói và file
  user import; sửa một chỗ, đừng viết mapper thứ hai.
- Escape mọi giá trị đưa vào `innerHTML` bằng `escapeHtml` (dữ liệu có tiếng Việt và ký tự lạ).
- Python: type hints, `pathlib`, chỉ stdlib + `openpyxl`.
- Chuỗi UI tiếng Việt. Wording thuộc quyền BA — DEV không tự chế câu từ, đặt biến i18n và áp đề xuất của BA.

## Identity — không hardcode

Email/tên/owner luôn đọc từ môi trường, không lấy từ context hay memory của agent:

```bash
OWNER_EMAIL="${CODER_USER_EMAIL:-$(git config user.email)}"
OWNER_EMAIL="${OWNER_EMAIL:-${CODER_USER}@matbao.com}"
```

## Lệnh hay dùng

```bash
docker compose up -d --build              # db + api + web  → http://localhost:8080
docker compose run --rm seed              # nạp CSV vào Postgres (SEED_FORCE=1 để nạp đè)
python3 scripts/clean_asset_workbook.py   # XLSX → CSV   (pip install -r requirements.txt)
python3 scripts/build_data.py             # CSV  → data/atlas-data.js (bản chạy không cần database)
python3 -m http.server 8080               # xem trang tĩnh, không cần database
```

## Hai chế độ chạy

Trang dò `/api/data` khi khởi động. Có API → đọc/ghi Postgres, nhập-xuất CSV đi thẳng vào
database. Không có API → rơi về `data/atlas-data.js`, mọi thay đổi chỉ nằm trong bộ nhớ trình
duyệt. Giữ nguyên cả hai đường: `mapAssetRow` / `mapHistoryRow` nhận đúng bộ cột CSV nên API
và file tĩnh dùng chung một mapper — đừng viết mapper thứ hai cho API.

## Tài khoản & bí mật

Tài khoản đăng nhập nằm trong bảng `app_user` của Postgres, mật khẩu băm bằng scrypt.
**Không bao giờ** đặt tài khoản/mật khẩu vào `index.html`, tài liệu hay `docker-compose.yml`.
Tài khoản quản trị đầu tiên do `docker compose run --rm seed` tạo từ `ADMIN_USERNAME` /
`ADMIN_PASSWORD` trong `.env` (đã gitignore); bỏ trống `ADMIN_PASSWORD` thì hệ thống sinh
ngẫu nhiên và in ra đúng một lần.

## Đang thiếu

Chưa có git repo, test, CI, auth cho API. Xem `docs/PLAN.md`.
