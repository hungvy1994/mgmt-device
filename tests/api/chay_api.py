#!/usr/bin/env python3
"""Kiểm tầng API bằng HTTP THẬT, chạy trong chính ảnh production.

Không thêm phụ thuộc nào: uvicorn (đã có trong ảnh) chạy nền trong một luồng, còn phía gọi
dùng urllib của thư viện chuẩn. Nhờ vậy bộ kiểm đi qua đúng tầng mà người dùng đi qua —
cookie phiên, multipart, mã trạng thái HTTP — chứ không gọi tắt vào hàm Python.

Dữ liệu nằm ở MỘT DATABASE RIÊNG dựng lúc chạy rồi xoá ngay sau đó; không bao giờ đụng
database thật. Xem cách chạy ở scripts/kiem_thu_api.sh
"""
from __future__ import annotations

import json
import os
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONG = int(os.environ.get("TEST_PORT", "8765"))
GOC = f"http://127.0.0.1:{CONG}"

bao_cao: list[str] = []
DA_GOI: list[tuple[str, str]] = []   # mọi lệnh đã gọi, để tự chứng minh độ phủ
_nhom = ""


def nhom(ten: str) -> None:
    global _nhom
    _nhom = ten
    bao_cao.append(f"\n--- {ten} ---")


def check(nhan: str, dat: bool, them: str = "") -> None:
    bao_cao.append(f"{'PASS' if dat else 'FAIL'}  {nhan}{' — ' + str(them)[:120] if them else ''}")


# ----------------------------------------------------------------- dựng database sạch
def dung_database() -> str:
    import psycopg

    that = os.environ["DATABASE_URL"]
    ten_thu = os.environ.get("TEST_DB", "thu_api")
    goc = that.rsplit("/", 1)[0]
    with psycopg.connect(f"{goc}/postgres", autocommit=True) as conn:
        conn.execute(
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s", (ten_thu,)
        )
        conn.execute(f'DROP DATABASE IF EXISTS "{ten_thu}"')
        conn.execute(f'CREATE DATABASE "{ten_thu}"')
    dsn = f"{goc}/{ten_thu}"
    # Lược đồ gốc do docker-entrypoint nạp khi container db dựng lần đầu; database mới thì
    # phải tự nạp, không thì startup của app chỉ vá thêm lên hư không.
    schema = Path(os.environ.get("SCHEMA_SQL", "/srv/schema.sql")).read_text()
    with psycopg.connect(dsn, autocommit=True) as conn:
        conn.execute(schema)
    return dsn


def xoa_database() -> None:
    import psycopg

    that = os.environ["DATABASE_URL"]
    ten_thu = os.environ.get("TEST_DB", "thu_api")
    goc = that.rsplit("/", 1)[0]
    try:
        with psycopg.connect(f"{goc}/postgres", autocommit=True) as conn:
            conn.execute(
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s",
                (ten_thu,),
            )
            conn.execute(f'DROP DATABASE IF EXISTS "{ten_thu}"')
    except Exception as loi:  # pragma: no cover
        print(f"(không xoá được database thử: {loi})", file=sys.stderr)


# ----------------------------------------------------------------- gọi HTTP
def multipart(form: dict, files: dict) -> tuple[bytes, str]:
    bien = "----mgmtdevice" + secrets.token_hex(8)
    ra = b""
    for k, v in form.items():
        ra += f'--{bien}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    for k, (ten, noi_dung) in files.items():
        ra += (
            f'--{bien}\r\nContent-Disposition: form-data; name="{k}"; filename="{ten}"\r\n'
            f"Content-Type: application/octet-stream\r\n\r\n"
        ).encode() + noi_dung + b"\r\n"
    ra += f"--{bien}--\r\n".encode()
    return ra, f"multipart/form-data; boundary={bien}"


def goi(method: str, path: str, *, body=None, form=None, files=None, cookie: str = ""):
    """-> (mã HTTP, nội dung đã giải mã, headers). Không ném lỗi khi máy chủ trả 4xx/5xx."""
    data = ctype = None
    if body is not None:
        data, ctype = json.dumps(body).encode(), "application/json"
    elif form is not None or files is not None:
        data, ctype = multipart(form or {}, files or {})
    DA_GOI.append((method, path.split("?")[0]))
    req = urllib.request.Request(GOC + path, data=data, method=method)
    if ctype:
        req.add_header("Content-Type", ctype)
    if cookie:
        req.add_header("Cookie", cookie)

    def doc(r):
        raw = r.read()
        kieu = r.headers.get("Content-Type", "")
        if "json" in kieu:
            try:
                return json.loads(raw)
            except ValueError:
                return raw
        return raw

    try:
        with urllib.request.urlopen(req) as r:
            return r.status, doc(r), r.headers
    except urllib.error.HTTPError as e:
        return e.code, doc(e), e.headers


def dang_nhap(ten: str, mat_khau: str) -> str:
    ma, _, headers = goi("POST", "/api/login", body={"username": ten, "password": mat_khau})
    if ma != 200:
        return ""
    dat = headers.get("Set-Cookie", "")
    return dat.split(";", 1)[0] if dat else ""


# ----------------------------------------------------------------- ma trận phân quyền
# (method, đường dẫn, vai tối thiểu). Đường dẫn có tham số dùng giá trị bừa vì dependency
# chặn TRƯỚC khi vào thân hàm — đúng ra phải thế, và đây chính là điều cần kiểm.
ENDPOINT_GHI = [
    ("POST", "/api/assets", "ghi"),
    ("PUT", "/api/assets/khong-co", "ghi"),
    ("DELETE", "/api/assets/khong-co", "ghi"),
    ("POST", "/api/events", "ghi"),
    ("PUT", "/api/events/1", "ghi"),
    ("DELETE", "/api/events/1", "ghi"),
    ("POST", "/api/statuses", "ghi"),
    ("PUT", "/api/statuses/khong-co", "ghi"),
    ("DELETE", "/api/statuses/khong-co", "ghi"),
    ("POST", "/api/asset-types", "ghi"),
    ("PUT", "/api/asset-types/khong-co", "ghi"),
    ("DELETE", "/api/asset-types/khong-co", "ghi"),
    ("POST", "/api/clusters", "ghi"),
    ("PUT", "/api/clusters/khong-co", "ghi"),
    ("DELETE", "/api/clusters/khong-co", "ghi"),
    ("POST", "/api/locations", "ghi"),
    ("PUT", "/api/locations/site-1", "ghi"),
    ("DELETE", "/api/locations/site-1", "ghi"),
    ("POST", "/api/import/assets", "ghi"),
    ("POST", "/api/import/history", "ghi"),
    ("POST", "/api/import/preview", "ghi"),
    ("POST", "/api/assets/bulk-update", "ghi"),
    ("POST", "/api/assets/bulk-delete", "ghi"),
    ("POST", "/api/assets/transfer", "ghi"),
    ("POST", "/api/export-templates", "ghi"),
    ("PUT", "/api/export-templates/1", "ghi"),
    ("DELETE", "/api/export-templates/1", "ghi"),
    ("POST", "/api/users", "admin"),
    ("PUT", "/api/users/1", "admin"),
    ("DELETE", "/api/users/1", "admin"),
    ("PUT", "/api/backup", "admin"),
    ("POST", "/api/backup/run", "admin"),
    ("POST", "/api/data/wipe", "admin"),
]


