# CLAUDE.md — mgmt-device (Device Management)

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
| `data/mgmt-device-data.js` | `scripts/build_data.py` |

Sửa logic ở script rồi chạy lại. `BAO CAO THEO DOI SERVER (HR+SA).xlsx` là nguồn gốc, không sửa.

## Hiện trạng nằm ở DÒNG CUỐI, không phải cột Datacenter

Sổ Excel nhét cả lịch sử luân chuyển vào **một ô**, mỗi lần chuyển một dòng: cột **V** (ngày),
**W** (nơi đặt), **X** (đối tượng sử dụng). 71 ô ở V và X có nhiều dòng, 55 ô ở W. Cột **O
(Datacenter) thường đứng yên từ lần ghi đầu nên đã cũ** — **dòng cuối mới là hiện trạng**.
`clean_asset_workbook.py` vẫn tách đúng từng dòng thành sự kiện lịch sử, nhưng trước đây lấy
vị trí/trạng thái từ cột O nên 137 tài sản sai hiện trạng.

Quy tắc đang áp:

- dòng cuối của **X hoặc W** là "Kho" -> ở trong kho (`in_stock`). Trạng thái `broken` /
  `retired` **giữ nguyên** — hỏng vẫn nằm được trong kho.
- ngược lại -> đang dùng (`in_use`), và vị trí lấy từ dòng cuối cột W **chỉ khi** nó trùng
  đúng một tên site chuẩn.

**Cột W ghi tên tắt — không được lấy đè.** W có "CMC" (71 ô, không rõ Tân Thuận hay Quận 9)
và "VNPT" (5 ô). Lấy thẳng thì `VNPT Tân Thuận` bị hạ thành `VNPT`. `SITE_NAMES` dựng từ chính
cột Datacenter của sổ (không gõ tay), và khi tên ở W không khớp mà cột O đang ghi "Kho" thì
để **trống** vị trí kèm cờ `current_location_unknown` — 24 tài sản như vậy. Thà nói không biết
còn hơn ghi sai site.

Cờ để lần ra: `location_from_last_transfer` (126), `status_from_last_transfer` (19),
`current_location_unknown` (24).

## Hai hệ mã độc lập — ĐỪNG so sánh sổ với ứng dụng bằng mã tài sản

- Mã trong **sổ Excel** do người gõ tay, mang tính tùy ý (`SSD-240-001`, `CAP-10-0015`).
- Mã trong **ứng dụng** sinh tự động từ hiện trạng thật (`ssd-240-001` = ổ thứ nhất đọc được
  từ bản xuất hệ thống).

Hai hệ này **không liên quan gì nhau**. `SSD-240-001` của sổ là ổ dự phòng nằm kho; `ssd-240-001`
của ứng dụng là ổ đang cắm trong `svr-p07-u23`. Trùng mã **không** có nghĩa trùng vật, và khác
mã **không** có nghĩa khác vật (`SVR-P7-3839` ↔ `svr-p07-u38` là một máy).

Đối chiếu hai nguồn thì dựa vào **hiện trạng vật lý**: rack + ô U cho thiết bị, IP quản trị cho
máy, số linh kiện đã ghi nhận cho ổ. Dùng mã làm khóa so sánh là sai từ gốc — đã mắc một lần và
phải rollback 613 bản ghi.

## CI và triển khai

`.gitlab-ci.yml` có hai job: **`kiem-thu`** (node 22, `npm ci`, `npm test`) và **`dung-anh`**
(dựng ảnh Docker để bắt lỗi Dockerfile sớm — không đẩy registry, không triển khai).

Bộ kiểm thử cần một ảnh chụp dữ liệu ở thư mục gốc, mà CI không có database. Nên CI dùng
**`tests/fixture-30.json`** — 30 tài sản cố định trong repo, chọn theo CA CHỨ KHÔNG NGẪU NHIÊN:
8 có ô U, 10 có thiết bị cha, 12 trong kho, 6 chưa gán mã, 6 loại, 3 trạng thái. Thiếu một ca
là suite tương ứng gãy. Bộ kiểm thử phải xanh với **cả** fixture này lẫn dữ liệu thật.

Hệ quả: **đừng gõ cứng số lượng bản ghi trong test** — `smoke2.js` từng đòi "chọn 50 thì hiện
50 dòng", gãy ngay khi chạy trên fixture 30 bản ghi. Kiểm theo công thức `min(cỡ trang, tổng)`.

`scripts/trien_khai.sh` thay lối chép tay bằng scp: `git pull` → dựng lại container → chờ API
trả 200 mới báo xong. **Không đụng `.env`, không đụng volume dữ liệu.**

### `index.html` bind-mount THEO FILE — đổi file xong phải dựng lại `web`

`docker-compose.yml` gắn `./index.html:/usr/share/nginx/html/index.html:ro`, tức mount **một
file**. `git pull`, `rsync` và phần lớn trình soạn thảo không ghi đè tại chỗ mà **ghi file mới
rồi đổi tên** — inode đổi, còn container vẫn giữ inode CŨ đã bị xoá. Hậu quả rất dễ nhầm: trang
vẫn trả **200**, file trên đĩa đúng bản mới, mà trình duyệt nhận bản cũ.

Kiểm bằng cách so inode hai bên:

```bash
stat -c %i index.html
docker exec atlas-ops_web_1 stat -c %i /usr/share/nginx/html/index.html
```

Lệch nhau thì `docker-compose up -d --no-deps --force-recreate web` (nginx lên dưới một giây).
`trien_khai.sh` đã luôn làm bước này. Đồng bộ tay thì thêm `rsync --inplace` để giữ nguyên inode.

## Sao lưu database

Cấu hình nằm trong bảng `backup_config` (đúng một dòng), đổi được từ **mục Admin**: bật/tắt,
giờ chạy, giữ bao nhiêu bản. **Không dùng cron của máy chủ** — lịch nằm trong database nên
dựng lại ứng dụng ở máy khác vẫn giữ nguyên cấu hình.

- `pg_dump` chạy trong container **api** (ảnh đã cài `postgresql-client`), ghi ra volume
  `backups:/backups` dạng `mgmt-device-YYYYmmdd-HHMMSS.sql.gz`.
- Bộ lập lịch là một **thread nền** kiểm mỗi phút; lỗi trong đó **không được làm chết API**.
- Ghi ra **file tạm rồi mới đổi tên** — bản sao dở dang không bao giờ mang tên thật, nên danh
  sách không bao giờ có file hỏng.
- Danh sách bản sao đọc **thẳng từ đĩa**, không từ một bảng ghi chép: bảng có thể lệch thực tế.
- Dọn bản cũ sau mỗi lần chạy, giữ đúng số đã khai.

Phục hồi (đã kiểm thật, 1232 tài sản khớp):

```bash
docker compose exec -T db psql -U mgmt-device -d postgres -c "CREATE DATABASE thu;"
docker compose exec -T api sh -c "gunzip -c /backups/<file>.sql.gz | psql <dsn>/thu"
```

## GitLab: hai host, đừng nhầm

| Host | Xác thực | Ghi chú |
|---|---|---|
| `git.matbao.support` | token trong `~/.git-credentials` | Token đó của tài khoản **`nk` (namlt@matbao.com)**, KHÔNG phải owner project — đừng mượn |
| `gitlab.infra.matbao.io` | **SSH** (`~/.ssh/id_ed25519`) | Token trên trả 401 ở đây. SSH xác thực đúng `@vydh` |

Repo của project: **`git@gitlab.infra.matbao.io:matbao/mgmt-device.git`** — cùng namespace
`matbao/` với `openstack-sop`, `openstack-system`, `mbcloud-images`. Repo được tạo bằng
**push-to-create** qua SSH, không cần token API.

Hiện repo **chỉ có `README.md`** (nội dung `docs/PROPOSAL.md`). Mã nguồn chưa đẩy — task 4.5
rà soát bí mật phải xong trước, vì `.env` và `~/.git-credentials` từng chứa credential thật.

`scripts/tao_repo_gitlab.py` là đường dự phòng khi có token API; đường đang dùng là SSH.

## Ba vai và mục Admin

| Vai | Đọc | Ghi dữ liệu | Quản lý tài khoản · xoá sạch |
|---|---|---|---|
| `admin` — Quản trị | ✔ | ✔ | ✔ |
| `sua` — Sửa dữ liệu | ✔ | ✔ | ✘ |
| `xem` — Chỉ xem | ✔ | ✘ | ✘ |

Chặn ở **tầng API** bằng hai dependency: `nguoi_ghi` (24 endpoint ghi) và `nguoi_quan_tri`
(quản lý tài khoản + xoá sạch dữ liệu). **Ẩn nút trên giao diện là tiện lợi, không phải bảo
vệ** — `body.chi-xem` chỉ để đỡ bày ra nút bấm vào sẽ báo lỗi.

Hai lớp chặn tự nhốt mình ra ngoài, đã kiểm bằng lệnh thật:

- Không hạ vai / khoá **tài khoản quản trị cuối cùng còn hoạt động** (409).
- Không xoá **tài khoản đang đăng nhập** (409).

`GET /api/users` · `POST /api/users` · `PUT /api/users/{id}` · `DELETE /api/users/{id}` —
tất cả đều chỉ quản trị viên gọi được, và đều ghi vào `audit_log` với `entity = user`.
Mật khẩu tối thiểu 8 ký tự, băm scrypt, **không bao giờ vào nhật ký** (`password_hash` bị
loại khỏi phần `changes`, chỉ ghi ghi chú "đổi mật khẩu").

### Màn Nhập / Xuất chia 3 tab

