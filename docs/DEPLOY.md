# DEPLOY — mgmt-device (Device Management)

Hướng dẫn triển khai bằng Docker Compose. Cập nhật 2026-09-10 · team `sa`.

Mọi lệnh chạy tại thư mục gốc của project (nơi có `docker-compose.yml`).

## 1. Yêu cầu

| | |
|---|---|
| Docker Engine | 24+ (đã kiểm trên 29.1.3) |
| Docker Compose | v2 (`docker compose`, đã kiểm trên 2.40.3) — khuyến nghị. Vẫn chạy được với `docker-compose` v1 từ 1.27 trở lên |
| Cổng trống | 1 cổng cho web, mặc định `8080` |
| Dung lượng | ~600MB image + ~50MB dữ liệu |

Không cần cài Python hay Node trên máy đích. Hai script trong `scripts/` chỉ dùng khi cần
bóc lại dữ liệu từ file Excel gốc.

## 2. Cấu hình

```bash
cp .env.example .env
```

| Biến | Mặc định | Ghi chú |
|---|---|---|
| `POSTGRES_DB` | `mgmt-device` | tên database |
| `POSTGRES_USER` | `mgmt-device` | user database |
| `POSTGRES_PASSWORD` | `change-me` | **bắt buộc đổi** trước khi chạy ngoài máy cá nhân |
| `WEB_PORT` | `8080` | cổng nginx publish ra host |
| `ADMIN_USERNAME` | `admin` | tài khoản quản trị đầu tiên |
| `ADMIN_PASSWORD` | *(trống)* | để trống → sinh ngẫu nhiên, in ra một lần khi chạy `seed` |
| `ADMIN_EMAIL` / `ADMIN_NAME` | — | thông tin liên hệ hiển thị trong app |
| `SESSION_HOURS` | `8` | thời hạn phiên đăng nhập |
| `COOKIE_SECURE` | `0` | đặt `1` khi chạy sau HTTPS |

`COMPOSE_PROJECT_NAME=mgmt-device` quyết định tên container và volume. File compose **không** đặt
khóa `name:` (chỉ Compose v2 hiểu — `docker-compose` v1 báo
`'name' does not match any of the regexes: '^x-'`) và cũng **không** đặt `version:`
(Compose v2 cảnh báo lỗi thời; v1 từ 1.27 tự nhận diện cấu trúc `services`).

Với `docker-compose` v1, tên container dùng gạch dưới (`mgmt-device_web_1`) thay vì gạch ngang
(`mgmt-device-web-1`) — thay tên tương ứng trong các lệnh ở dưới. Compose v1 đã hết hỗ trợ,
nên dùng `docker compose` (v2) khi có thể.

`.env` đã nằm trong `.gitignore` — không commit. Không hardcode mật khẩu vào
`docker-compose.yml`; không đưa email/identity vào file cấu hình (đọc từ `$CODER_USER_EMAIL`).

## 3. Triển khai lần đầu

```bash
docker compose up -d --build     # dựng image api, kéo postgres:17-alpine + nginx:alpine
docker compose run --rm seed     # nạp asset_import.csv + asset_history_import.csv vào Postgres
```

Kết quả mong đợi của `seed`:

```
asset_import.csv: 847 dòng -> {'added': 847, 'updated': 0}
asset_history_import.csv: 729 dòng -> {'applied': 729, 'skipped_unknown_asset': 0}
Trong database: 847 tài sản, 729 sự kiện, 5 site, 8 trạng thái, 404 bản ghi có cờ review
```

`seed` cũng tạo tài khoản quản trị và in mật khẩu nếu để trống `ADMIN_PASSWORD`:

```
Đã tạo tài khoản quản trị: admin
  Mật khẩu sinh ngẫu nhiên (chỉ hiện một lần): xxxxxxxxxxxx
```

**Chép mật khẩu này lại ngay** — nó không được lưu ở đâu dạng đọc được, database chỉ giữ bản băm scrypt.

`seed` chạy lại được nhiều lần: nếu database đã có dữ liệu hoặc tài khoản đã tồn tại thì bỏ qua.
Muốn nạp đè dữ liệu và đặt lại mật khẩu quản trị:

```bash
docker compose run --rm -e SEED_FORCE=1 seed
```

Đặt lại mật khẩu mà không đụng dữ liệu:

```bash
docker compose run --rm -e SEED_FORCE=1 -e ADMIN_PASSWORD='mật-khẩu-mới' seed
```

## 4. Kiểm tra sau khi lên

```bash
docker compose ps                            # db + api phải "healthy", web "Up"
curl -s http://localhost:8080/api/health     # {"status":"ok"} — endpoint duy nhất không cần đăng nhập

# Các endpoint dữ liệu đều cần phiên đăng nhập, không có cookie sẽ trả 401:
curl -s -c ck.txt -X POST http://localhost:8080/api/login \
     -H 'Content-Type: application/json' -d '{"username":"admin","password":"..."}'
curl -s -b ck.txt http://localhost:8080/api/data | head -c 200
```

Mở `http://localhost:8080` → đăng nhập → dòng dưới tiêu đề phải ghi
**"nguồn đang đọc: database Postgres"**. Nếu ghi "file tĩnh data/mgmt-device-data.js" nghĩa là
trang không gọi được API — xem mục 8.

## 5. Các service

| Service | Image | Cổng | Vai trò | Restart |
|---|---|---|---|---|
| `db` | `postgres:17-alpine` | 5432 (nội bộ) | Nguồn sự thật: tài sản, lịch sử, trạng thái, tài khoản. Schema chạy tự động từ `db/schema.sql` khi tạo database lần đầu | `unless-stopped` |
| `api` | build từ `./api` | 8000 (nội bộ) | FastAPI. Healthcheck gọi `/api/health` mỗi 10s | `unless-stopped` |
| `web` | `nginx:alpine` | `${WEB_PORT}` → 80 | Phục vụ `index.html` + proxy `/api/` sang api | `unless-stopped` |
| `seed` | build từ `./api` | — | Chạy một lần rồi thoát, nạp CSV vào database | `no` |

Endpoint API:

```
POST /api/login                # {username, password} -> cookie phiên HttpOnly
GET  /api/me                   # thông tin tài khoản đang đăng nhập
POST /api/logout
GET  /api/health               # không cần đăng nhập
GET  /api/data                 # {meta, statuses, assetRows, historyRows}
POST /api/import/assets        # multipart CSV, khóa asset_id
POST /api/import/history       # multipart CSV, khóa asset_id + event_sequence
GET  /api/export/assets.csv
GET  /api/export/history.csv
GET  /api/docs                 # Swagger UI
```

Trừ `/api/health` và `/api/login`, mọi endpoint đều trả 401 nếu chưa đăng nhập.

Dữ liệu nằm trong volume `mgmt-device_pgdata`. `index.html`, `data/`, `db/schema.sql` và
`web/nginx.conf` được mount read-only từ thư mục project.

## 6. Vận hành hằng ngày

```bash
docker compose logs -f api            # xem log, đổi api thành db/web tùy nhu cầu
docker compose restart web            # nạp lại sau khi sửa index.html hoặc nginx.conf
docker compose down                   # dừng, GIỮ dữ liệu trong volume
docker compose down -v                # dừng và XÓA luôn database
```

Sửa `index.html` xong chỉ cần `docker compose restart web` (file mount trực tiếp, không phải
build lại). Sửa `api/app.py` thì phải `docker compose up -d --build api`.

## 7. Sao lưu & phục hồi

Đã kiểm thực tế: dump 847 tài sản → restore sang database trống → đếm lại đúng 847.

```bash
# Sao lưu
docker compose exec -T db pg_dump -U mgmt-device -d mgmt-device --clean --if-exists > backup-$(date +%F).sql

# Phục hồi vào database đang chạy
docker compose exec -T db psql -U mgmt-device -d mgmt-device < backup-2026-09-10.sql
```

Cách thứ hai, không cần Postgres: xuất CSV rồi nạp lại bằng `seed`.

```bash
curl -s -c ck.txt -X POST http://localhost:8080/api/login \
     -H 'Content-Type: application/json' -d '{"username":"admin","password":"..."}'
curl -s -b ck.txt -o asset_export.csv   http://localhost:8080/api/export/assets.csv
curl -s -b ck.txt -o history_export.csv http://localhost:8080/api/export/history.csv
```