def _tham_so(path: str) -> dict:
    """Body hợp lệ về mặt hình thức, để 401/403 là lý do DUY NHẤT khiến lệnh bị chặn."""
    if path.startswith("/api/import/"):
        form = {"kind": "assets"} if path.endswith("preview") else {"skip": "[]"}
        return {"form": form, "files": {"file": ("thu.csv", b"asset_id\n")}}
    return {"body": {}}


def kiem_phan_quyen(ck: dict) -> None:
    nhom(f"Phân quyền — {len(ENDPOINT_GHI)} endpoint ghi")
    hong_401, hong_403, hong_admin = [], [], []
    for method, path, vai in ENDPOINT_GHI:
        ts = _tham_so(path)
        ma, _, _ = goi(method, path, **ts)
        if ma != 401:
            hong_401.append(f"{method} {path} -> {ma}")
        ma, _, _ = goi(method, path, cookie=ck["xem"], **ts)
        if ma != 403:
            hong_403.append(f"{method} {path} -> {ma}")
        if vai == "admin":
            ma, _, _ = goi(method, path, cookie=ck["sua"], **ts)
            if ma != 403:
                hong_admin.append(f"{method} {path} -> {ma}")
    check("chưa đăng nhập thì MỌI endpoint ghi trả 401", not hong_401, "; ".join(hong_401))
    check("vai chỉ-xem bị chặn ở MỌI endpoint ghi (403)", not hong_403, "; ".join(hong_403))
    check("vai sửa-dữ-liệu không đụng được việc của quản trị (403)", not hong_admin,
          "; ".join(hong_admin))


def kiem_dang_nhap(ck: dict) -> None:
    nhom("Đăng nhập và phiên làm việc")
    ma, noi, _ = goi("POST", "/api/login", body={"username": "admin", "password": "sai-be-bet"})
    check("mật khẩu sai trả 401", ma == 401, ma)
    check("báo lỗi KHÔNG tiết lộ tài khoản có tồn tại hay không",
          isinstance(noi, dict) and "không đúng" in str(noi.get("detail", "")), noi)
    ma, _, _ = goi("POST", "/api/login", body={"username": "khong-ton-tai", "password": "x"})
    check("tài khoản không có cũng trả 401 y hệt", ma == 401, ma)

    ma, noi, headers = goi("POST", "/api/login", body={"username": "admin", "password": MK_ADMIN})
    check("đăng nhập đúng trả 200", ma == 200, ma)
    dat = headers.get("Set-Cookie", "")
    check("cookie phiên đặt HttpOnly", "HttpOnly" in dat, dat[:90])
    check("cookie phiên đặt SameSite", "SameSite" in dat, dat[:90])
    check("cookie mang tên mới mgmt_device_session", "mgmt_device_session" in dat, dat[:60])

    ma, noi, _ = goi("GET", "/api/me", cookie=ck["admin"])
    check("/api/me trả đúng tài khoản đang đăng nhập",
          ma == 200 and noi.get("username") == "admin", noi)
    check("/api/me KHÔNG trả mật khẩu băm",
          isinstance(noi, dict) and not any("password" in k for k in noi), list(noi))

    ma, _, _ = goi("GET", "/api/me", cookie="mgmt_device_session=token-bia-dat")
    check("token bịa đặt bị từ chối", ma == 401, ma)

    # đăng xuất phải huỷ phiên thật, không chỉ xoá cookie phía trình duyệt
    rieng = dang_nhap("admin", MK_ADMIN)
    goi("POST", "/api/logout", cookie=rieng)
    ma, _, _ = goi("GET", "/api/me", cookie=rieng)
    check("đăng xuất huỷ phiên ở phía máy chủ", ma == 401, ma)


def kiem_tai_khoan(ck: dict) -> None:
    nhom("Tài khoản — hai lớp chặn tự nhốt mình ra ngoài")
    a = ck["admin"]
    ma, noi, _ = goi("POST", "/api/users", cookie=a,
                     body={"username": "moi1", "password": "mat-khau-dai", "role": "sua"})
    check("tạo tài khoản mới trả 201", ma == 201, noi)
    moi_id = (noi or {}).get("user", {}).get("id")

    ma, noi, _ = goi("POST", "/api/users", cookie=a,
                     body={"username": "moi1", "password": "mat-khau-dai", "role": "sua"})
    check("trùng tên đăng nhập trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/users", cookie=a,
                     body={"username": "ngan", "password": "123", "role": "xem"})
    check("mật khẩu dưới 8 ký tự bị chặn (400)", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/users", cookie=a,
                     body={"username": "vai-la", "password": "mat-khau-dai", "role": "sep-tong"})
    check("vai ngoài danh mục bị chặn (400)", ma == 400, noi)

    ma, noi, _ = goi("GET", "/api/users", cookie=a)
    dsach = (noi or {}).get("users", [])
    check("danh sách tài khoản KHÔNG lộ mật khẩu băm",
          dsach and not any("password" in k for u in dsach for k in u), list(dsach[0]) if dsach else "")

    # quản trị viên cuối cùng: không hạ vai, không khoá, không tự xoá
    ma_admin = [u for u in dsach if u["role"] == "admin"]
    check("đang chỉ còn một quản trị viên", len(ma_admin) == 1, len(ma_admin))
    id_admin = ma_admin[0]["id"]
    ma, noi, _ = goi("PUT", f"/api/users/{id_admin}", cookie=a, body={"role": "xem"})
    check("không hạ vai quản trị viên cuối cùng (409)", ma == 409, noi)
    ma, noi, _ = goi("PUT", f"/api/users/{id_admin}", cookie=a, body={"isActive": False})
    check("không khoá quản trị viên cuối cùng (409)", ma == 409, noi)
    ma, noi, _ = goi("DELETE", f"/api/users/{id_admin}", cookie=a)
    check("không tự xoá tài khoản đang đăng nhập (409)", ma == 409, noi)

    ma, _, _ = goi("PUT", f"/api/users/{moi_id}", cookie=a, body={"password": "mat-khau-moi-dai"})
    check("đổi mật khẩu người khác được (200)", ma == 200, ma)
    check("mật khẩu mới dùng đăng nhập được", bool(dang_nhap("moi1", "mat-khau-moi-dai")))
    ma, _, _ = goi("DELETE", f"/api/users/{moi_id}", cookie=a)
    check("xoá được tài khoản khác (200)", ma == 200, ma)
    ma, _, _ = goi("PUT", "/api/users/999999", cookie=a, body={"role": "xem"})
    check("sửa tài khoản không có trả 404", ma == 404, ma)