`Nơi lưu dữ liệu` (kèm nhập/xuất file) · `Nhật ký nhập file` · `Nhật ký thao tác`.
`bindTabs()` dùng chung cho mọi thanh `.tabs`; panel ẩn bằng thuộc tính `hidden`.
Nút **Xoá sạch dữ liệu đã chuyển khỏi sidebar** vào mục Admin — việc nguy hiểm không nên
nằm cạnh nút Đăng xuất.

### Đừng bám vào `apiAvailable` để suy vai

`apiAvailable` được đặt ở bước khác trong luồng khởi động, nên bám vào nó là bám vào thứ tự
chạy — đã có lần cờ `chi-xem` không được gắn vì thế. Bám vào `currentUser` đã có hay chưa.

## Nhật ký thao tác — bảng `audit_log`

Mọi thao tác GHI đều để lại một dòng: **ai · lúc nào · làm gì · giá trị cũ là gì**.
Ghi ở **tầng ứng dụng** chứ không bằng trigger database, vì chỉ tầng ứng dụng mới biết ai đang
thao tác (phiên đăng nhập).

| Cột | Nội dung |
|---|---|
| `action` | `them` · `sua` · `xoa` · `nhap` · `luan_chuyen` · `xoa_sach` |
| `entity` | `asset` · `event` · `status` · `asset_type` · `cluster` · `location` · `data` |
| `changes` | JSONB `{cột: {"cu": ..., "moi": ...}}` — chỉ giữ cột THỰC SỰ đổi |
| `note` | câu giải thích khi cần (đổi mã, sửa hàng loạt, phạm vi xóa sạch) |

Hai quy tắc khi thêm endpoint ghi mới:

- **Đọc giá trị cũ TRƯỚC khi xóa/sửa.** Xóa xong rồi thì không còn gì để ghi vào nhật ký.
  `delete_asset` và `bulk_delete` đều `SELECT` trước khi `DELETE`.
- **Lỗi ghi nhật ký không được làm hỏng việc chính.** `ghi_nhat_ky()` nuốt mọi lỗi — mất một
  dòng nhật ký còn hơn làm hỏng thao tác người dùng vừa thực hiện.

`doi_gi(truoc, cot)` dựng phần `changes`, bỏ qua cột có giá trị không đổi. Xóa hàng loạt thì
nhật ký giữ **đủ tên từng bản ghi** vì đó là thao tác không lùi được.

Đọc bằng `GET /api/audit?entity=&entity_id=&limit=` — hồ sơ tài sản chỉ hỏi nhật ký **của
chính nó** (`entity=asset&entity_id=<mã>`), không tải cả kho.

## Cụm và vị trí là hai chiều ĐỘC LẬP

**Một tủ phục vụ nhiều cụm, một cụm trải nhiều tủ** — quan hệ nhiều–nhiều, nên **không tồn tại
"ánh xạ cụm → tủ"**. Đừng suy vị trí từ cụm, cũng đừng suy cụm từ vị trí. Ca `CMC1 → P07` từng
làm được chỉ vì cụm đó tình cờ nằm gọn một tủ; đó là ngoại lệ, không phải quy tắc.

Hệ quả: **gán vị trí là việc làm tay của người quản trị**, không tự động hoá được. Công cụ:

- **Ô lọc theo cụm** ở danh mục tài sản (`clusterFilterFull`), liệt kê từ **danh mục cụm** nên
  cụm chưa gán tài sản nào vẫn chọn được, cộng lối chọn **"— Chưa gán cụm —"** — đó chính là
  tập cần xử lý tay.
- Lọc ra rồi **sửa hàng loạt** để đặt rack: `cluster` và `rack_id` đều nằm trong `BULK_FIELDS`.
- Cột **Vị trí không bao giờ hiện tên cụm** — cụm không phải vị trí.

### Nhãn trùng tên cụm thì vào TRƯỜNG CỤM

File nhập ghi "Nơi gắn linh kiện" bằng nhãn cụm (`CMC1`, `VNPT1`) chứ không bằng mã máy. Nhãn
không khớp mã nào nhưng **trùng tên một cụm đã khai** thì `prepare_asset` đưa về `cluster`, chứ
không để nằm ở `attachment_label` — nằm ở đó thì không bộ lọc nào tìm ra được. Nhãn lạ thật sự
vẫn giữ nguyên làm nhãn cha chưa khớp.

### Danh mục cụm không phân biệt hoa thường khi nhập

Khóa duy nhất của bảng `cluster` phân biệt hoa thường nên `BACKUP` và `backup` từng thành **hai
cụm**. Nay khi nhập file, cụm chỉ khác cách viết sẽ **dùng lại tên đã có** thay vì đẻ thêm bản
ghi trùng nghĩa.

## Admin là nơi cấp mã tài sản

Quy tắc đã chốt (task 3.7): **mã tài sản do admin đặt, ứng dụng không tự chế tiền tố.**

- Không gắn tiền tố theo nguồn, theo chỗ để, hay theo bất cứ thứ gì vào mã admin đưa.
- Mã trong file nhập được dùng **nguyên văn**.
- Mã đã có chủ khác thì **để trống** cho admin điền, không tự đặt mã thay. Ứng dụng cấp mã tạm
  `CHUA-GAN-####` và hiển thị "Chưa gán mã" — đây là chỗ trống chờ admin, không phải tiền tố.
- Hai nguồn đụng mã thì hàng rào bên dưới chặn lại, admin sửa mã ở file nguồn rồi nhập lại.

### Bug đã sửa: mã trống làm hỏng quan hệ cha-con

`upsert_assets` gom `incoming_ids` từ mọi dòng, **kể cả dòng để trống mã** — chuỗi rỗng lọt vào
tập đó, rồi một `parent_reference` rỗng lại "khớp" với nó và bị ghi thành `parent_asset_id = ''`,
vi phạm khóa ngoại và làm cả lần nhập trả 500. Chỉ lộ khi một file có **cả cột mã lẫn cột cha
đều trống**. Nay lọc chuỗi rỗng khi dựng `incoming_ids`.

## Đụng mã giữa hai nguồn — hàng rào ở đường nhập

Hai nguồn đánh mã độc lập nhau nên **cùng một mã ở hai nguồn là hai vật khác nhau**. Trước
đây đường nhập coi đó là "cập nhật" bình thường: đẩy nguyên file sổ lên thì 106 dòng được
báo là ghi đè, trong đó **103 dòng đè lên ổ đang cắm trong máy**, và người nhập chỉ thấy
dòng chữ "ghi đè 106".

`code_conflict(stored, row)` trong `api/app.py` nhận diện bằng `source_sheet`: mã đã tồn tại,
hai bên đều có dấu vết nguồn, và hai nguồn **khác nhau** -> đụng mã. Thiếu dấu vết nguồn ở
một phía thì **không kết luận** (tài sản nhập tay không có `source_sheet`, chặn bừa là sai).
Nhập lại đúng file cũ vẫn chạy bình thường vì cùng `source_sheet` — đã kiểm: 117 và 182 dòng
đều ra "không đổi", 0 đụng mã.

- `/api/import/preview` trả thêm nhóm **`conflicts`**, tách hẳn khỏi `updated`.
- `/api/import/assets` **bỏ qua** dòng đụng mã và trả danh sách lý do. Muốn ghi đè thật thì
  khai `allow_conflicts=1` trên chính lần nhập đó — cố ý, từng lần, không có cờ toàn cục.
- Giao diện hiện khối "Đụng mã — sẽ KHÔNG nạp" **đứng trước** hai khối kia, nói rõ mã đó
  đang là tài sản nào và lắp ở đâu. Dòng đụng mã **không có ô tick bỏ qua** (nó vốn đã không
  nạp, thêm ô tick chỉ gây hiểu nhầm là phải tự tay bỏ).
- Thông báo sau khi nhập phải nhắc số bản ghi bị bỏ vì đụng mã — im lặng chỗ này là người
  nhập tưởng đã nạp đủ.

Đây là hàng rào an toàn, **không phải quy tắc đặt mã**. Quy tắc đặt mã (tiền tố theo nguồn,
hay một nguồn duy nhất được cấp mã) vẫn là quyết định đang chờ — xem `docs/PROPOSAL.md` task 3.7.

## Nhập hàng kho từ sổ

Chỉ lấy tài sản **đang ở Kho VÀ không ở trạng thái đang sử dụng** (`in_stock`, `retired`,
`broken`, `degraded`, `not_in_use`, `pending_disposal`) — 241 món. Đồ sổ ghi `in_use` thì thuộc
hiện trạng vận hành, không phải hàng kho.

**KHÔNG gắn tiền tố vào mã tài sản.** Trước đây hàng kho mang tiền tố `kho-`; đã bỏ. Tiền tố
đó đặt tên theo *chỗ để* chứ không theo *vật*, trái nguyên tắc "mã đi theo vật" — món trong kho
đem lắp vào máy thì mã vẫn đeo chữ `kho-` (bằng chứng: `kho-svr-kho-001`).

Mã nào trong nguồn đã có chủ khác thì **để TRỐNG** cho admin tự điền; ứng dụng cấp mã tạm và
hiển thị "Chưa gán mã", `source_row` vẫn truy về dòng sổ gốc. 54 món đang ở trạng thái này.

Hai switch `SW-J6-12` / `SW-J6-13` sổ ghi ở Kho nhưng **không nhập** — người quản trị đã xác
nhận chính là hai switch đang lắp ở D12 U44/U45 (`sw-j6-12`, `sw-j6-13`). Loại theo lời xác
nhận đó, không phải vì trùng mã.

### Sơ đồ không đếm hàng kho