## 8. Sự cố hay gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| `failed to bind host port 0.0.0.0:8080: address already in use` | Cổng 8080 đang có tiến trình khác | Đổi `WEB_PORT` trong `.env`, hoặc tắt tiến trình đang chiếm cổng |
| Log web: `host not found in upstream "api"` | nginx khởi động trước api | Đã xử lý sẵn bằng `resolver 127.0.0.11` + biến upstream trong `web/nginx.conf`. Nếu vẫn gặp: `docker compose up -d --force-recreate web` |
| `docker compose ps` báo web `Up` nhưng `curl` trả 000 | Container chạy nhưng chưa gắn network / chưa publish cổng | `docker compose up -d --force-recreate web`, kiểm lại bằng `docker port mgmt-device-web-1` |
| `seed` in `Database đã có N tài sản — bỏ qua` | Đúng thiết kế, tránh nạp trùng | Thêm `-e SEED_FORCE=1` nếu thực sự muốn nạp đè |
| Trang hiện "nguồn đang đọc: file tĩnh" | Proxy `/api/` hỏng hoặc api chưa healthy | `curl localhost:8080/api/health`, xem `docker compose logs api` |
| Import CSV báo "Thiếu cột asset_id" | Sai file hoặc CSV không phải UTF-8 | Dùng đúng `asset_import.csv` / `asset_history_import.csv`, mã hóa UTF-8 (BOM cũng được) |
| Quên mật khẩu quản trị | Mật khẩu chỉ in một lần, database giữ bản băm | `docker compose run --rm -e SEED_FORCE=1 -e ADMIN_PASSWORD='...' seed` |
| Mọi request API trả 401 | Chưa đăng nhập hoặc phiên hết hạn (8h) | Đăng nhập lại; kiểm tra `docker compose exec db psql -U mgmt-device -d mgmt-device -c "select username,last_login_at from app_user"` |
| Sửa `api/app.py` hoặc `api/seed.py` không có tác dụng | Image chưa build lại | `docker compose build api seed` rồi `docker compose up -d api` |
| Sửa `db/schema.sql` không có tác dụng | Schema chỉ chạy khi tạo database lần đầu | `docker compose down -v` rồi dựng lại, hoặc chạy tay bằng `psql` |
| `docker-compose` báo `'name' does not match any of the regexes: '^x-'` | Compose v1 không hiểu khóa `name:` ở cấp cao nhất | File hiện tại đã bỏ `name:`; nếu vẫn gặp là đang dùng bản compose cũ hơn — cập nhật file hoặc chuyển sang `docker compose` v2 |
| `docker-compose` v1 báo lỗi ở `depends_on` | Bản v1 dưới 1.27 không hỗ trợ `condition: service_healthy` | Nâng lên `docker-compose` 1.29.2 hoặc dùng `docker compose` v2 |

## 9. Rollback

```bash
docker compose down
git checkout <commit-trước-đó>          # khi project đã có git repo
docker compose up -d --build
```

Dữ liệu nằm trong volume nên không mất khi rollback code. Nếu bản mới đã đổi schema thì phải
phục hồi dump ở mục 7. Mục tiêu rollback < 1 phút theo NFR trong `docs/PRD.md`.

## 10. Deploy lên hạ tầng nội bộ

Bản compose này dành cho máy dev và preview nội bộ. Muốn đưa lên hạ tầng Mắt Bão:

- Preview nhanh: skill `/deploy-preview` (link tạm) hoặc `/local-dev` (route qua Traefik `*.b.matbao.ai`).
- Chính thức: skill `/deploy-beta` — **bắt buộc** chọn scope public/local; public phải pass
  `/vibe-sec` và qua Gate 2 trước.
- Domain dự kiến: `mgmt-device.sa.dev.matbao.ai` · Coolify: `ops.matbao.ai`.

Trước khi deploy public còn phải làm: phân quyền theo vai trò (hiện mọi tài khoản đều là
`admin`), rate limit / khóa tài khoản khi nhập sai nhiều lần, màn đổi mật khẩu, và bật
`COOKIE_SECURE=1` sau HTTPS. Xem `docs/ARCH.md` mục 5.