def kiem_danh_muc(ck: dict) -> None:
    nhom("Danh mục dùng chung — trạng thái, loại tài sản, cụm")
    a = ck["admin"]
    ma, noi, _ = goi("POST", "/api/statuses", cookie=a, body={"code": "thu_tt", "label": "Thử"})
    check("tạo trạng thái trả 201", ma == 201, noi)
    ma, noi, _ = goi("POST", "/api/statuses", cookie=a, body={"code": "thu_tt", "label": "Thử"})
    check("trạng thái trùng mã trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/statuses", cookie=a, body={"code": "", "label": ""})
    check("trạng thái thiếu mã/tên trả 400", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/statuses", cookie=a,
                     body={"code": "kieu_la", "label": "X", "cls": "mau-tim-than-thanh"})
    check("kiểu hiển thị lạ bị chặn (400)", ma == 400, noi)
    ma, _, _ = goi("DELETE", "/api/statuses/thu_tt", cookie=a)
    check("xoá được trạng thái chưa ai dùng", ma == 200, ma)

    ma, noi, _ = goi("POST", "/api/asset-types", cookie=a, body={"code": "thu_loai", "label": "Thử"})
    check("tạo loại tài sản trả 201", ma == 201, noi)
    ma, noi, _ = goi("POST", "/api/asset-types", cookie=a, body={"code": "Loại Lạ!", "label": "X"})
    check("mã loại sai định dạng bị chặn (400)", ma == 400, noi)
    ma, noi, _ = goi("PUT", "/api/asset-types/thu_loai", cookie=a,
                     body={"code": "thu_loai2", "label": "Thử 2"})
    check("đổi mã loại được (200)", ma == 200, noi)
    ma, _, _ = goi("DELETE", "/api/asset-types/thu_loai2", cookie=a)
    check("xoá được loại chưa có tài sản", ma == 200, ma)

    ma, noi, _ = goi("POST", "/api/clusters", cookie=a, body={"name": "CumThu"})
    check("tạo cụm trả 201", ma == 201, noi)
    ma, noi, _ = goi("POST", "/api/clusters", cookie=a, body={"name": "CumThu"})
    check("cụm trùng tên trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/clusters", cookie=a, body={"name": "  "})
    check("cụm thiếu tên trả 400", ma == 400, noi)
    ma, _, _ = goi("PUT", "/api/clusters/CumThu", cookie=a, body={"name": "CumThu2"})
    check("đổi tên cụm được (200)", ma == 200, ma)
    ma, _, _ = goi("DELETE", "/api/clusters/CumThu2", cookie=a)
    check("xoá được cụm chưa có tài sản", ma == 200, ma)
    ma, _, _ = goi("DELETE", "/api/clusters/khong-bao-gio-co", cookie=a)
    check("xoá cụm không có trả 404", ma == 404, ma)


def kiem_vi_tri(ck: dict) -> dict:
    nhom("Vị trí ba cấp — Site / Phòng máy / Rack")
    a = ck["admin"]
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "location", "site": "SiteThu"})
    check("tạo site trả 201", ma == 201, noi)
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "room", "site": "SiteThu", "room": "P1", "name": "Phòng 1"})
    check("tạo phòng máy thuộc site trả 201", ma == 201, noi)
    phong = (noi or {}).get("id", "")
    so_phong = phong.split("-")[-1]
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "room", "site": "Site-Khong-Co", "room": "P9", "name": "X"})
    check("phòng máy thuộc site không có trả 400", ma == 400, noi)

    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "rack", "site": "SiteThu", "roomId": so_phong,
                           "rack": "R01", "heightU": 42})
    check("tạo rack trả 201", ma == 201, noi)
    rack = (noi or {}).get("id", "")          # lấy id NGAY, trước khi `noi` bị lệnh sau ghi đè
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "rack", "site": "SiteThu", "roomId": "room-1", "rack": "R09"})
    check("mã phòng máy đọc không ra thì BÁO LỖI, không lặng lẽ xếp vào phòng ngầm định",
          ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "rack", "site": "SiteThu", "roomId": so_phong, "rack": "R01"})
    check("rack trùng mã trong cùng phòng trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "rack", "site": "SiteThu", "roomId": so_phong,
                           "rack": "R02", "heightU": "bốn hai"})
    check("chiều cao U không phải số trả 400", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/locations", cookie=a,
                     body={"kind": "rack", "site": "SiteThu", "roomId": so_phong, "rack": ""})
    check("rack thiếu mã trả 400", ma == 400, noi)
    return {"site": "SiteThu", "phong": phong, "rack": rack}