Kho tách khỏi sơ đồ, nên `diagramNote` và `diagramCaption` phải lọc `asset.inStore` trước khi
đếm. Trước đây đếm cả vào nên ghi chú báo "241 thiết bị chưa gán rack — xếp vào nhánh Chưa xếp
rack" trong khi nhánh đó rỗng, người xem tìm mãi không thấy.

## Kho không bao giờ là một site

`prepare_asset()` tạo site từ cột `datacenter`; file nhập hay ghi "Kho" ở cột đó, và chỉ cần
quên cờ `in_store` là danh mục Vị trí mọc ra một site "Kho" rỗng. Nay `prepare_asset` **tự
nhận ra**: `datacenter` bỏ dấu bằng "kho" -> đặt `in_store = True`, `datacenter = NULL`, không
tạo site. Đừng gỡ đoạn này rồi trông chờ file nhập lúc nào cũng đúng.

## Bộ lọc của các danh sách

| Danh sách | Điều khiển |
|---|---|
| Danh mục tài sản | tìm · loại · trạng thái · site · **Xóa** |
| Kho | tìm · loại · trạng thái · **Xóa** |
| Danh mục vị trí | tìm · cấp (Site / Phòng máy / Rack) |
| Danh mục cụm · trạng thái · loại tài sản | tìm |

Bố cục thống nhất: **ô tìm -> các ô lọc -> nút Xóa đứng cuối hàng** (smoke15 kiểm đúng thứ tự
này, đừng chèn gì sau nút Xóa).

Hai điểm dễ làm sai:

- Ô lọc loại/trạng thái của **Kho chỉ liệt kê thứ thực sự đang nằm trong kho**, không bày cả
  danh mục — bày hết thì đa số lựa chọn bấm vào ra bảng rỗng.
- So chuỗi qua `noAccent()` (bỏ dấu, hạ chữ thường) nên gõ "kho" khớp "Kho", "tan thuan" khớp
  "Tân Thuận". Dùng `filterText(id)` + `hitText(query, ...)` thay vì tự viết lại từng chỗ.

## Mã tài sản đi theo VẬT, không theo chỗ

Thiết bị luân chuyển thì **giữ mã gốc**, không đổi theo chỗ mới: mã là danh tính của vật,
đổi mã mỗi lần dời chỗ thì mất dấu lịch sử. Cùng lý do với mã ổ cứng (`ssd-2tb-001` không mang
vị trí). Đang có ba ca như vậy, đều đứng ở tủ D12 nhưng mang mã tủ cũ:

| mã | đứng tại | vốn là |
|---|---|---|
| `sw-j6-12` | D12 U44 | J6 — Nexus C3064 |
| `sw-j6-13` | D12 U45 | J6 — Nexus C3064 |
| `sw-j3-45` | D12 U47 | J3 — Nexus 3048 |

Hệ quả: **đừng suy rack từ mã tài sản** cho thiết bị đã luân chuyển — `build_j_map.py` và
`rack_cables.py` đọc rack từ `rack_id` trong database, không tách từ mã, nên vẫn đúng.

### Cột thiếu trong header thì DictWriter nuốt im lặng

`asset_import.csv` không có cột `in_store`. Dựng file nhập kho bằng cách chép dòng của sổ rồi
gán `r["in_store"] = "1"` mà quên thêm cột vào `fieldnames` thì `csv.DictWriter(...,
extrasaction="ignore")` **bỏ qua không báo gì** — nhập xong 6 tài sản nằm ngoài kho. Thêm cột
vào header trước khi gán, và luôn đối chiếu lại bằng truy vấn `WHERE in_store = true`.

### Bug đã sửa: đổi mã thiết bị có vị trí U

`asset_changes()` nhận `asset_id=new_id`, nhưng lúc kiểm trùng ô U thì hàng trong database vẫn
mang **mã cũ** — thiết bị tự thấy chính mình và trả 409 "U44 đang là chỗ của sw-d12-u44". Nay
loại trừ **cả mã mới lẫn mã hiện tại**. Lỗi này chặn việc đổi mã của mọi thiết bị đứng trong rack.

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

## Chạy bộ kiểm khói

```bash
npm install                                          # chỉ cần jsdom
curl -s -b <cookie> http://127.0.0.1:8084/api/data > api-data.json
npm test                                             # tests/run.js chạy hết, tổng kết PASS/FAIL
```

`tests/run.js` tự quét `tests/smoke*.js` và `tests/check_*.js` nên thêm suite mới **không phải
sửa gì**. Test đọc `index.html` và `api-data.json` ở thư mục gốc, còn fixture (`fixture-move.json`,
`fixture-u.json`) nằm cạnh test và được trỏ bằng `__dirname` — đừng đổi thành đường dẫn tương
đối, chạy từ thư mục khác là gãy.

`api-data.json` là **ảnh chụp dữ liệu thật**, đã gitignore — không commit, và nhớ lấy lại sau
mỗi lần đổi dữ liệu, không thì test kiểm trên dữ liệu cũ mà vẫn báo xanh.