def kiem_tai_san(ck: dict, vt: dict) -> dict:
    nhom("Tài sản — mã, ô U, ràng buộc rack/site")
    a = ck["admin"]
    so_rack = vt["rack"].split("-")[-1]

    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-001", "asset_name": "Máy thử 1",
                           "asset_type": "server", "datacenter": vt["site"],
                           "rack_id": so_rack, "rack_unit": 10})
    check("tạo tài sản trả 201", ma == 201, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-001", "asset_name": "Trùng mã"})
    check("trùng mã tài sản trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a, body={"asset_name": ""})
    check("thiếu tên tài sản trả 400", ma == 400, noi)

    # để trống mã -> cấp mã tạm, KHÔNG phải lỗi
    ma, noi, _ = goi("POST", "/api/assets", cookie=a, body={"asset_name": "Chưa biết mã"})
    tam = (noi or {}).get("asset", {}).get("asset_id", "")
    check("để trống mã thì được cấp mã tạm CHUA-GAN", ma == 201 and tam.startswith("CHUA-GAN"), tam)
    check("tài sản mã tạm bật cờ code_pending",
          bool((noi or {}).get("asset", {}).get("code_pending")), noi)

    # ô U: trùng chỗ, ngoài khoảng, có U mà chưa chọn rack
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-002", "asset_name": "Máy thử 2",
                           "datacenter": vt["site"], "rack_id": so_rack, "rack_unit": 10})
    check("hai thiết bị cùng một ô U trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-003", "asset_name": "Máy thử 3",
                           "datacenter": vt["site"], "rack_id": so_rack, "rack_unit": 999})
    check("ô U vượt chiều cao rack bị chặn", ma in (400, 409), noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-004", "asset_name": "Máy thử 4", "rack_unit": 5})
    check("có ô U mà chưa chọn rack bị chặn", ma in (400, 409), noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-005", "asset_name": "Máy thử 5",
                           "asset_type": "loai-khong-co-that"})
    check("loại tài sản ngoài danh mục trả 400", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-006", "asset_name": "Máy thử 6",
                           "usage_status": "trang-thai-bia"})
    check("trạng thái ngoài danh mục trả 400", ma == 400, noi)

    # số U chiếm: máy 2U ở U10 chiếm cả U11 -> kiểm theo DẢI U, không chỉ U bắt đầu
    ma, noi, _ = goi("PUT", "/api/assets/thu-001", cookie=a, body={"rack_size_u": 2})
    check("khai số U chiếm trả 200", ma == 200 and str((noi or {}).get("asset", {}).get("rack_size_u")) == "2", noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-u11", "asset_name": "Đè lên U11",
                           "datacenter": vt["site"], "rack_id": so_rack, "rack_unit": 11})
    check("đặt vào U thứ hai của máy 2U trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-u09", "asset_name": "Máy 2U ở U9",
                           "datacenter": vt["site"], "rack_id": so_rack, "rack_unit": 9, "rack_size_u": 2})
    check("máy 2U ở U9 chồng lên U10 trả 409", ma == 409, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-u41", "asset_name": "Máy 3U ở U41",
                           "datacenter": vt["site"], "rack_id": so_rack, "rack_unit": 41, "rack_size_u": 3})
    check("dải U vượt chiều cao rack trả 400", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "thu-u12", "asset_name": "Máy 2U ở U12",
                           "datacenter": vt["site"], "rack_id": so_rack, "rack_unit": 12, "rack_size_u": 2})
    check("máy 2U sát ngay trên dải U12-13 vẫn đặt được", ma == 201, noi)
    ma, noi, _ = goi("PUT", "/api/assets/thu-u12", cookie=a, body={"rack_size_u": 0})
    check("số U chiếm bằng 0 trả 400", ma == 400, noi)
    ma, noi, _ = goi("PUT", "/api/assets/thu-u12", cookie=a, body={"in_store": "1"})
    check("vào kho thì bỏ vị trí U nhưng giữ số U chiếm",
          ma == 200 and str((noi or {}).get("asset", {}).get("rack_size_u")) == "2"
          and not (noi or {}).get("asset", {}).get("rack_unit"), noi)
    goi("DELETE", "/api/assets/thu-u12", cookie=a)

    # ISO: mặc định chưa xác nhận, admin xác nhận xong đổi được qua lại.
    ma, noi, _ = goi("PUT", "/api/assets/thu-001", cookie=a, body={"iso_confirmed": "1"})
    check("xác nhận ISO trả 200", ma == 200 and (noi or {}).get("asset", {}).get("iso_confirmed") == "1", noi)
    ma, noi, _ = goi("PUT", "/api/assets/thu-001", cookie=a, body={"iso_confirmed": ""})
    check("bỏ xác nhận ISO trả 200", ma == 200 and not (noi or {}).get("asset", {}).get("iso_confirmed"), noi)

    # sửa từng phần: gửi một trường thì các trường khác KHÔNG bị xoá trắng
    goi("PUT", "/api/assets/thu-001", cookie=a, body={"serial": "SN-123"})
    ma, noi, _ = goi("PUT", "/api/assets/thu-001", cookie=a, body={"capacity": "64GB"})
    check("sửa từng phần không xoá trắng trường khác",
          ma == 200 and (noi or {}).get("asset", {}).get("serial") == "SN-123", noi)

    # đổi mã của thiết bị đang đứng trong rack (bug cũ: tự thấy chính mình rồi trả 409)
    ma, noi, _ = goi("PUT", "/api/assets/thu-001", cookie=a, body={"asset_id": "thu-001b"})
    check("đổi mã thiết bị đang chiếm ô U vẫn được (không tự đụng chính mình)", ma == 200, noi)

    ma, noi, _ = goi("PUT", "/api/assets/khong-co-that", cookie=a, body={"asset_name": "X"})
    check("sửa tài sản không có trả 404", ma == 404, noi)
    ma, _, _ = goi("DELETE", "/api/assets/khong-co-that", cookie=a)
    check("xoá tài sản không có trả 404", ma == 404, ma)
    return {"ma": "thu-001b", "tam": tam, "rack": so_rack}


def kiem_su_kien(ck: dict, ts: dict) -> None:
    nhom("Sự kiện vòng đời")
    a = ck["admin"]
    ma, noi, _ = goi("POST", "/api/events", cookie=a,
                     body={"asset_id": ts["ma"], "event_type": "transfer",
                           "event_date": "2026-01-15", "location": "Kho"})
    check("tạo sự kiện trả 201", ma == 201, noi)
    sk = (noi or {}).get("event", {}).get("event_id")
    ma, noi, _ = goi("POST", "/api/events", cookie=a, body={"event_type": "transfer"})
    check("sự kiện thiếu mã tài sản trả 400", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/events", cookie=a,
                     body={"asset_id": "khong-co-that", "event_type": "x"})
    check("sự kiện gắn vào tài sản không có bị chặn", ma in (400, 404, 409), noi)
    ma, noi, _ = goi("POST", "/api/events", cookie=a,
                     body={"asset_id": ts["ma"], "event_date": "35/13/2026"})
    check("ngày sai định dạng trả 400", ma == 400, noi)
    ma, _, _ = goi("PUT", f"/api/events/{sk}", cookie=a, body={"notes": "sửa lại"})
    check("sửa sự kiện được (200)", ma == 200, ma)
    ma, _, _ = goi("DELETE", f"/api/events/{sk}", cookie=a)
    check("xoá sự kiện được (200)", ma == 200, ma)
    ma, _, _ = goi("DELETE", "/api/events/999999", cookie=a)
    check("xoá sự kiện không có trả 404", ma == 404, ma)


def kiem_rang_buoc_xoa(ck: dict, vt: dict, ts: dict) -> None:
    nhom("Xoá phải từ dưới lên — còn con thì không xoá được")
    a = ck["admin"]
    ma, noi, _ = goi("DELETE", f"/api/locations/{vt['rack']}", cookie=a)
    check("rack còn tài sản thì không xoá được (409)", ma == 409, noi)
    ma, noi, _ = goi("DELETE", f"/api/locations/{vt['phong']}", cookie=a)
    check("phòng máy còn rack thì không xoá được (409)", ma == 409, noi)
    ma, noi, _ = goi("DELETE", "/api/locations/site-999999", cookie=a)
    check("xoá vị trí không có trả 404", ma == 404, noi)
    ma, noi, _ = goi("DELETE", "/api/locations/khong-dung-dinh-dang", cookie=a)
    check("mã vị trí sai định dạng bị chặn", ma in (400, 404), noi)

    # loại và trạng thái đang có tài sản dùng thì cũng không xoá được
    ma, noi, _ = goi("DELETE", "/api/asset-types/server", cookie=a)
    check("loại tài sản còn tài sản thì không xoá được (409)", ma == 409, noi)


def kiem_hang_loat(ck: dict, vt: dict) -> None:
    nhom("Sửa / xoá hàng loạt và luân chuyển")
    a = ck["admin"]
    for i in (11, 12, 13):
        goi("POST", "/api/assets", cookie=a,
            body={"asset_id": f"lo-{i}", "asset_name": f"Lô {i}", "asset_type": "server"})
    # linh kiện lắp trong lo-11, để kiểm luân chuyển có kéo theo không
    goi("POST", "/api/assets", cookie=a,
        body={"asset_id": "lo-11-o", "asset_name": "Ổ trong lô 11", "asset_type": "disk",
              "parent_reference": "lo-11"})

    goi("POST", "/api/clusters", cookie=a, body={"name": "CumLo"})
    ma, noi, _ = goi("POST", "/api/assets/bulk-update", cookie=a, body={"ids": []})
    check("sửa hàng loạt mà chưa chọn gì trả 400", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/assets/bulk-update", cookie=a,
                     body={"ids": ["lo-11", "lo-12"], "changes": {"cluster": "CumLo"}})
    check("sửa hàng loạt được (200)", ma == 200, noi)
    ma, noi, _ = goi("POST", "/api/assets/bulk-update", cookie=a,
                     body={"ids": ["lo-11"], "changes": {}})
    check("sửa hàng loạt mà không nêu trường nào trả 400", ma == 400, noi)
    # Hai ca dưới phải chặn vì trường NẰM NGOÀI BULK_FIELDS — gửi kèm một trường hợp lệ để
    # chắc chắn 400 không đến từ việc "chưa chọn trường nào".
    ma, noi, _ = goi("POST", "/api/assets/bulk-update", cookie=a,
                     body={"ids": ["lo-11"], "changes": {"rack_unit": 7}})
    check("ô U KHÔNG cho sửa hàng loạt (mỗi U một thiết bị)", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/assets/bulk-update", cookie=a,
                     body={"ids": ["lo-11"], "changes": {"serial": "SN-CHUNG", "cluster": "CumLo"}})
    check("serial bị bỏ qua khi sửa hàng loạt (của riêng từng máy)", ma == 200, noi)
    ma, noi, _ = goi("GET", "/api/data", cookie=a)
    lo11 = [r for r in (noi or {}).get("assetRows", []) if r.get("asset_id") == "lo-11"]
    check("serial thật sự KHÔNG bị ghi hàng loạt",
          lo11 and not lo11[0].get("serial"), lo11[:1])

    ma, noi, _ = goi("POST", "/api/assets/transfer", cookie=a,
                     body={"ids": ["lo-11"], "datacenter": vt["site"], "event_date": "2026-02-01"})
    check("luân chuyển sang site trả 200", ma == 200, noi)
    check("luân chuyển kéo theo linh kiện lắp bên trong",
          (noi or {}).get("moved", 0) >= 2 or (noi or {}).get("components", 0) >= 1, noi)
    ma, noi, _ = goi("POST", "/api/assets/transfer", cookie=a,
                     body={"ids": ["lo-12"], "in_store": "1"})
    check("chuyển vào kho trả 200", ma == 200, noi)
    ma, noi, _ = goi("GET", "/api/data", cookie=a)
    trong_kho = [r for r in (noi or {}).get("assetRows", []) if r.get("asset_id") == "lo-12"]
    check("vào kho thì bỏ hết site/rack/ô U",
          trong_kho and not trong_kho[0].get("datacenter") and not trong_kho[0].get("rack_unit"),
          trong_kho[:1])
    ma, noi, _ = goi("POST", "/api/assets/transfer", cookie=a,
                     body={"ids": ["lo-13"], "datacenter": "Site-Bia-Dat"})
    check("luân chuyển tới site không có bị chặn", ma in (400, 404), noi)
    ma, noi, _ = goi("POST", "/api/assets/transfer", cookie=a,
                     body={"ids": ["lo-13"], "datacenter": vt["site"], "event_date": "hôm qua"})
    check("ngày luân chuyển sai định dạng trả 400", ma == 400, noi)

    ma, noi, _ = goi("POST", "/api/assets/bulk-delete", cookie=a, body={"ids": ["lo-13"]})
    check("xoá hàng loạt được (200)", ma == 200, noi)