Suite nào không chạy được (thiếu fixture, lỗi cú pháp) thì `run.js` báo **KHÔNG CHẠY ĐƯỢC** và
trả mã lỗi — im lặng bỏ qua một suite còn nguy hơn để nó fail.

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
npm install && npm test                   # 21 bộ kiểm khói (cần api-data.json ở thư mục gốc)
docker compose up -d --build              # db + api + web  → http://localhost:8080
docker compose run --rm seed              # nạp CSV vào Postgres (SEED_FORCE=1 để nạp đè)
python3 scripts/clean_asset_workbook.py   # XLSX → CSV   (pip install -r requirements.txt)
python3 scripts/build_data.py             # CSV  → data/mgmt-device-data.js (bản chạy không cần database)
python3 -m http.server 8080               # xem trang tĩnh, không cần database
```

## Database là nguồn dữ liệu duy nhất

Postgres là nơi lưu dữ liệu. Mọi thao tác thêm / sửa / xóa của người dùng — một bản ghi hay
hàng loạt, tài sản, sự kiện, trạng thái, vị trí — đều phải đi qua API và ghi vào database.
**Không được** đổi dữ liệu trong `state` rồi `renderAll()` coi như xong: sửa xong thì gọi
`refreshFromApi()` để đọc lại từ database.

File Excel / CSV / XLSX **chỉ là công cụ hỗ trợ**, không phải nguồn chân lý:
nhập = đẩy file lên `/api/import/*` cho API ghi vào database (có ghi `import_log`),
xuất = tải từ `/api/export/*`. Giao diện không được mô tả sổ Excel như nơi hệ thống đọc dữ liệu.
`source_sheet` / `source_row` chỉ còn là **dấu vết nguồn** của bản ghi, hiển thị trong hồ sơ
chi tiết để truy ngược, không phải trạng thái hiện tại.

`origin` phân biệt bản ghi `import` (nạp từ file) với `manual` (nhập tay trên giao diện) —
bản ghi nhập tay không có `source_row`, đó là chuyện bình thường, không phải thiếu dữ liệu.

Chế độ chạy không có database (`data/mgmt-device-data.js`) là **bản chụp chỉ đọc**: bật class
`read-only` trên `body`, mọi nút ghi bị tắt và `canWrite()` chặn mọi handler. Tuyệt đối không
cho sửa vào bộ nhớ trình duyệt rồi báo "đã lưu". `mapAssetRow` / `mapHistoryRow` vẫn dùng chung
cho cả hai đường — đừng viết mapper thứ hai cho API.

Endpoint ghi: `POST/PUT/DELETE /api/assets`, `/api/events`, `/api/statuses`, `/api/locations`,
`/api/clusters`,
`POST /api/assets/bulk-update|bulk-delete`, `POST /api/import/{assets,history}`.
Whitelist cột sửa được nằm ở `ASSET_FIELDS` trong `api/app.py` — tên cột ghép thẳng vào SQL nên
mọi trường mới bắt buộc khai vào đó, không nhận tên cột tùy ý từ client.


## Danh mục dùng chung — form phải CHỌN, không gõ tay

Bốn thứ này có danh mục riêng trong database, form tài sản (và form sửa hàng loạt) phải là ô
chọn lấy từ đó, không để người dùng gõ chuỗi tự do:

| Trường | Bảng | Quản lý ở màn |
|---|---|---|
| Trạng thái (`usage_status`) | `status_catalog` | Trạng thái |
| Site (`datacenter`) | `site` | Vị trí & Cụm |
| Rack (`rack_id`) | `rack` (qua `room` → `site`) | Vị trí & Cụm |
| Cụm (`cluster`) | `cluster` | Vị trí & Cụm |

Vị trí có ba cấp **Site → Phòng máy → Rack**, cùng đi qua `/api/locations` với `kind` =
`location` | `room` | `rack`; mã vị trí là `site-<id>` / `room-<id>` / `rack-<id>`. Cấp con
CHỌN cấp cha từ danh mục, không gõ lại tên — API trả 400 nếu site không có thật hoặc phòng máy
không thuộc site đang chọn. Xóa thì phải từ dưới lên: còn tài sản thì không xóa được rack/site,
còn rack thì không xóa được phòng máy, còn phòng máy thì không xóa được site (`room`/`rack`
nối vào `site` bằng ON DELETE CASCADE nên xóa site là mất cả cây con).

Form dựng ô theo cấp bằng `KIND_FIELDS` + `onReady` trong `openLocationForm`; ô bị ẩn vẫn nằm
trong DOM nên KHÔNG được đặt `required` lên chúng — trình duyệt sẽ chặn submit vì không focus
được ô đang ẩn. Kiểm bắt buộc làm trong handler.

API tự chặn giá trị ngoài danh mục (400). Rack phải nằm trong đúng site đang gán, nếu không
cũng 400; đổi site mà không nói gì về rack thì rack cũ bị bỏ, còn sửa hàng loạt chỉ chọn rack
thì site tự đi theo rack. Nhập file vẫn được phép mang cụm mới vào — khi đó cụm được ghi thêm
vào danh mục chứ không bị bỏ qua.

`bindRackToSite()` trong `index.html` lo việc lọc rack theo site đang chọn; muốn thêm ô chọn
phụ thuộc nhau khác thì dùng tham số `onReady(form)` của `openModal`.


## Template XLSX nhập liệu

`GET /api/template/mgmt-device-import-template.xlsx` dựng file tại chỗ từ danh mục đang có trong
database (`build_template` trong `api/app.py`), nên ô chọn trong file luôn khớp site / rack /
cụm / trạng thái thật — không có bản cứng nào để đi lệch. File gồm 4 sheet:
`Hướng dẫn` (mở đầu tiên) · `Tài sản` · `Lịch sử` · `Danh mục`.

Giải thích từng cột nằm ở **comment trên ô tiêu đề**, không phải dòng phụ — thêm dòng nào dưới
tiêu đề là dòng đó bị đọc thành dữ liệu. Ô chọn (data validation) trỏ vào sheet `Danh mục`.

Vì file có nhiều sheet nên `rows_from_xlsx(raw, want)` **dò sheet theo bộ cột** chứ không lấy
sheet đầu: `assets` = sheet có `asset_id` mà không có `event_sequence`, `history` = sheet có cả
hai. Nhờ vậy cùng một file dùng được cho cả hai ô nhập. Sửa `ASSET_COLUMNS` / `HISTORY_COLUMNS`
thì nhớ sửa `ASSET_COLUMN_GUIDE` / `HISTORY_COLUMN_GUIDE` kèm theo, không thì cột mới không có
lời giải thích nào.


## Sơ đồ hạ tầng (màn Sơ đồ)

Cây Site → Phòng máy → Rack → Thiết bị → Linh kiện, dựng bằng `buildTopology()` +
`nodeMarkup()` trong `index.html`. Chỉ dựng HTML cho nhánh đang mở nên 848 thiết bị vẫn nhẹ.

Hai quy tắc không được phá:

- **Linh kiện luôn nằm dưới thiết bị cha**, dù hồ sơ ghi vị trí ở đâu — lắp vào máy nào
  thì nằm trong máy đó. Hồ sơ ghi khác chỗ máy cha đang đứng thì node có chú thích
  `hồ sơ ghi ở <nơi>`, không lặng lẽ nuốt mất chênh lệch.
- **Số đếm tính ngược từ cây** (`countUp`), không lọc lại danh sách — con số luôn khớp
  đúng những gì đang vẽ. Hệ quả: site có linh kiện đang lắp ở site khác sẽ đếm thiếu so
  với số bản ghi ghi tên nó; ghi chú dưới sơ đồ nói rõ điều đó, và khi lọc theo site thì
  kể tên từng linh kiện đang hiện ở nơi khác. Không bản ghi nào biến mất.
- **Không đoán vị trí.** Thiết bị chưa có phòng/rack đi vào nhánh "Chưa xếp phòng máy" /
  "Chưa xếp rack", không gán bừa vào rack nào. Ghi chú dưới sơ đồ nói rõ số lượng, cùng
  với 388 nhãn cụm chưa khớp mã.

Trong rack thì xếp theo `rack_unit` giảm dần — U cao nằm trên, đúng như nhìn vào mặt
trước rack; thiết bị chưa ghi U rơi xuống dưới cùng. Ngoài rack thì xếp thiết bị CÓ quan
hệ cha-con lên trước (đó là thứ sơ đồ sinh ra để cho thấy), vì ngăn đông chỉ hiện
`DEVICE_CAP` dòng đầu.

`asset.rack_unit`: vị trí U của thiết bị trong rack, **U1 là đáy rack** (chuẩn EIA-310).
API chặn U ngoài khoảng `1..rack.height_u`, U đã có thiết bị khác (409), và U khi chưa
chọn rack. Bỏ rack thì U tự xóa theo. Không cho sửa hàng loạt trường này — mỗi U chỉ một
thiết bị nên gán chung cho cả lô là vô nghĩa.


## Luân chuyển tài sản

`POST /api/assets/transfer` — **không phải** "sửa trường vị trí". Nó dời thiết bị KÈM toàn
bộ linh kiện đang lắp trong nó (đệ quy theo `parent_asset_id`), và ghi **một dòng lịch sử
cho từng bản ghi được dời**: `event_date` + `location` (nhãn vị trí đích) + `notes`.

- Linh kiện đi cùng thiết bị: cùng site / phòng / rack, nhưng **không có `rack_unit` riêng**
  — chúng nằm trong máy chứ không chiếm ô rack nào.
- Muốn để lại một linh kiện thì **tháo nó ra trước** (xóa thiết bị cha ở form sửa) rồi mới
  bấm luân chuyển. Đây là quy trình do người dùng chốt; form chỉ liệt kê sẵn danh sách linh
  kiện sẽ đi cùng để người dùng kiểm trước khi bấm.
- Chuyển nhiều máy một lúc thì không nhận `rack_unit` (mỗi U chỉ một thiết bị).
- Form luân chuyển có nút tắt **↦ Chuyển vào <kho>**: đặt kho đích + trạng thái `in_stock`,
  bỏ phòng máy / rack / vị trí U, rồi gửi luôn — cả thiết bị lẫn MỌI linh kiện lắp trong nó
  (đệ quy nhiều tầng) đều vào kho và đều sang Trong kho. Chưa khai báo kho nào thì nút vẫn
  hiện nhưng bị khoá kèm lý do, KHÔNG ẩn đi — ẩn thì người dùng đi tìm mãi không hiểu nút
  mình vừa được bảo là có nằm ở đâu. Mở sẵn từ nút "Chuyển về kho" hàng loạt thì không thêm
  nút này, vì nút Lưu lúc đó đã làm đúng việc đó rồi.

## Kho

**Kho KHÔNG phải một site.** Nó là cờ `asset.in_store` trên từng tài sản, quản lý ở màn Kho
riêng. Danh mục vị trí (`site`) chỉ còn datacenter — form site không còn ô "Loại site".

Trong kho và đứng ở một site là hai chỗ **loại trừ nhau**: `in_store = TRUE` thì
`datacenter`, `current_location`, `room_id`, `rack_id`, `rack_unit` đều NULL; đặt
`datacenter` thì `in_store` tự về FALSE. API giữ ràng buộc này ở `asset_changes()`,
`prepare_asset()` và `transfer_assets()` — đừng set tay từng cột ở chỗ khác.

Trên giao diện, hằng `STORE = '__store__'` là giá trị của mục "— Trong kho —" trong ô chọn
vị trí; khi gửi lên thì dịch thành `in_store: '1'` + `datacenter: ''`. Sơ đồ chỉ vẽ
datacenter; tài sản trong kho KHÔNG rơi vào nhánh "Chưa ghi site" — ghi chú dưới sơ đồ đếm
riêng và trỏ sang màn Kho.

- Luân chuyển về kho gửi `in_store: '1'` (không gửi `datacenter`); trạng thái **mặc định** thành `in_stock`, áp cho cả linh kiện đi
  cùng. Chỉ là mặc định: người dùng chọn trạng thái khác thì tôn trọng lựa chọn đó, còn giá
  trị do quy tắc tự đặt thì nhả ra khi đổi sang site không phải kho.
- Bảng ở màn Kho chỉ liệt kê THIẾT BỊ; linh kiện nằm trong cột "Linh kiện đi kèm" của chính
  thiết bị chứa chúng. Linh kiện có hồ sơ ghi ở kho nhưng thiết bị cha đứng nơi khác thì
  không thành dòng — ghi chú dưới bảng **kể tên từng cái**, không để rơi vào khoảng trống
  giữa hai màn hình.
- Khi tính tập site cho sơ đồ, phải tách hai tập: `known` (mọi site đã khai báo, để biết thế
  nào là "chưa ghi site") và `drawn` (site sơ đồ vẽ, không có kho). Lẫn hai tập này thì toàn
  bộ tài sản trong kho bị đếm nhầm sang nhánh khác.


## Sắp xếp theo cột

Mọi danh sách item đều bấm tiêu đề cột để sắp: ba trạng thái **tăng → giảm → về thứ tự gốc**.
Ô trống LUÔN xuống cuối bất kể chiều sắp — "chưa có dữ liệu" không phải giá trị nhỏ nhất hay
lớn nhất. Bảng tài sản và bảng kho sắp trên **toàn bộ dữ liệu rồi mới phân trang**
(`applySort` trong `visibleAssets` / `storeAssets`), không phải sắp riêng trang đang xem.
Bảng nhỏ dựng lại bằng innerHTML mỗi lần render nên sắp ngay trên DOM (`bindMiniSort`), có
giữ thứ tự gốc để còn quay về được.


## Một tên duy nhất: `mgmt-device`

Tên hiển thị là **Device Management**, tên kỹ thuật là `mgmt-device`. Ở **mã nguồn** đã thống
nhất hết:

| Chỗ | Cũ | Nay |
|---|---|---|
| Tên hiển thị | Atlas Ops | Device Management |
| File chụp offline | `data/atlas-data.js` | `data/mgmt-device-data.js` |
| Biến toàn cục | `window.ATLAS_DATA` | `window.MGMT_DEVICE_DATA` |
| Cookie phiên | `atlas_session` | `mgmt_device_session` |
| Khóa localStorage | `atlas.pageSize.*` | `mgmt-device.pageSize.*` |
| Tiền tố file sao lưu | `atlas-*.sql.gz` | `mgmt-device-*.sql.gz` |

### Bản đang chạy vẫn mang định danh hạ tầng cũ — CỐ Ý, không phải sót

| Chỗ | Bản đang chạy trên 103.15.49.62 | `.env.example` (cài mới) |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `atlas-ops` | `mgmt-device` |
| `POSTGRES_DB` / `POSTGRES_USER` | `atlas` | `mgmt-device` |

Nên container vẫn tên `atlas-ops_api_1` / `atlas-ops_db_1`, volume vẫn `atlas-ops_pgdata` /
`atlas-ops_backups`. Cài mới từ `.env.example` thì ra tên `mgmt-device`. **Đừng sửa `.env` của
bản đang chạy cho "khớp tài liệu"** — đổi tên database bắt buộc đi kèm `ALTER DATABASE` +
`ALTER ROLE` trong Postgres và chép volume sang tên project mới; sửa mỗi `.env` thì compose
dựng database RỖNG mang tên mới, còn dữ liệu cũ nằm lại volume cũ không ai đọc.

**Cạm bẫy đã vấp:** đổi `POSTGRES_PASSWORD` trong `.env` làm compose thấy cấu hình **mọi
service có `DATABASE_URL`** thay đổi (`db`, `api`, và cả `seed`) nên đòi dựng lại chúng —
docker-compose v1 vấp `KeyError: 'ContainerConfig'` giữa chừng, để lại container bị đổi tên lạ
và đã tắt. Dữ liệu không mất (nằm ở named volume) nhưng dịch vụ chết vài phút. Hai cách né:

- `-V` (`--renew-anon-volumes`) làm compose **bỏ qua** đoạn đọc `image_config` của container cũ
  — chính chỗ ném KeyError. An toàn ở đây vì `pgdata` và `backups` đều là named volume, không có
  volume ẩn danh nào để mất.
- **Nêu đích danh service**, đừng `docker-compose up -d` trống: lệnh trống kéo theo cả `seed`
  (thứ chỉ chạy một lần rồi thoát), và chính container `seed` cũ nằm đó làm gãy cả lượt triển
  khai dù `api`/`web` chẳng sao. `scripts/trien_khai.sh` nay dùng `up -d --build -V db api web`.

Nạp dữ liệu gốc thì gọi tay: `docker-compose run --rm seed`.

### Mật khẩu database

Trước đây `POSTGRES_PASSWORD` = `POSTGRES_USER` = `POSTGRES_DB` = `atlas` — một từ 5 ký tự.
Nay là chuỗi ngẫu nhiên 48 ký tự hex, **sinh ngay trên server** (`openssl rand -hex 24`), chỉ
nằm ở `/root/mgmt-device/.env` và bản lưu `/root/.mk_mgmt_device` (quyền 600). Không chép sang
workspace, không vào git. Cách đổi:

```bash
# 1. đổi trong Postgres (không làm rớt kết nối đang mở)
printf "ALTER ROLE atlas PASSWORD '%s';\n" "$M" | docker exec -i atlas-ops_db_1 psql -U atlas -d postgres -f -
# 2. sửa .env  3. dựng lại RIÊNG api
docker-compose up -d --no-deps api
```

Cổng 5432 **không publish ra host**, chỉ container trong mạng docker nối được — đó là lý do
mật khẩu yếu trước đây chưa bị phơi, không phải lý do để giữ nó.

**Bài học khi thay tên hàng loạt:** lệnh thay thế đã sửa luôn một câu khẳng định trong
`smoke7.js` — test vốn kiểm *"không còn chữ Atlas Ops"* biến thành kiểm *"không còn chữ
Device Management"*, tức đòi tên hiện tại phải biến mất. Nay tên cũ trong test được **ghép
chuỗi** (`'At' + 'las Ops'`) để lần đổi tên sau không nuốt mất chính cái tên đang cần tìm.


## Phòng ban khác — mẫu file xuất khai trong database

Mỗi phòng ban cần một hình dạng file khác nhau: bên nạp ERP cần đúng đường dẫn trường của ERP,
bên kiểm kê cần cột đọc được bằng mắt. **Ghim từng mẫu vào code là sai đường** — đổi một cột
thành phải sửa code rồi triển khai lại. Mẫu nằm ở bảng `export_template`, quản lý ở màn
**Phòng ban khác**; thêm cột hay đổi cách lấy dữ liệu chỉ là sửa dữ liệu.

Mỗi mẫu = **một tác vụ**: tên mẫu đặt theo việc (`Kiểm kê thiết bị SA → ERP`), không đặt theo
tên phòng ban — một phòng ban có thể cần nhiều mẫu cho nhiều việc.

### Khuôn lấy dữ liệu của một cột

| Khuôn | Ra gì |
|---|---|
| `Thiết Bị System Admin` | hằng số — **không có `$` thì cả chuỗi là giá trị cố định** |
| `$asset_id` | giá trị của trường |
| `${asset_id}` | như trên, ngoặc để tách khỏi chữ dính liền |
| `text_${asset_id}_text` | trộn chữ thường với giá trị |
| `$site-$cluster-$loai_nhan` | ghép nhiều trường |
| `${usage_status\|trang_thai_erp}` | lấy giá trị rồi tra qua bảng đổi từ vựng |
| `$$` | một dấu `$` thật |

Cột còn có **bảng đổi áp lên giá trị cuối cùng** — dùng khi phải tra bằng nhiều mảnh: ERP tách
SSD với HDD trong khi app chỉ có một loại `disk`, nên cột đó khai khuôn `$asset_type/$ma_tien_to`
rồi tra bảng với khoá `disk/ssd`, `disk/hdd`. Khoá `*` là giá trị cho mọi trường hợp không khớp.

**Tham chiếu tới trường không có thì API trả 400**, không lặng lẽ để trống — gõ nhầm tên trường
mà file vẫn xuất ra là kiểu sai khó tìm nhất.

### Trường dựng thêm

`stt` (số thứ tự dòng) · `ma_tien_to` · `loai_nhan` · `trang_thai_nhan` · `site` · `rack` ·
`phong` · `noi_luu` · **`ma_hien_thi`**.

`$ma_hien_thi` khác `$asset_id`: mã tạm `CHUA-GAN-####` là **chỗ trống chờ admin điền, không
phải danh tính của vật**. Gửi nó ra ngoài là bên nhận tưởng mã thật rồi ghi vào sổ của họ. Nên
file cho phòng ban khác dùng `$ma_hien_thi` (để trống khi `code_pending`), còn `$asset_id` giữ
mã thật cho xuất/nhập nội bộ khớp lại được.

### Kiểu ô và bảng đổi từ vựng

Mỗi cột khai kiểu `chu` / `so` / `ngay`. Ghi tất cả thành chữ thì bên nhận đọc số thành text rồi
báo lỗi nạp — `ep_kieu()` chuyển giá và ngày về đúng kiểu của Excel.

Bảng đổi viết kiểu INI (`[tên_bảng]` rồi từng dòng `cũ = mới`) để dán thẳng từ Excel sang được,
thay vì một lưới ô nhỏ xíu.

### Ba mẫu gieo sẵn

`gieo_mau_xuat()` gieo khi bảng còn RỖNG: `Kiểm kê thiết bị SA → ERP` (dựng theo file
`NB-HR-Kiem ke thiet bi SA`, 19 cột, **header hai dòng** — dòng 2 là đường dẫn trường Odoo, sai
một chữ là ERP từ chối cả file), `Biên bản bàn giao thiết bị`, `Kiểm kê hàng trong kho`. Xoá hết
rồi khởi động lại thì gieo lại — đó là đường quay về bản gốc, không phải lỗi.

Mẫu ERP còn **ba chỗ chờ chốt**, ghi rõ trong `note` của chính mẫu đó: cột NƠI BẢO QUẢN (file
gốc ghép 5 mảnh, app chưa có "đối tượng sử dụng" theo từng tài sản nên tạm ghép 3), trạng thái
`broken` / `degraded` đang xếp tạm, và bốn cột app có dữ liệu nhưng file gốc để trống.

## Nhập file phải xem trước

`POST /api/import/preview` (form: `kind` = assets|history, `file`) trả về ba nhóm:
`added` (sẽ thêm mới), `updated` (sẽ ghi đè, kèm `changes` gồm từng trường cũ/mới),
`unchanged`. **Không ghi gì vào database.** Người dùng tick "bỏ qua" từng bản ghi, rồi
`POST /api/import/{assets,history}` với form `skip` = JSON mảng khóa
(`asset_id`, hoặc `asset_id#event_sequence` cho lịch sử).

`prepare_asset()` / `prepare_event()` là đường DUY NHẤT dựng giá trị từ một dòng file —
cả xem trước lẫn ghi thật đều gọi nó, để bản xem trước không bao giờ nói một đằng rồi ghi
một nẻo. `prepare_asset(..., register=False)` là chế độ xem trước: chỉ tính giá trị, không
tạo thêm site / cụm / nhà cung cấp / trạng thái trong danh mục.

## Xoá sạch dữ liệu

`POST /api/data/wipe` với `confirm` = `XOA SACH` và `scope`:
`records` (asset, asset_event, import_log) hoặc `all` (thêm placement, rack, room, site,
cluster, supplier). **`app_user` và `status_catalog` không bao giờ bị xoá** — xoá tài khoản
là tự khóa mình ra ngoài, xoá danh mục trạng thái là làm hỏng khóa ngoại của mọi tài sản
về sau. Hộp thoại nói trước sẽ mất bao nhiêu bản ghi và bắt gõ đúng câu xác nhận.

## Kiểm thử tầng API

`tests/api/chay_api.py` — **146 ca, chạy bằng HTTP THẬT** trong chính ảnh production:
uvicorn (đã có sẵn trong ảnh) chạy nền một luồng, phía gọi dùng `urllib` của thư viện chuẩn.
**Không thêm phụ thuộc nào** — không pytest, không httpx. Nhờ đi qua đúng tầng mà người dùng
đi qua (cookie phiên, multipart, mã HTTP) nên bắt được cả những lỗi mà gọi thẳng hàm Python
không thấy.

```bash
ssh root@<server> 'cd /root/mgmt-device && ./scripts/kiem_thu_api.sh'
```

Dữ liệu nằm ở **database riêng** dựng lúc chạy rồi xoá ngay — không bao giờ đụng database thật.
Nhớ nạp `db/schema.sql` trước: `SCHEMA_PATCH` lúc khởi động chỉ VÁ THÊM, database trống mà chỉ
chạy patch thì vá lên hư không.

**Độ phủ tự chứng minh, không tự nhận.** `kiem_phu_song()` đọc thẳng bảng route của FastAPI
(`app.routes` + `route.path_regex`) rồi đối chiếu với mọi lệnh đã gọi. Thêm endpoint ghi mà
quên viết ca kiểm là bộ kiểm gãy ngay — chứ không lặng lẽ phủ thiếu. Hiện **36/36 endpoint ghi**.

Hai nhóm đáng giá nhất vì chạy theo bảng, không viết tay từng cái:

- **Ma trận phân quyền** — 33 endpoint ghi × 2 vai: chưa đăng nhập phải 401, vai `xem` phải 403,
  và endpoint của quản trị thì vai `sua` cũng phải 403.
- **Chống tiêm SQL** — thử tiêm thật vào đúng những chỗ Bandit cảnh báo, rồi xem bảng còn nguyên
  không. Đọc code rồi tin là chưa đủ.

Ba cái bẫy đã vấp khi viết bộ kiểm này, ghi lại kẻo mắc lại:

| Tưởng là | Thật ra |
|---|---|
| tạo site gửi `name` | gửi `site` |
| sự kiện trả về `id` | trả về `event_id` |
| sửa hàng loạt gửi trường ở gốc payload | gửi trong `changes` |

Cái thứ ba nguy hiểm nhất: gửi sai chỗ thì API trả 400 *"Chưa chọn trường nào để sửa"*, mà hai
ca kiểm "không cho sửa hàng loạt ô U / serial" lại **PASS vì đúng cái 400 sai lý do đó**. Ca
kiểm xanh vì lý do sai còn tệ hơn ca kiểm đỏ.

### Bug thật do bộ kiểm tìm ra

`resolve_room()` coi "không khai phòng máy" và "khai một giá trị đọc không ra" là một, đều rơi
vào phòng ngầm định `—`. Gửi nhầm `roomId="room-1"` thay vì `"1"` thì rack **lặng lẽ nằm sai
phòng**. Nay chỉ để TRỐNG mới là ý "chưa xếp phòng"; giá trị đọc không ra thì trả 400.

## Quét bảo mật

`./scripts/quet_bao_mat.sh` — ba tầng, ba ngưỡng khác nhau và mỗi ngưỡng có lý do:

| Tầng | Công cụ | Ngưỡng | Vì sao |
|---|---|---|---|
| Mã nguồn | Bandit | chặn HIGH | 13 cảnh báo MEDIUM `B608` là **báo nhầm** |
| Phụ thuộc Python | pip-audit | chặn MỌI lỗ hổng | nâng version là xong, không có cớ để nợ |
| Ảnh container | Trivy | chặn HIGH/CRITICAL **có bản vá** | xem bên dưới |

**Vì sao B608 là báo nhầm.** App ghép TÊN CỘT vào SQL ở 13 chỗ, nhưng tên cột luôn lọc qua
whitelist chữ cứng: `asset_changes` dùng `if key in ASSET_FIELDS`, `event_changes` dùng
`EVENT_TEXT & payload.keys()`, `update_user` gán khoá bằng chữ literal, `wipe_data` lấy tên bảng
từ hằng `WIPE_RECORDS`/`WIPE_CATALOGS`. Giá trị thì luôn đi qua `%s`. Đã thử tiêm thật để chứng
minh — xem nhóm "Chống tiêm SQL". **Thêm chỗ ghép tên cột mới thì phải kiểm lại điều này.**

**Vì sao Trivy dùng `--ignore-unfixed`.** Gói hệ điều hành luôn tồn một mớ CVE mà Debian chưa
phát hành vá (hiện **47 lỗi** HIGH/CRITICAL, phần lớn ở `util-linux`, `perl`, `ncurses` — đều
`affected` hoặc `fix_deferred`). Bắt về 0 tuyệt đối thì hoặc không bao giờ xanh, hoặc phải bỏ
qua bừa bằng `.trivyignore` — cả hai đều tệ hơn. Ship một CVE **đã có bản vá** mới là lỗi của
mình, và đó là thứ được chặn.

`apt-get upgrade -y` trong `api/Dockerfile` **không thừa**: ảnh nền `python:3.12-slim` đông cứng
ở thời điểm phát hành nên luôn trễ vài bản vá Debian. Bỏ dòng đó là ship ảnh dính 6 CVE đã có vá.

### Nâng phụ thuộc 18/09/2026

pip-audit báo 11 lỗ hổng: `python-multipart 0.0.20` dính 6 lỗi phân tích multipart (DoS
preamble/epilogue, DoS header, `Content-Length` âm) — app có 3 endpoint nhận file nên đây là
đường tấn công thật; `starlette 0.49.3` dính 5 lỗi, đáng kể nhất là không kiểm `Host` header và
không áp giới hạn form cho `x-www-form-urlencoded`.

Nâng lên `fastapi==0.141.1` (kéo theo starlette 1.6.0, python-multipart 0.0.32) + uvicorn 0.53.0
+ psycopg 3.3.5. Nhân đó bỏ luôn `@app.on_event("startup")` (đã bị đánh dấu bỏ) sang **`lifespan`**
— gom hai việc khởi động về một chỗ và chạy đúng thứ tự: vá lược đồ TRƯỚC rồi mới bật bộ lập
lịch sao lưu, vì bộ lập lịch cần bảng `backup_config`. Đã xác minh luồng nền còn sống bằng cách
hẹn lịch vào phút kế tiếp rồi chờ nó chạy thật, chứ không chỉ xem app có lên hay không.

## Bố cục nút và chữ dài

Ba lỗi trực quan đã mắc và đã có `tests/check_giao_dien.js` canh:

- **Hàng nút nhảy dòng.** `.toolbar-row` là flex có `flex-wrap`, nên khối chữ dài đẩy cụm nút
  rơi xuống dòng dưới — ba mẫu cạnh nhau thì mẫu có ghi chú dài bị lệch hẳn nhịp so với hai
  mẫu kia. Cho khối chữ `flex: 1 1 240px; min-width: 0` để nó **co lại**, và cụm nút dùng
  `.nut-nhom` (`flex: 0 0 auto`) để không bao giờ tự xuống dòng.
- **Chữ dài cắt mất dấu ba chấm.** `text-overflow: ellipsis` chỉ ăn vào chữ nằm TRỰC TIẾP
  trong ô. Tên và mã tài sản nằm trong `<button class="asset-link">` nên bị cắt phăng:
  `svr-d12-u34` hiện ra thành `svr-d12-u3` — **trông y như một mã đủ**, nguy hiểm hơn hẳn việc
  hiển thị thiếu. Luật `table.compact .cell-clip > button` ép nút tự cắt lấy kèm dấu `…`.
- **Ô nhập trong bảng tràn sang cột bên cạnh.** `<input>` giữ bề rộng mặc định 185px của trình
  duyệt, không tự co theo ô. Bảng khai mẫu từng có ô "Bảng đổi" rộng 117px chứa input 185px,
  tràn 78px đè lên cột kế. Mọi input/select trong bảng phải `width: 100%` + `box-sizing:
  border-box`.

Nút phụ dùng `.nut-gon` (padding nhỏ, 13px) để một hàng 4 nút không nặng bằng bốn nút chính.
Ghi chú dài trong danh sách gói bằng `-webkit-line-clamp` kèm `title` để xem đủ khi rê chuột.

**`id` trùng là lỗi câm.** Đã mắc: thêm `id="exportNote"` cho màn Phòng ban khác trong khi màn
Nhập/Xuất đã có sẵn id đó, nên `getElementById` trả về phần tử của màn kia — số đếm "3 mẫu" ghi
nhầm sang chỗ khác và không ai thấy lỗi gì. `check_giao_dien.js` quét toàn file.

### Kiểm bằng mắt: `scripts/chup_man_hinh.sh`

Test chức năng không thấy được nút sát nhau hay chữ tràn ô. Script dựng một bản sao `index.html`
có gắn `fetch` giả (dữ liệu từ `tests/fixture-30.json`) rồi chụp từng màn bằng
`chrome-headless-shell` của Playwright — **không cần đăng nhập, không đụng server**:

```bash
./scripts/chup_man_hinh.sh /tmp/anh 1280
```

Đo đạc sâu hơn (bề rộng ô, chỗ tràn) thì chèn một `<script>` đo vào bản sao đó rồi đọc bằng
`--dump-dom`; đây là cách tìm ra cả ba lỗi ở trên.

## Bề rộng cột

Mọi bảng danh sách đặt `table-layout: fixed` kèm `<colgroup>` khai bề rộng từng cột, để đổi
trang / lọc / sắp xếp không làm cột nhảy qua nhảy lại. Thêm cột mới thì PHẢI thêm `<col>`
tương ứng, không thì cả bảng lệch.


## Danh mục loại tài sản

Bảng `asset_type` (code / label / note / sort_order), quản lý ở màn **Loại tài sản**.
Trước đây đây là hằng `TYPE_META` cứng trong `index.html` nên không sửa được — giờ
`TYPE_SEED` chỉ còn là bản gieo cho chế độ offline, `TYPE_META` dựng lại từ
`DATA.assetTypes` mỗi lần nạp.

- Form tài sản và form sửa hàng loạt CHỌN loại từ danh mục; API trả 400 nếu mã lạ.
- Mã loại chỉ gồm `[a-z0-9_]`. Đổi mã thì tài sản đang mang mã cũ được chuyển theo.
- Loại còn tài sản thì không xoá được (409).
- Nhập file mang mã loại lạ thì mã đó được **ghi thêm vào danh mục**, không bị bỏ qua.
- `asset_type` là master data như `status_catalog`: **không** nằm trong danh sách bảng bị
  "xoá sạch dữ liệu" xoá, vì xoá xong form sẽ không còn gì để chọn cho tới lần khởi động lại.

## Cách hiển thị danh sách tài sản

- **Mã tài sản** hiển thị bình thường (đậm, monospace, màu chữ chính) — KHÔNG làm mờ.
- **Thiết bị cha**: có thì hiện (mã đã khớp là nút mở hồ sơ, nhãn chưa khớp là chữ nghiêng
  mờ); không có thì **để trống hẳn**, không bày chữ `Null` ra.
- **Vị trí**: chỉ `site + rack` (kèm U nếu có), hoặc chip "Trong kho". Cụm KHÔNG nằm ở cột
  vị trí — cụm không phải vị trí và đã có màn riêng.


## Mã tài sản

Mã là khóa chính, **không được trùng**; TÊN thì trùng thoải mái (hai máy cùng model là bình thường).

Thêm tài sản mà chưa biết mã thì **để trống** — API cấp mã tạm `CHUA-GAN-####` từ sequence
`asset_code_seq` và bật cờ `asset.code_pending`. Giao diện hiện **“Chưa gán mã”**, không phơi
mã tạm ra (`codeOf()` / `codeCell()` trong `index.html`); form sửa cũng để ô mã TRỐNG chứ
không điền mã tạm vào. Biết mã thật thì gõ vào, cờ tự tắt và lịch sử / quan hệ cha-con đi
theo nhờ `ON UPDATE CASCADE`.

Mã tạm vẫn là mã thật trong database nên xuất/nhập CSV khớp lại được — `code_pending` nằm
trong `ASSET_COLUMNS`. **Cột boolean khi xuất phải ghi `1`/rỗng, không phải `True`**
(`export_assets_rows` chuẩn hóa `in_store` và `code_pending`), không thì xuất ra nhập lại là
mất cờ.

## Kiểm trùng ngay trong form

`fieldError(form, name, message)` gắn lỗi ngay dưới đúng ô đang sai thay vì chỉ hiện toast.
Form tài sản kiểm hai thứ ngay khi gõ, không đợi bấm Lưu:

- `duplicateCode()` — mã đã thuộc về tài sản nào, nói rõ tên tài sản đó.
- `occupiedUnit()` — vị trí U đã có thiết bị nào trong rack đó. Chỉ xét **thiết bị chính**;
  linh kiện nằm trong máy nên không chiếm ô rack.

Đây là kiểm SỚM cho dễ dùng, không thay thế ràng buộc ở API — API vẫn trả 409 cho cả hai.

## Nhân bản tài sản

Nút **⧉ Nhân bản** chép mọi thông tin từ bản gốc, trừ **mã tài sản** và **vị trí U** để
trống — hai thứ duy nhất không được trùng.

- Chọn **một** tài sản: mở form tạo mới đã điền sẵn để gõ mã ngay
  (`openAssetForm(asset, { clone: true })`).
- Chọn **nhiều**: `cloneSelected()` hỏi xác nhận rồi tạo từng bản sao, mỗi cái nhận **mã tạm**
  `CHUA-GAN-####`. Không thể bắt người dùng gõ mã cho từng cái trong một lượt, và cũng không
  được tự chế mã — mã tạm là đường đúng.

## Nạp dữ liệu từ NetBox

`scripts/netbox_to_import.py` chuyển bản xuất NetBox (`netbox_devices (1).csv`) sang bộ cột
nhập của hệ thống. Sổ NetBox không có mã tài sản nên mã được dựng theo quy tắc
**`<tiền tố loại>-<rack>-u<vị trí U>`** (vd `svr-p07-u42`):

- Tiền tố theo Role: `svr` (Compute & Storage / Compute / Standalone Server), `sw`
  (Core Switch / Access Switch / **Layer2 Storage** — đây là Cisco Nexus làm mạng lưu trữ,
  vẫn là switch), `fw` (Firewall), `hsm` (HSM), `sto` (NAS/DAS).
- Hãng ghi rõ `DAS` hoặc `NAS 2U` thì đi theo hãng chứ không theo Role — NetBox đang để DAS
  ở Role "Standalone Server".
- Rack lấy theo **đúng tên trong danh mục vị trí của hệ thống**, không theo CSV: NetBox ghi
  `P7` còn danh mục ghi `P07`. Lệch tên là lúc nhập rack không khớp và mất vị trí.
- Vị trí U đệm 2 chữ số (`u05`) cho khớp cách đặt tên rack và để mã sắp xếp đúng thứ tự.

## Nạp ổ cứng từ bản xuất hệ thống ảo hóa

Hai bước, hai script — **đừng gõ tay bảng IP vào script**, mỗi bản xuất là một tủ khác:

```bash
python3 scripts/build_host_map.py <host_*.csv> asset_import.csv <ảnh chụp asset>.csv map.json
python3 scripts/host_to_disks.py  <host_*.csv> <file nhập>.csv map.json <ảnh chụp asset>.csv
```

**Nối IP về mã tài sản — hai kiểu tủ, hai script.** Bản xuất chỉ có IP; hệ thống đặt mã
theo rack + vị trí U. Cả hai script đều in bản đối chiếu từng dòng và **dừng hẳn** nếu một IP
không nối được chứ không đoán:

- `build_j_map.py <host.csv> <ảnh chụp asset>.csv asset_import.csv map.json <RACK,...>` — dùng
  khi **tên máy đã mang đuôi IP**: `Email Node 06 - 128.6` (P07), `Node ClusterX113 - 49.167`
  (J3–J6). Nối thẳng bằng tên rồi đối chiếu chéo lại với sổ Excel gốc ở những IP sổ có.
- `build_host_map.py <host.csv> asset_import.csv <ảnh chụp asset>.csv map.json` — dùng khi
  **tên máy KHÔNG mang IP**: `Node VNPT104` (AQ53/AQ54). Bắt buộc đi vòng qua **sổ Excel gốc**,
  nơi duy nhất có cả IP lẫn rack/U:

      IP -> sổ gốc: mã cũ SVR-AQ53-2425 (rack AQ53, U24) -> mã đang dùng svr-aq53-u24

**Máy đổi IP.** Tên trong sổ đăng ký giữ IP CŨ nên nối bằng tên sẽ trượt: `103.15.49.220` của
tủ J6 không có ở đâu cả, hóa ra là IP mới của `Node Cluster924 - 49.181` (svr-j6-u25). Khai
`<IP mới>=<IP cũ>` trên dòng lệnh để nối qua IP cũ, còn IP ghi vào hồ sơ vẫn là IP mới:

```bash
python3 scripts/build_j_map.py <host.csv> <asset>.csv asset_import.csv map.json J6 \
    103.15.49.220=103.15.49.181
```

Script chỉ bồi trường `ip_address`, **không tự đổi tên** — tên là nhãn của sổ đăng ký. Ở ca
này người quản trị đã duyệt nên tên cũng đã đổi thành `Node Cluster924 - 49.220`; đổi tên không
làm rời linh kiện vì quan hệ cha-con bám theo `asset_id` chứ không theo tên.

Thêm `--bo-qua-khong-khop` để bỏ qua IP không nối được. Phải khai báo cờ này rõ ràng — **bỏ qua
im lặng nghĩa là ổ của máy đó biến mất mà không ai biết**. Dùng khi đã xác minh máy thật sự
chưa đăng ký, không phải để né một IP chưa tra ra.

**`host_to_disks.py` — dựng hai thứ:**

- `<file nhập>.csv` — mỗi ổ một dòng, dựng thành **linh kiện** gắn vào máy chứa qua
  `parent_reference`. Ổ đi cùng site/rack với máy nhưng **không có `rack_unit`**: ổ nằm
  trong máy chứ không chiếm ô U của rack. Nhập bằng `POST /api/import/assets`.
- `<file nhập>.csv.updates.json` — phần **bồi thêm** cho máy đã có sẵn (IP, cấu hình, serial).
  Gửi bằng `PUT /api/assets/<mã>`; `asset_changes()` chỉ dựng cột từ khóa có trong payload nên
  đây là cập nhật từng phần, **không tạo lại và không xóa trắng trường khác**.

Quy ước mã ổ: `<phương tiện>-<dung lượng>-<số thứ tự 3 chữ số>`. **Phương tiện phải phân biệt**
— HDD là đĩa quay, SSD là bộ nhớ, RAID là volume logic do card dựng chứ không phải ổ vật lý;
gọi chung `ssd-` là ghi sai bản chất thiết bị. Vì vậy `DISK_KINDS` khóa theo **cặp (phương
tiện, dung lượng)**, và parser bắt cả tiền tố `SSD(` / `HDD(` / `RAID(`:

| tiền tố | dùng cho | ví dụ |
|---|---|---|
| `ssd-240` `ssd-480` `ssd-960` | SSD 240.06 / 480.10 / 960.20GB | `ssd-240-091` |
| `ssd-2tb` `ssd-8tb` | SSD 1.9TB / 7.7TB (làm tròn danh nghĩa) | `ssd-2tb-268` |
| `hdd-4tb` | HDD 4.0TB — đĩa quay, khác tốc độ/tuổi thọ/giá thay thế | `hdd-4tb-028` |
| `raid-240` `raid-480` `raid-960` | volume RAID 239 / 479 / 999GB | `raid-240-004` |

Volume RAID ghi `asset_type = disk` (danh mục chưa có loại "volume", **không tự thêm loại mới**)
nhưng tiền tố `raid-` + nhãn "Volume RAID 239.00GB" nói rõ đây không phải ổ vật lý. Một volume
239GB thường là RAID-1 của 2 ổ 240GB, nên **số bản ghi `raid-*` không phải số ổ vật lý**.

Số thứ tự **chạy tiếp theo kho ổ đang có** (tham số thứ 4), không đánh lại từ 001 cho mỗi tủ:
mã ổ không mang thông tin vị trí nên ổ rút ra cắm sang máy khác vẫn giữ nguyên mã.

**Nhập nhiều tủ thì phải TUẦN TỰ.** Sinh hai file từ cùng một ảnh chụp là hai file đánh trùng
số thứ tự (J5 và J6 từng trùng 57 mã) — nhập chồng lên nhau sẽ gán ổ sang máy khác. Đúng thứ
tự: sinh → nhập → **chụp lại danh sách asset** → sinh file kế. Xem trước lúc nhập phải luôn
báo `ghi đè 0`; khác 0 là dấu hiệu trùng mã, dừng lại.

Dung lượng chưa có trong `DISK_KINDS` thì script **báo ra `vấn đề`** chứ không tự chế tiền tố.

CPU + RAM ghép vào cột `capacity` (Dung lượng / cấu hình), số license vào cột `serial`.

### Tủ BD51: không có IP ở bất kỳ nguồn nào

`192.168.201.1–6` không xuất hiện trong database, sổ Excel gốc lẫn NetBox, và 6 bản ghi
`MatBao-CA Node 01–06` giống hệt nhau (cùng "Supermicro Node 2U", không IP/serial/ngày) nên
**không có gì để nối bằng dữ liệu**. Ánh xạ là do người quản trị xác nhận: Node 1-2-3 nằm giữa
tủ (U13/16/19), 4-5-6 nằm trên (U39/37/35), IP theo số node — `192.168.201.N` -> `Node 0N`.

Hai mảnh khớp chéo xác nhận: serial của `.1/.2/.3` mang tiền tố **SGH của HP**, và Node 1-2-3
đúng là máy HP. NetBox ghi cả 6 máy là "Supermicro Node 2U" — **sai với Node 01-03**; `description`
của ba máy đó đã sửa thành `HP Node 2U`. Phần "Node 2U" vẫn là Type chung chung của NetBox,
chưa phải model HP thật.

Bài học chung: khi bản xuất không nối được về mã tài sản bằng bằng chứng, **dừng và hỏi**.
Đoán sai ở đây không giống đoán sai vị trí ổ — nó ghi serial của máy này sang khung máy khác.

### Nguồn là khối chữ gõ tay, không phải file xuất

`scripts/text_to_disks.py <khối>.txt <ảnh chụp asset>.csv <file nhập>.csv` — mỗi máy một khối
ngăn bằng dòng trống, **mã tài sản cho sẵn** nên không phải nối IP:

```
odsvps02 svr-d12-u31
10.10.70.12
Intel(R) Xeon(R) CPU E5-2620 v4 @ 2.10GHz
RAM 251.8 GiB · SSD 4×1.92 TB + SSD 2×960.20 GB + HDD 6×4.00 TB
```

IP và CPU/RAM có thể vắng (3 máy `control0N` của D12 chỉ có ổ) — vắng thì **không bồi trường
đó**, không điền giá trị thay thế. Script `import` DISK_KINDS từ `host_to_disks.py` nên tiền
tố mã ổ chỉ có MỘT chỗ quyết định; vì vậy `host_to_disks.py` để hằng số ở mức module và bọc
phần chạy trong `main()` — đừng đưa code thực thi ra ngoài `if __name__ == "__main__"`.

**Gộp cách ghi dung lượng.** Hai công cụ ghi cùng một loại ổ hai kiểu: `1.9TB` / `1.92 TB`,
`4.0TB` / `4.00 TB`, `240GB` / `240.06GB`. `SIZE_ALIAS` gộp về **cách ghi đang có trong
database** để danh mục không có hai tên cho một loại ổ. Gộp chỉ áp cho cách ghi khác nhau của
cùng một ổ — không gộp hai dung lượng thật sự khác nhau.

### Ổ bỏ qua có chủ ý — `IGNORED_DISKS`

Bản xuất khai `HDD(1*8.05GB)` trên máy HP của BD51: đó là **thẻ khởi động** (microSD / USB DOM)
chứ không phải ổ dữ liệu, ghi vào danh mục ổ là làm sai số đếm. `IGNORED_DISKS` liệt kê những
cặp (phương tiện, dung lượng) như vậy; script **bỏ qua nhưng vẫn in ra** mục "bỏ qua có chủ ý"
— khác hẳn với việc lặng lẽ nuốt mất. Đừng xử lý bằng cách xóa khỏi `DISK_KINDS`: làm thế thì
nó rơi vào `vấn đề` như một dung lượng lạ, lẫn với ổ thật sự chưa biết đặt mã.

### Serial mẫu của nhà máy

Bản xuất hay ghi `0123456789` ở ô Server License — cùng một chuỗi trên nhiều máy thì đó là
số mẫu chưa điền, không phải serial thật (tủ AQ53/AQ54 có 4 máy như vậy). Script để **trống**
`serial` cho những máy đó và liệt kê ra, đúng quy tắc *hiện chỗ thiếu, không lấp bằng giá trị
đoán*. Danh sách chuỗi mẫu nằm ở hằng `PLACEHOLDER_SERIALS`.

## Sinh cáp theo quy tắc rack

`scripts/rack_cables.py <ảnh chụp asset>.csv <file nhập>.csv` — quy tắc đấu nối do người
quản trị đặt:

- rack có **đúng 2** switch storage -> mỗi switch **1 sợi 10Gbps + 1 sợi 20Gbps**
- cùng rack đó -> **mỗi server thêm 2 sợi 10Gbps**

Cáp là **linh kiện** gắn vào thiết bị qua `parent_reference`, cùng site/rack nhưng **không
chiếm ô U** — giống ổ cứng. Cáp của server gắn vào **chính server** (không gắn vào switch):
server chuyển đi thì cáp theo cùng, và sơ đồ cho thấy ngay máy nào có mấy sợi. Mã theo khuôn
quen thuộc: `cab-10g-001`, `cab-20g-001`.

Rack có 0 hoặc 1 switch storage thì **không đụng tới**, và script in ra vì sao — im lặng bỏ
qua thì không ai biết rack nào chưa được áp quy tắc.

### Nhận diện switch storage

Script dò bằng **tên** (`asset_type = switch` và tên chứa "storage") vì database **không lưu
Role của NetBox**. Hai nguồn lệch nhau đúng một chỗ: `sw-j3-u40` tên "Sw access" nhưng NetBox
xếp Role `Layer2 Storage`. **Đã xác minh: NetBox sai, tên đúng** — máy này là
`Cisco WS-C2970G-24TS-E` (Catalyst 2970G, switch access 24 cổng Gigabit), không phải Nexus
C3064 như mọi switch storage khác trong hệ thống. J3 có **0** switch storage, không áp quy tắc
cáp. Rack khác hai nguồn khớp hoàn toàn.

Bài học: **Role của NetBox không đáng tin hơn tên** — đối chiếu thêm model thiết bị khi hai
nguồn cãi nhau.

## Cột `serial`

`asset.serial` giữ **số serial / license** của thiết bị. Có mặt trong `ASSET_COLUMNS` nên
đi cả đường nhập lẫn xuất, có trong `ASSET_DIFF_FIELDS` nên xem trước lúc nhập thấy được
thay đổi, nhưng **không nằm trong `BULK_FIELDS`**: serial là của riêng từng máy, sửa hàng
loạt là sai. Trên giao diện là ô "Số serial / license", đặt sau ngày hết bảo hành.

## Bảng Vị trí & Cụm: một nút Edit

Ba nút Xem / Sửa / Xóa gộp thành **một nút ✎** rộng 40px. Bấm vào mở hộp thoại có đủ ba việc:
khối chi tiết (cấp, thuộc, số tài sản, đang vận hành, cần chú ý + lối xem tài sản của site),
form sửa, và nút Xóa. `openModal` nhận tham số thứ 7 `extras = { details, danger, onDanger,
onLink }` để dựng khối chi tiết và nút phụ — dùng lại được cho bảng khác.

## Tài khoản & bí mật

Tài khoản đăng nhập nằm trong bảng `app_user` của Postgres, mật khẩu băm bằng scrypt.
**Không bao giờ** đặt tài khoản/mật khẩu vào `index.html`, tài liệu hay `docker-compose.yml`.
Tài khoản quản trị đầu tiên do `docker compose run --rm seed` tạo từ `ADMIN_USERNAME` /
`ADMIN_PASSWORD` trong `.env` (đã gitignore); bỏ trống `ADMIN_PASSWORD` thì hệ thống sinh
ngẫu nhiên và in ra đúng một lần.

## Đang thiếu

Chưa có git repo, test, CI, auth cho API. Xem `docs/PLAN.md`.