def kiem_nhap_file(ck: dict) -> None:
    nhom("Nhập file — xem trước, ghi thật, bỏ qua, đụng mã")
    a = ck["admin"]
    csv1 = b"asset_id,asset_name,asset_type\nnhap-001,May nhap 1,server\nnhap-002,May nhap 2,server\n"

    ma, noi, _ = goi("POST", "/api/import/preview", cookie=a,
                     form={"kind": "assets"}, files={"file": ("a.csv", csv1)})
    check("xem trước trả 200", ma == 200, noi)
    check("xem trước phân nhóm thêm mới / ghi đè / không đổi",
          all(k in (noi or {}) for k in ("added", "updated", "unchanged")), list(noi or {}))
    check("xem trước thấy đúng 2 bản ghi sẽ thêm", len((noi or {}).get("added", [])) == 2, noi)
    ma, noi2, _ = goi("GET", "/api/data", cookie=a)
    co = [r for r in (noi2 or {}).get("assetRows", []) if r.get("asset_id") == "nhap-001"]
    check("xem trước KHÔNG ghi gì vào database", not co, co)

    ma, noi, _ = goi("POST", "/api/import/assets", cookie=a,
                     form={"skip": "[]"}, files={"file": ("a.csv", csv1)})
    check("nhập thật trả 200", ma == 200, noi)
    check("nhập thật báo đúng số thêm mới", (noi or {}).get("added") == 2, noi)

    ma, noi, _ = goi("POST", "/api/import/assets", cookie=a,
                     form={"skip": json.dumps(["nhap-001"])},
                     files={"file": ("a.csv", csv1.replace(b"May nhap 1", b"Doi ten"))})
    check("bỏ qua từng bản ghi có tác dụng", (noi or {}).get("skipped", 0) >= 1, noi)
    ma, noi, _ = goi("GET", "/api/data", cookie=a)
    giu = [r for r in (noi or {}).get("assetRows", []) if r.get("asset_id") == "nhap-001"]
    check("bản ghi bị bỏ qua giữ nguyên tên cũ",
          giu and giu[0].get("asset_name") == "May nhap 1", giu[:1])

    ma, noi, _ = goi("POST", "/api/import/preview", cookie=a,
                     form={"kind": "assets"}, files={"file": ("a.csv", b"khong,co,cot,dung\n1,2,3,4\n")})
    check("file sai bộ cột bị báo lỗi chứ không nuốt im", ma in (400, 422) or
          (isinstance(noi, dict) and not noi.get("added")), (ma, str(noi)[:80]))

    ma, noi, _ = goi("POST", "/api/import/history", cookie=a, form={"skip": "[]"},
                     files={"file": ("h.csv", b"asset_id,event_sequence,event_type\nnhap-001,1,transfer\n")})
    check("nhập lịch sử trả 200", ma == 200, noi)

    ma, noi, _ = goi("GET", "/api/imports", cookie=a)
    check("mỗi lần nhập để lại một dòng nhật ký", len((noi or {}).get("imports", [])) >= 3, noi)


def kiem_mau_xuat(ck: dict) -> None:
    nhom("Mẫu file xuất cho phòng ban khác")
    a = ck["admin"]
    mau = {"name": "Mẫu thử", "sheet_name": "Thử", "header_rows": 1, "scope": {},
           "maps": {"bang_thu": {"server": "May chu", "*": ""}},
           "col_defs": [{"header1": "Mã", "header2": "", "mau": "$ma_hien_thi", "bang": "", "kieu": "chu"},
                        {"header1": "Loại", "header2": "", "mau": "$asset_type", "bang": "bang_thu", "kieu": "chu"}]}
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=mau)
    check("tạo mẫu xuất trả 201", ma == 201, noi)
    mid = (noi or {}).get("template", {}).get("id")
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=mau)
    check("mẫu trùng tên trả 409", ma == 409, noi)

    xau = dict(mau, name="Mẫu hỏng",
               col_defs=[{"header1": "X", "mau": "$truong_khong_co_that", "kieu": "chu"}])
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=xau)
    check("khuôn nhắc trường không có thì BÁO LỖI, không lặng lẽ để trống", ma == 400, noi)
    xau2 = dict(mau, name="Mẫu hỏng 2",
                col_defs=[{"header1": "X", "mau": "${asset_id|bang_chua_khai}", "kieu": "chu"}])
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=xau2)
    check("gọi bảng đổi chưa khai thì báo lỗi (400)", ma == 400, noi)
    xau3 = dict(mau, name="Mẫu hỏng 3", col_defs=[])
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=xau3)
    check("mẫu không có cột nào trả 400", ma == 400, noi)
    xau4 = dict(mau, name="Mẫu hỏng 4",
                col_defs=[{"header1": "X", "mau": "$asset_id", "kieu": "kieu-la"}])
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=xau4)
    check("kiểu ô lạ trả 400", ma == 400, noi)
    xau5 = dict(mau, name="Mẫu hỏng 5",
                col_defs=[{"header1": "", "mau": "$asset_id", "kieu": "chu"}])
    ma, noi, _ = goi("POST", "/api/export-templates", cookie=a, body=xau5)
    check("cột thiếu tiêu đề trả 400", ma == 400, noi)

    ma, noi, _ = goi("POST", "/api/export-templates/preview", cookie=a, body=dict(mau, limit=5))
    check("xem trước mẫu chưa lưu vẫn chạy (200)", ma == 200, noi)
    check("xem trước trả tiêu đề và các dòng",
          "headers" in (noi or {}) and "rows" in (noi or {}), list(noi or {}))
    check("bảng đổi từ vựng có tác dụng",
          any("May chu" in str(r) for r in (noi or {}).get("rows", [])), (noi or {}).get("rows", [])[:2])

    ma, _, headers = goi("GET", f"/api/export/template/{mid}.xlsx", cookie=a)
    check("xuất file theo mẫu trả 200", ma == 200, ma)
    check("trả đúng kiểu file xlsx",
          "spreadsheetml" in headers.get("Content-Type", ""), headers.get("Content-Type"))
    ma, _, _ = goi("GET", "/api/export/template/999999.xlsx", cookie=a)
    check("xuất theo mẫu không có trả 404", ma == 404, ma)
    ma, _, _ = goi("PUT", f"/api/export-templates/{mid}", cookie=a, body=dict(mau, name="Mẫu thử 2"))
    check("sửa mẫu được (200)", ma == 200, ma)
    ma, _, _ = goi("DELETE", f"/api/export-templates/{mid}", cookie=a)
    check("xoá mẫu được (200)", ma == 200, ma)
    ma, _, _ = goi("DELETE", "/api/export-templates/999999", cookie=a)
    check("xoá mẫu không có trả 404", ma == 404, ma)


def kiem_sao_luu(ck: dict) -> None:
    nhom("Sao lưu database")
    a = ck["admin"]
    ma, noi, _ = goi("GET", "/api/backup", cookie=a)
    check("đọc được cấu hình sao lưu", ma == 200 and "config" in (noi or {}), noi)
    ma, noi, _ = goi("PUT", "/api/backup", cookie=a,
                     body={"enabled": True, "hour": 3, "minute": 15, "keep": 5})
    check("lưu cấu hình sao lưu trả 200", ma == 200, noi)
    ma, noi, _ = goi("GET", "/api/backup", cookie=a)
    cfg = (noi or {}).get("config", {})
    check("cấu hình lưu xuống đọc lại đúng",
          cfg.get("hour") == 3 and cfg.get("minute") == 15 and cfg.get("keep") == 5, cfg)
    ma, noi, _ = goi("PUT", "/api/backup", cookie=a, body={"hour": 99, "minute": 0, "keep": 1})
    check("giờ chạy ngoài khoảng bị chặn (400)", ma == 400, noi)
    ma, noi, _ = goi("PUT", "/api/backup", cookie=a, body={"hour": 1, "minute": 0, "keep": 0})
    check("số bản giữ phải lớn hơn 0 (400)", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/backup/run", cookie=a)
    check("sao lưu tay chạy được và ra file", ma == 200 and (noi or {}).get("bytes", 0) > 0, noi)


def kiem_nhat_ky(ck: dict) -> None:
    nhom("Nhật ký thao tác")
    a = ck["admin"]
    ma, noi, _ = goi("GET", "/api/audit", cookie=a)
    muc = (noi or {}).get("entries", [])
    check("mọi việc vừa làm đều để lại nhật ký", ma == 200 and len(muc) > 20, len(muc))
    check("nhật ký ghi rõ ai làm", muc and all(m.get("username") for m in muc[:10]), muc[:1])
    check("nhật ký ghi giá trị cũ khi sửa",
          any(m.get("changes") for m in muc), [m for m in muc if m.get("changes")][:1])
    check("nhật ký KHÔNG chứa mật khẩu băm",
          not any("scrypt" in json.dumps(m, ensure_ascii=False) for m in muc))
    ma, noi, _ = goi("GET", "/api/audit?entity=asset&limit=5", cookie=a)
    check("lọc nhật ký theo loại đối tượng được",
          ma == 200 and all(m.get("entity") == "asset" for m in (noi or {}).get("entries", [])), noi)


def kiem_xoa_sach(ck: dict) -> None:
    """Chạy CUỐI CÙNG: nó xoá dữ liệu của chính bộ kiểm."""
    nhom("Xoá sạch dữ liệu")
    a = ck["admin"]
    ma, noi, _ = goi("POST", "/api/data/wipe", cookie=a, body={"confirm": "xoa nham"})
    check("gõ sai câu xác nhận thì không xoá (400)", ma == 400, noi)
    ma, noi, _ = goi("POST", "/api/data/wipe", cookie=a,
                     body={"confirm": "XOA SACH", "scope": "pham-vi-bia"})
    check("phạm vi lạ bị chặn (400)", ma == 400, noi)

    ma, noi, _ = goi("GET", "/api/data", cookie=a)
    truoc = len((noi or {}).get("assetRows", []))
    check("trước khi xoá còn tài sản trong database", truoc > 0, truoc)
    ma, noi, _ = goi("POST", "/api/data/wipe", cookie=a, body={"confirm": "XOA SACH"})
    check("xoá sạch trả 200", ma == 200, noi)
    ma, noi, _ = goi("GET", "/api/data", cookie=a)
    check("xoá xong không còn tài sản nào", len((noi or {}).get("assetRows", [])) == 0, noi)
    check("danh mục TRẠNG THÁI không bị xoá theo",
          len((noi or {}).get("statuses", [])) > 0, len((noi or {}).get("statuses", [])))
    check("danh mục LOẠI TÀI SẢN không bị xoá theo",
          len((noi or {}).get("assetTypes", [])) > 0, len((noi or {}).get("assetTypes", [])))
    ma, noi, _ = goi("GET", "/api/users", cookie=a)
    check("TÀI KHOẢN không bị xoá theo (không tự khoá mình ra ngoài)",
          len((noi or {}).get("users", [])) > 0, noi)
    check("phiên đăng nhập vẫn còn dùng được sau khi xoá sạch", ma == 200, ma)


def kiem_chong_tiem_sql(ck: dict) -> None:
    """Bandit cảnh báo 13 chỗ ghép tên cột vào SQL (B608). Tên cột đều lọc qua whitelist chữ
    cứng, nhưng đọc code rồi tin là chưa đủ — thử tiêm thật rồi xem database còn nguyên không."""
    nhom("Chống tiêm SQL — thử tiêm thật vào các chỗ Bandit cảnh báo")
    a = ck["admin"]
    doc = 'x"; DROP TABLE asset; --'

    # 1. tên cột lạ trong payload tài sản phải bị BỎ QUA, không ghép vào câu lệnh
    ma, noi, _ = goi("POST", "/api/assets", cookie=a,
                     body={"asset_id": "tiem-1", "asset_name": "Thử tiêm",
                           "asset_name) VALUES (1); DROP TABLE asset; --": "x"})
    check("tên cột lạ trong payload bị bỏ qua, tạo tài sản vẫn bình thường", ma == 201, noi)

    # 2. sửa hàng loạt: khoá độc phải rơi hết, còn lại rỗng -> 400
    ma, noi, _ = goi("POST", "/api/assets/bulk-update", cookie=a,
                     body={"ids": ["tiem-1"], "changes": {doc: "1", "khong_co_cot_nay": "2"}})
    check("sửa hàng loạt với toàn khoá lạ bị chặn (400), không ghép vào SQL", ma == 400, noi)

    # 3. sửa tài khoản: khoá lạ không được thành tên cột
    ma, noi, _ = goi("PUT", "/api/users/1", cookie=a, body={doc: "1"})
    check("sửa tài khoản với khoá lạ không đụng được SQL", ma in (400, 409), noi)

    # 4. bộ lọc nhật ký ghép chuỗi điều kiện -> tham số phải đi qua %s
    ma, noi, _ = goi("GET", f"/api/audit?entity={urllib.parse.quote(doc)}&limit=5", cookie=a)
    check("bộ lọc nhật ký nhận chuỗi độc mà không vỡ", ma == 200, ma)
    check("chuỗi độc chỉ là GIÁ TRỊ tìm kiếm, không khớp gì",
          ma == 200 and (noi or {}).get("entries") == [], noi)

    # 5. giá trị chứa cú pháp SQL phải được LƯU NGUYÊN VĂN, không thi hành
    ma, noi, _ = goi("PUT", "/api/assets/tiem-1", cookie=a, body={"description": doc})
    check("giá trị chứa cú pháp SQL lưu được bình thường", ma == 200, noi)
    ma, noi, _ = goi("GET", "/api/data", cookie=a)
    hang = [r for r in (noi or {}).get("assetRows", []) if r.get("asset_id") == "tiem-1"]
    check("lưu NGUYÊN VĂN chuỗi độc, không bị thi hành",
          hang and hang[0].get("description") == doc, hang[:1])

    # 6. sau tất cả, bảng vẫn còn và dữ liệu vẫn đọc được
    check("bảng asset vẫn còn nguyên sau mọi phép thử", len((noi or {}).get("assetRows", [])) > 0)
    goi("DELETE", "/api/assets/tiem-1", cookie=a)


def kiem_phu_song(app_mod) -> None:
    """Tiêu chí của task là MỌI endpoint ghi đều có ca kiểm. Không tự nhận — đối chiếu
    thẳng với bảng route của FastAPI, nên thêm endpoint mới mà quên viết kiểm là gãy ngay."""
    nhom("Độ phủ — đối chiếu với bảng route thật")
    thieu, dem = [], 0
    for route in app_mod.app.routes:
        cach = getattr(route, "methods", None) or set()
        for m in sorted(cach & {"POST", "PUT", "DELETE"}):
            dem += 1
            if not any(mm == m and route.path_regex.match(p) for mm, p in DA_GOI):
                thieu.append(f"{m} {route.path}")
    check(f"cả {dem} endpoint ghi đều đã được gọi ít nhất một lần", not thieu, "; ".join(thieu))
    check("có gọi cả endpoint đọc để chắc dữ liệu ghi xuống đọc lại được",
          any(m == "GET" for m, _ in DA_GOI))


# ----------------------------------------------------------------- chạy
MK_ADMIN = "mat-khau-thu-rat-dai"


def tao_tai_khoan(app_mod) -> None:
    with app_mod.connect() as conn:
        for ten, vai in (("admin", "admin"), ("nguoi_sua", "sua"), ("nguoi_xem", "xem")):
            conn.execute(
                "INSERT INTO app_user (username, email, full_name, role, password_hash)"
                " VALUES (%s,%s,%s,%s,%s) ON CONFLICT (username) DO NOTHING",
                (ten, f"{ten}@thu.local", ten, vai, app_mod.hash_password(MK_ADMIN)),
            )
        conn.commit()


def main() -> int:
    if not os.environ.get("DATABASE_URL"):
        print("Thiếu DATABASE_URL.", file=sys.stderr)
        return 2
    dsn = dung_database()
    os.environ["DATABASE_URL"] = dsn          # app đọc DSN lúc import
    os.environ.setdefault("COOKIE_SECURE", "0")
    os.environ.setdefault("BACKUP_DIR", "/tmp/backup-thu")
    Path(os.environ["BACKUP_DIR"]).mkdir(parents=True, exist_ok=True)

    import uvicorn

    import app as app_mod

    server = uvicorn.Server(uvicorn.Config(app_mod.app, host="127.0.0.1", port=CONG,
                                           log_level="warning"))
    threading.Thread(target=server.run, daemon=True).start()
    for _ in range(100):
        try:
            if goi("GET", "/api/health")[0] == 200:
                break
        except Exception:
            pass
        time.sleep(0.1)
    else:
        print("API không lên được.", file=sys.stderr)
        return 2

    tao_tai_khoan(app_mod)
    ck = {
        "admin": dang_nhap("admin", MK_ADMIN),
        "sua": dang_nhap("nguoi_sua", MK_ADMIN),
        "xem": dang_nhap("nguoi_xem", MK_ADMIN),
    }
    if not all(ck.values()):
        print("Không đăng nhập được bằng tài khoản thử.", file=sys.stderr)
        return 2

    try:
        kiem_dang_nhap(ck)
        kiem_phan_quyen(ck)
        kiem_tai_khoan(ck)
        kiem_danh_muc(ck)
        vt = kiem_vi_tri(ck)
        ts = kiem_tai_san(ck, vt)
        kiem_su_kien(ck, ts)
        kiem_rang_buoc_xoa(ck, vt, ts)
        kiem_hang_loat(ck, vt)
        kiem_nhap_file(ck)
        kiem_mau_xuat(ck)
        kiem_sao_luu(ck)
        kiem_nhat_ky(ck)
        kiem_chong_tiem_sql(ck)
        kiem_xoa_sach(ck)          # phải đứng cuối
        kiem_phu_song(app_mod)
    finally:
        for dong in bao_cao:
            print(dong)
        xoa_database()

    hong = sum(1 for d in bao_cao if d.startswith("FAIL"))
    tong = sum(1 for d in bao_cao if d.startswith(("PASS", "FAIL")))
    print(f"\n{tong - hong} PASS · {hong} FAIL")
    return 1 if hong else 0


if __name__ == "__main__":
    sys.exit(main())
