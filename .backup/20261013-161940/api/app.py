"""Device Management API — Postgres là nguồn dữ liệu duy nhất của ứng dụng.

Mọi thao tác thêm / sửa / xóa của người dùng đều đi qua đây và ghi thẳng vào database.
CSV và XLSX chỉ là hai công cụ hỗ trợ: nạp dữ liệu vào và lấy dữ liệu ra để đối soát —
không phải nơi lưu trữ. Sổ Excel gốc chỉ còn là dấu vết nguồn của từng bản ghi
(`source_sheet` / `source_row`), giữ để truy ngược, không phải "chân lý" của hệ thống.
"""
from __future__ import annotations

import base64
import csv
import hashlib
import hmac
import io
import json
import unicodedata
import os
import re
import secrets
import time
from datetime import date, datetime, timedelta, timezone
from typing import Any

import gzip
import subprocess
import threading
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.parse import quote
import psycopg
from psycopg.types.json import Json
from fastapi import Depends, FastAPI, Form, HTTPException, Request, Response, UploadFile, File
from fastapi.responses import StreamingResponse
from psycopg.rows import dict_row

DSN = os.environ.get("DATABASE_URL", "postgresql://mgmt-device:mgmt-device@db:5432/mgmt-device")
COOKIE_NAME = "mgmt_device_session"
COOKIE_SECURE = os.environ.get("COOKIE_SECURE", "").lower() in {"1", "true", "yes"}
SESSION_HOURS = int(os.environ.get("SESSION_HOURS", "8"))

ASSET_COLUMNS = [
    "asset_id", "code_pending", "asset_name", "asset_type", "asset_category", "ip_address",
    "ip_or_type_raw", "cluster", "in_store", "datacenter", "current_location", "rack",
    "rack_unit", "rack_size_u", "parent_reference",
    "capacity", "replacement_target", "usage_status", "usage_status_label",
    "usage_start_date", "handover_date", "handover_status", "purchase_invoice",
    "purchase_price_vnd", "supplier_code", "supplier_name", "warranty_months",
    "warranty_end_date", "serial", "description", "source_sheet", "source_row", "review_flags",
]
HISTORY_COLUMNS = [
    "asset_id", "event_sequence", "event_type", "event_date", "location",
    "usage_object", "notes", "declared_transition_count", "source_column",
    "source_row", "review_flags",
]

# on_event đã bị đánh dấu bỏ (FastAPI cảnh báo DeprecationWarning, sẽ gỡ hẳn ở bản sau).
# lifespan là đường thay thế: hai việc lúc khởi động gom về một chỗ, chạy đúng thứ tự —
# vá lược đồ TRƯỚC rồi mới bật bộ lập lịch sao lưu, vì bộ lập lịch cần bảng backup_config.
@asynccontextmanager
async def vong_doi(_app: "FastAPI"):
    ensure_schema()          # định nghĩa bên dưới; chỉ gọi lúc chạy nên thứ tự không sao
    bat_bo_lap_lich()
    yield


app = FastAPI(title="Device Management API", docs_url="/api/docs",
              openapi_url="/api/openapi.json", lifespan=vong_doi)


def connect() -> psycopg.Connection:
    return psycopg.connect(DSN, row_factory=dict_row)


def text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (date, datetime)):
        return value.isoformat()[:10]
    if isinstance(value, list):
        return ";".join(str(item) for item in value)
    return str(value)


def stamp(value: Any) -> str:
    """Dấu thời gian đầy đủ (khác `text`, vốn cắt còn phần ngày)."""
    return value.isoformat(timespec="seconds") if isinstance(value, datetime) else ""


def as_int(value: Any) -> int | None:
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def as_date(value: Any) -> date | None:
    raw = str(value or "").strip()
    if not raw:
        return None
    try:
        return date.fromisoformat(raw[:10])
    except ValueError:
        return None


def as_flags(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    return [part.strip() for part in str(value or "").replace("|", ";").split(";") if part.strip()]


# ------------------------------------------------------------------ tài khoản
# Mật khẩu KHÔNG bao giờ lưu dạng thô: scrypt (thư viện chuẩn, không thêm dependency).
SCRYPT_N, SCRYPT_R, SCRYPT_P = 2 ** 14, 8, 1


def hash_password(password: str, salt: bytes | None = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=SCRYPT_N, r=SCRYPT_R, p=SCRYPT_P, dklen=32)
    return "$".join([
        "scrypt", str(SCRYPT_N), str(SCRYPT_R), str(SCRYPT_P),
        base64.b64encode(salt).decode(), base64.b64encode(digest).decode(),
    ])


def verify_password(password: str, stored: str) -> bool:
    try:
        scheme, n, r, pcost, salt_b64, digest_b64 = stored.split("$")
        if scheme != "scrypt":
            return False
        digest = hashlib.scrypt(
            password.encode(), salt=base64.b64decode(salt_b64),
            n=int(n), r=int(r), p=int(pcost), dklen=len(base64.b64decode(digest_b64)),
        )
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(digest, base64.b64decode(digest_b64))


# Volume database cũ không chạy lại db/schema.sql, nên các thay đổi schema về sau
# phải viết ở đây dưới dạng lệnh chạy lại được nhiều lần.
SCHEMA_PATCH = """
CREATE TABLE IF NOT EXISTS app_user (
    id            SERIAL PRIMARY KEY,
    username      TEXT UNIQUE NOT NULL,
    email         TEXT,
    full_name     TEXT,
    role          TEXT NOT NULL DEFAULT 'admin',
    password_hash TEXT NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS user_session (
    token      TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_session_expires ON user_session (expires_at);

-- origin: bản ghi vào hệ thống bằng đường nào — 'import' (nạp từ file) hay 'manual'
-- (người dùng tự thêm trên giao diện). Dùng để nói đúng dữ liệu đang từ đâu mà có.
ALTER TABLE asset       ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE asset       ADD COLUMN IF NOT EXISTS origin     TEXT        NOT NULL DEFAULT 'import';
ALTER TABLE asset_event ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE asset_event ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE asset_event ADD COLUMN IF NOT EXISTS origin     TEXT        NOT NULL DEFAULT 'import';
ALTER TABLE site        ADD COLUMN IF NOT EXISTS status     TEXT        NOT NULL DEFAULT 'Đang sử dụng';
-- Vị trí U của thiết bị trong rack. U1 là đáy rack (chuẩn EIA-310), NULL = chưa ghi nhận.
ALTER TABLE asset       ADD COLUMN IF NOT EXISTS rack_unit  INTEGER;
-- Số U thiết bị chiếm (máy 2U đứng ở U42 thì chiếm U42–43). Là thuộc tính của THIẾT BỊ chứ
-- không phải của chỗ đặt: vào kho vẫn giữ. NULL = chưa khai báo, sơ đồ chỉ hiện U bắt đầu.
ALTER TABLE asset       ADD COLUMN IF NOT EXISTS rack_size_u INTEGER;
-- Kho KHÔNG phải một site. Tài sản đang nằm kho thì in_store = TRUE và không có
-- site / phòng máy / rack nào cả; màn Kho quản lý riêng phần này.
ALTER TABLE asset       ADD COLUMN IF NOT EXISTS in_store   BOOLEAN NOT NULL DEFAULT FALSE;
-- Chuyển dữ liệu của mô hình cũ (kho từng là site kind='warehouse') sang cột in_store,
-- rồi bỏ những site đó khỏi danh mục vị trí. Chạy lại nhiều lần không sao.
UPDATE asset SET in_store = TRUE, datacenter = NULL, current_location = NULL,
                 site_id = NULL, room_id = NULL, rack_id = NULL, rack_unit = NULL
 WHERE datacenter IN (SELECT name FROM site WHERE kind = 'warehouse');
DELETE FROM site WHERE kind = 'warehouse';
CREATE INDEX IF NOT EXISTS idx_asset_in_store ON asset (in_store);
-- Thêm tài sản khi chưa biết mã: hệ thống cấp mã tạm CHUA-GAN-#### và bật cờ này.
-- Mã tạm vẫn là mã thật trong database nên khóa ngoại và xuất/nhập file vẫn chạy.
ALTER TABLE asset ADD COLUMN IF NOT EXISTS code_pending BOOLEAN NOT NULL DEFAULT FALSE;
-- Số serial / license do hãng cấp. Là của riêng từng máy nên không sửa hàng loạt được.
ALTER TABLE asset ADD COLUMN IF NOT EXISTS serial TEXT;
CREATE SEQUENCE IF NOT EXISTS asset_code_seq;

-- Danh mục loại tài sản: trước đây là bảng cứng trong index.html nên không sửa được.
CREATE TABLE IF NOT EXISTS asset_type (
    code       TEXT PRIMARY KEY,
    label      TEXT NOT NULL,
    note       TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0
);
INSERT INTO asset_type (code, label, sort_order) VALUES
    ('server', 'Server', 1), ('switch', 'Switch', 2), ('firewall', 'Firewall', 3),
    ('network_or_host', 'Thiết bị mạng / Host', 4), ('hsm', 'HSM', 5),
    ('disk', 'Ổ cứng', 6), ('ram', 'RAM', 7), ('cpu', 'CPU', 8),
    ('raid_card', 'Card RAID', 9), ('nic', 'Card mạng', 10),
    ('optical_module', 'Module quang', 11), ('power_supply', 'Bộ nguồn', 12),
    ('adapter', 'Adapter', 13), ('cable', 'Cáp', 14), ('raid_cable', 'Cáp RAID', 15),
    ('unknown', 'Chưa xác định', 99)
ON CONFLICT (code) DO NOTHING;
-- Mã loại lạ đang có trong dữ liệu vẫn phải quản lý được, không im lặng bỏ qua.
INSERT INTO asset_type (code, label, sort_order)
SELECT DISTINCT asset_type, asset_type, 50 FROM asset
 WHERE asset_type IS NOT NULL AND btrim(asset_type) <> ''
ON CONFLICT (code) DO NOTHING;
ALTER TABLE rack        ADD COLUMN IF NOT EXISTS status     TEXT        NOT NULL DEFAULT 'Đang sử dụng';

-- Nhật ký nhập file: mỗi lần nạp CSV/XLSX là một dòng, để biết dữ liệu trong
-- database được bồi thêm lúc nào, bằng file nào, do ai.
CREATE TABLE IF NOT EXISTS import_log (
    id         BIGSERIAL PRIMARY KEY,
    kind       TEXT NOT NULL,               -- assets | history
    file_name  TEXT NOT NULL,
    file_type  TEXT NOT NULL,               -- csv | xlsx
    rows_read  INTEGER NOT NULL DEFAULT 0,
    added      INTEGER NOT NULL DEFAULT 0,
    updated    INTEGER NOT NULL DEFAULT 0,
    skipped    INTEGER NOT NULL DEFAULT 0,
    username   TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_import_log_time ON import_log (created_at DESC);

-- Nhật ký thao tác: ai sửa gì, lúc nào, giá trị cũ là gì. Ghi ở tầng ứng dụng chứ không
-- bằng trigger, vì chỉ tầng ứng dụng mới biết ai đang thao tác (phiên đăng nhập).
CREATE TABLE IF NOT EXISTS audit_log (
    id         BIGSERIAL PRIMARY KEY,
    at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    username   TEXT,
    action     TEXT NOT NULL,               -- them | sua | xoa | nhap | luan_chuyen | xoa_sach
    entity     TEXT NOT NULL,               -- asset | event | status | asset_type | cluster | location | data
    entity_id  TEXT,
    changes    JSONB,                       -- {cột: {"cu": ..., "moi": ...}}
    note       TEXT
);
CREATE INDEX IF NOT EXISTS idx_audit_time   ON audit_log (at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log (entity, entity_id, at DESC);

-- Cấu hình sao lưu tự động. Đúng MỘT dòng (id = 1) — cấu hình của hệ thống, không phải
-- của từng người dùng, nên không cần khóa nào khác.
CREATE TABLE IF NOT EXISTS backup_config (
    id         SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    enabled    BOOLEAN NOT NULL DEFAULT FALSE,
    hour       SMALLINT NOT NULL DEFAULT 2  CHECK (hour BETWEEN 0 AND 23),
    minute     SMALLINT NOT NULL DEFAULT 0  CHECK (minute BETWEEN 0 AND 59),
    keep       SMALLINT NOT NULL DEFAULT 14 CHECK (keep BETWEEN 1 AND 365),
    last_run_at   TIMESTAMPTZ,
    last_status   TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO backup_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
CREATE INDEX IF NOT EXISTS idx_asset_origin    ON asset (origin);

-- Danh mục cụm vận hành. Trước đây cụm là chữ gõ tay trên từng tài sản nên dễ lệch
-- ("MBO" / "mbo" / "MB0"); gom về một danh mục để form chọn thay vì gõ.
CREATE TABLE IF NOT EXISTS cluster (
    name TEXT PRIMARY KEY,
    note TEXT
);
INSERT INTO cluster (name)
SELECT DISTINCT btrim(cluster) FROM asset WHERE cluster IS NOT NULL AND btrim(cluster) <> ''
ON CONFLICT (name) DO NOTHING;

-- Mã tài sản là khóa chính nhưng vẫn phải sửa được khi người dùng gõ nhầm. Cho khóa ngoại
-- ON UPDATE CASCADE để sự kiện / quan hệ cha-con đi theo mã mới thay vì chặn câu lệnh.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conname = 'asset_event_asset_id_fkey' AND confupdtype <> 'c') THEN
        ALTER TABLE asset_event DROP CONSTRAINT asset_event_asset_id_fkey;
        ALTER TABLE asset_event ADD CONSTRAINT asset_event_asset_id_fkey
            FOREIGN KEY (asset_id) REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conname = 'asset_parent_asset_id_fkey' AND confupdtype <> 'c') THEN
        ALTER TABLE asset DROP CONSTRAINT asset_parent_asset_id_fkey;
        ALTER TABLE asset ADD CONSTRAINT asset_parent_asset_id_fkey
            FOREIGN KEY (parent_asset_id) REFERENCES asset(asset_id) ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conname = 'placement_asset_id_fkey' AND confupdtype <> 'c') THEN
        ALTER TABLE placement DROP CONSTRAINT placement_asset_id_fkey;
        ALTER TABLE placement ADD CONSTRAINT placement_asset_id_fkey
            FOREIGN KEY (asset_id) REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

-- Mẫu file xuất cho phòng ban khác. Mỗi mẫu là MỘT tác vụ (nạp ERP, kiểm kê, bàn giao...),
-- có bộ cột riêng và cách lấy dữ liệu riêng. col_defs là mảng:
--   [{"header1": "MÃ TÀI SẢN", "header2": "Equipment/.../Serial Number", "mau": "$asset_id"}]
-- `mau` là khuôn chuỗi: chữ thường giữ nguyên, $ten_truong thay bằng giá trị của tài sản,
-- ${ten|bang} tra thêm qua bảng đổi từ vựng trong cột maps.
CREATE TABLE IF NOT EXISTS export_template (
    id          SERIAL PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    note        TEXT,
    file_name   TEXT,
    sheet_name  TEXT NOT NULL DEFAULT 'Sheet1',
    header_rows INTEGER NOT NULL DEFAULT 1,
    scope       JSONB NOT NULL DEFAULT '{}'::jsonb,
    maps        JSONB NOT NULL DEFAULT '{}'::jsonb,
    col_defs    JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""


def ensure_schema() -> None:
    with connect() as conn:
        conn.execute(SCHEMA_PATCH)
        conn.execute("DELETE FROM user_session WHERE expires_at < now()")
        gieo_mau_xuat(conn)
        conn.commit()


def current_user(request: Request) -> dict:
    token = request.cookies.get(COOKIE_NAME)
    if not token:
        raise HTTPException(status_code=401, detail="Chưa đăng nhập.")
    with connect() as conn:
        row = conn.execute(
            """
            SELECT u.id, u.username, u.email, u.full_name, u.role
            FROM user_session s JOIN app_user u ON u.id = s.user_id
            WHERE s.token = %s AND s.expires_at > now() AND u.is_active
            """,
            (token,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Phiên đăng nhập đã hết hạn.")
    return row


@app.post("/api/login")
def login(response: Response, payload: dict) -> dict:
    username = str(payload.get("username") or payload.get("account") or "").strip().lower()
    password = str(payload.get("password", ""))
    with connect() as conn:
        row = conn.execute(
            "SELECT id, username, email, full_name, role, password_hash FROM app_user"
            " WHERE lower(username) = %s AND is_active",
            (username,),
        ).fetchone()
        if not row or not verify_password(password, row["password_hash"]):
            time.sleep(0.4)  # làm chậm dò mật khẩu; không tiết lộ tài khoản có tồn tại hay không
            raise HTTPException(status_code=401, detail="Tài khoản hoặc mật khẩu không đúng.")
        token = secrets.token_urlsafe(32)
        expires = datetime.now(timezone.utc) + timedelta(hours=SESSION_HOURS)
        conn.execute(
            "INSERT INTO user_session (token, user_id, expires_at) VALUES (%s, %s, %s)",
            (token, row["id"], expires),
        )
        conn.execute("UPDATE app_user SET last_login_at = now() WHERE id = %s", (row["id"],))
        conn.execute("DELETE FROM user_session WHERE expires_at < now()")
        conn.commit()
    response.set_cookie(
        COOKIE_NAME, token, max_age=SESSION_HOURS * 3600, httponly=True,
        samesite="lax", secure=COOKIE_SECURE, path="/",
    )
    return {"username": row["username"], "email": row["email"], "fullName": row["full_name"], "role": row["role"]}


@app.get("/api/me")
def me(user: dict = Depends(current_user)) -> dict:
    return {"username": user["username"], "email": user["email"], "fullName": user["full_name"], "role": user["role"]}


@app.post("/api/logout")
def logout(request: Request, response: Response) -> dict:
    token = request.cookies.get(COOKIE_NAME)
    if token:
        with connect() as conn:
            conn.execute("DELETE FROM user_session WHERE token = %s", (token,))
            conn.commit()
    response.delete_cookie(COOKIE_NAME, path="/")
    return {"status": "ok"}


# ---------------------------------------------------------------- đọc dữ liệu
# Rack nằm ở bảng khác nên mọi câu đọc asset đều kèm nhãn rack, tránh phải tra lần hai.
ASSET_SELECT = """
    SELECT a.*, r.code AS rack_code, m.code AS room_code, s.name AS rack_site
    FROM asset a
    LEFT JOIN rack r ON r.id = a.rack_id
    LEFT JOIN room m ON m.id = r.room_id
    LEFT JOIN site s ON s.id = m.site_id
"""


def rack_label(row: dict) -> str:
    if not row.get("rack_code"):
        return ""
    room = row.get("room_code") or ""
    return f"{room} · {row['rack_code']}" if room and room != "—" else str(row["rack_code"])


def asset_row_out(row: dict) -> dict:
    """Một dòng asset trong DB -> đúng bộ cột của asset_import.csv (bỏ ô rỗng)."""
    out = {
        "asset_id": row["asset_id"],
        "code_pending": "1" if row.get("code_pending") else "",
        "asset_name": row["asset_name"],
        "asset_type": row["asset_type"],
        "asset_category": row["asset_category"],
        "ip_address": row["ip_address"],
        "ip_or_type_raw": row["ip_or_type_raw"],
        "cluster": row["cluster"],
        "datacenter": row["datacenter"],
        "current_location": row["current_location"],
        "rack": row.get("rack_code"),
        "rack_unit": row.get("rack_unit"),
        "rack_size_u": row.get("rack_size_u"),
        "in_store": "1" if row.get("in_store") else "",
        "code_pending": "1" if row.get("code_pending") else "",
        "parent_reference": row["parent_asset_id"] or row["attachment_label"],
        "capacity": row["capacity"],
        "replacement_target": row["replacement_target"],
        "usage_status": row["usage_status"],
        "usage_status_label": row["usage_status_label"],
        "usage_start_date": row["usage_start_date"],
        "handover_date": row["handover_date"],
        "handover_status": row["handover_status"],
        "purchase_invoice": row["purchase_invoice"],
        "purchase_price_vnd": row["purchase_price_vnd"],
        "supplier_code": row["supplier_code"],
        "supplier_name": row["supplier_name"],
        "warranty_months": row["warranty_months"],
        "warranty_end_date": row["warranty_end_date"],
        "serial": row["serial"],
        "description": row["description"],
        "source_sheet": row["source_sheet"],
        "source_row": row["source_row"],
        "review_flags": row["review_flags"],
    }
    packed = {key: text(value) for key, value in out.items() if text(value)}
    packed["origin"] = row.get("origin") or "import"
    packed["updated_at"] = stamp(row.get("updated_at"))
    packed["rack_id"] = text(row.get("rack_id"))
    packed["room_id"] = text(row.get("room_id"))
    packed["rack_label"] = rack_label(row)
    return packed


def history_row_out(row: dict) -> dict:
    out = {key: row.get(key) for key in HISTORY_COLUMNS}
    packed = {key: text(value) for key, value in out.items() if text(value) or key == "event_sequence"}
    packed["event_id"] = str(row["id"])
    packed["origin"] = row.get("origin") or "import"
    return packed


def location_rows(conn: psycopg.Connection) -> list[dict]:
    """Danh mục vị trí lấy thẳng từ bảng site / room / rack, không suy từ chuỗi datacenter."""
    sites = conn.execute("SELECT id, name, kind, status FROM site ORDER BY name").fetchall()
    rooms = conn.execute(
        """
        SELECT m.id, m.code, m.name, s.name AS site
        FROM room m JOIN site s ON s.id = m.site_id
        ORDER BY s.name, m.code
        """
    ).fetchall()
    racks = conn.execute(
        """
        SELECT r.id, r.code AS rack, r.status, r.height_u, m.id AS room_id, m.code AS room, s.name AS site
        FROM rack r JOIN room m ON m.id = r.room_id JOIN site s ON s.id = m.site_id
        ORDER BY s.name, m.code, r.code
        """
    ).fetchall()
    out = [
        {"id": f"site-{row['id']}", "kind": "location", "site": row["name"], "room": "",
         "rack": "", "siteKind": row["kind"], "status": row["status"]}
        for row in sites
    ]
    out += [
        {"id": f"room-{row['id']}", "kind": "room", "site": row["site"], "room": row["code"],
         "roomName": row["name"] or "", "rack": "", "siteKind": "", "status": "",
         "roomId": str(row["id"])}
        for row in rooms
    ]
    out += [
        {"id": f"rack-{row['id']}", "kind": "rack", "site": row["site"], "room": row["room"] or "",
         "rack": row["rack"], "siteKind": "", "status": row["status"], "rackId": str(row["id"]),
         "roomId": str(row["room_id"]), "heightU": str(row["height_u"])}
        for row in racks
    ]
    return out


def asset_type_rows(conn: psycopg.Connection) -> list[dict]:
    rows = conn.execute("SELECT code, label, note FROM asset_type ORDER BY sort_order, label").fetchall()
    return [{"code": row["code"], "label": row["label"], "note": row["note"] or ""} for row in rows]


def cluster_rows(conn: psycopg.Connection) -> list[dict]:
    rows = conn.execute("SELECT name, note FROM cluster ORDER BY name").fetchall()
    return [{"name": row["name"], "note": row["note"] or ""} for row in rows]


def dataset_meta(conn: psycopg.Connection, assets: list[dict], events: list[dict]) -> dict:
    last_import = conn.execute(
        "SELECT kind, file_name, file_type, rows_read, added, updated, skipped, username, created_at"
        " FROM import_log ORDER BY created_at DESC LIMIT 1"
    ).fetchone()
    touched = [row["updated_at"] for row in assets if row.get("updated_at")]
    return {
        # Nguồn dữ liệu của ứng dụng là database, không phải file nào cả.
        "source": "postgres",
        "storage": "PostgreSQL",
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "assetCount": len(assets),
        "eventCount": len(events),
        "assetsFlagged": sum(1 for row in assets if row["review_flags"]),
        "eventsFlagged": sum(1 for row in events if row["review_flags"]),
        "manualAssets": sum(1 for row in assets if (row.get("origin") or "import") == "manual"),
        "storedAssets": sum(1 for row in assets if row.get("in_store")),
        "importedAssets": sum(1 for row in assets if (row.get("origin") or "import") == "import"),
        "lastChangeAt": stamp(max(touched)) if touched else "",
        "lastImport": {
            "kind": last_import["kind"],
            "fileName": last_import["file_name"],
            "fileType": last_import["file_type"],
            "rows": last_import["rows_read"],
            "added": last_import["added"],
            "updated": last_import["updated"],
            "skipped": last_import["skipped"],
            "username": last_import["username"] or "",
            "at": stamp(last_import["created_at"]),
        } if last_import else None,
    }


@app.get("/api/health")
def health() -> dict:
    with connect() as conn:
        conn.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/api/data")
def data(user: dict = Depends(current_user)) -> dict:
    with connect() as conn:
        assets = conn.execute(
            ASSET_SELECT + " ORDER BY a.source_row NULLS LAST, a.created_at, a.asset_id"
        ).fetchall()
        events = conn.execute(
            "SELECT * FROM asset_event ORDER BY source_row NULLS LAST, asset_id, event_sequence"
        ).fetchall()
        statuses = conn.execute("SELECT * FROM status_catalog ORDER BY sort_order, code").fetchall()
        locations = location_rows(conn)
        clusters = cluster_rows(conn)
        types = asset_type_rows(conn)
        meta = dataset_meta(conn, assets, events)
    return {
        "meta": meta,
        "statuses": [
            {"code": row["code"], "label": row["label"], "cls": row["tag_style"], "attention": row["attention"]}
            for row in statuses
        ],
        "locations": locations,
        "clusters": clusters,
        "assetTypes": types,
        "assetRows": [asset_row_out(row) for row in assets],
        "historyRows": [history_row_out(row) for row in events],
    }


@app.get("/api/imports")
def imports(user: dict = Depends(current_user)) -> dict:
    with connect() as conn:
        rows = conn.execute(
            "SELECT kind, file_name, file_type, rows_read, added, updated, skipped, username, created_at"
            " FROM import_log ORDER BY created_at DESC LIMIT 20"
        ).fetchall()
    return {"imports": [
        {"kind": row["kind"], "fileName": row["file_name"], "fileType": row["file_type"],
         "rows": row["rows_read"], "added": row["added"], "updated": row["updated"],
         "skipped": row["skipped"], "username": row["username"] or "", "at": stamp(row["created_at"])}
        for row in rows
    ]}


# ------------------------------------------------------------------- sao lưu
# pg_dump chạy trong container api (ảnh đã cài postgresql-client) và ghi vào volume
# /backups. Không dùng cron của máy chủ: lịch nằm trong database nên đổi được từ giao
# diện, và ứng dụng dựng lại ở máy khác vẫn giữ nguyên cấu hình.
BACKUP_DIR = Path(os.environ.get("BACKUP_DIR", "/backups"))
BACKUP_PREFIX = "mgmt-device-"


def doc_cau_hinh_sao_luu(conn: psycopg.Connection) -> dict:
    row = conn.execute("SELECT * FROM backup_config WHERE id = 1").fetchone()
    if not row:
        conn.execute("INSERT INTO backup_config (id) VALUES (1) ON CONFLICT DO NOTHING")
        conn.commit()
        row = conn.execute("SELECT * FROM backup_config WHERE id = 1").fetchone()
    return dict(row)


def danh_sach_ban_sao() -> list[dict]:
    """Đọc THẲNG từ đĩa chứ không từ một bảng ghi chép — bảng có thể lệch với thực tế."""
    if not BACKUP_DIR.exists():
        return []
    ra = []
    for f in sorted(BACKUP_DIR.glob(f"{BACKUP_PREFIX}*.sql.gz"), reverse=True):
        try:
            st = f.stat()
        except OSError:
            continue
        ra.append({"name": f.name, "bytes": st.st_size,
                   "at": datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat()})
    return ra


def chay_sao_luu(conn: psycopg.Connection, giu: int) -> dict:
    """Tạo một bản sao rồi dọn bản cũ. Trả về {ok, name, bytes, error, removed}."""
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    ten = f"{BACKUP_PREFIX}{datetime.now(timezone.utc):%Y%m%d-%H%M%S}.sql.gz"
    dich = BACKUP_DIR / ten
    tam = dich.with_suffix(dich.suffix + ".dang-ghi")
    try:
        # Ghi ra file tạm rồi mới đổi tên: bản sao dở dang không bao giờ mang tên thật,
        # nên danh sách không bao giờ có file hỏng.
        with gzip.open(tam, "wb") as ra:
            tien_trinh = subprocess.run(
                ["pg_dump", "--no-owner", "--no-privileges", DSN],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=900, check=False,
            )
            if tien_trinh.returncode != 0:
                raise RuntimeError((tien_trinh.stderr or b"").decode()[:400] or "pg_dump lỗi")
            ra.write(tien_trinh.stdout)
        tam.rename(dich)
    except Exception as loi:
        tam.unlink(missing_ok=True)
        return {"ok": False, "error": str(loi)[:400]}
    # Dọn bản cũ, giữ đúng số lượng đã khai.
    bo = [f["name"] for f in danh_sach_ban_sao()[max(1, giu):]]
    for ten_cu in bo:
        (BACKUP_DIR / ten_cu).unlink(missing_ok=True)
    return {"ok": True, "name": ten, "bytes": dich.stat().st_size, "removed": bo}


def den_gio_chua(cfg: dict, bay_gio: datetime) -> bool:
    """Đến giờ hẹn và HÔM NAY chưa chạy lần nào."""
    if not cfg["enabled"]:
        return False
    if (bay_gio.hour, bay_gio.minute) < (cfg["hour"], cfg["minute"]):
        return False
    lan_truoc = cfg["last_run_at"]
    return not (lan_truoc and lan_truoc.astimezone(timezone.utc).date() == bay_gio.date())


def vong_lap_sao_luu() -> None:
    """Chạy nền, mỗi phút xem đã đến giờ chưa. Lỗi ở đây KHÔNG được làm chết API."""
    while True:
        time.sleep(60)
        try:
            with connect() as conn:
                cfg = doc_cau_hinh_sao_luu(conn)
                if not den_gio_chua(cfg, datetime.now(timezone.utc)):
                    continue
                ket = chay_sao_luu(conn, cfg["keep"])
                conn.execute(
                    "UPDATE backup_config SET last_run_at = now(), last_status = %s WHERE id = 1",
                    (f"tự động · {ket['name']}" if ket["ok"] else f"LỖI: {ket.get('error', '')}"[:400],),
                )
                ghi_nhat_ky(conn, {"username": "hệ thống"}, "sao_luu", "data", None, None,
                            f"sao lưu tự động: {ket['name']}" if ket["ok"]
                            else f"sao lưu tự động THẤT BẠI: {ket.get('error', '')}"[:300])
                conn.commit()
        except Exception:
            continue


def bat_bo_lap_lich() -> None:
    threading.Thread(target=vong_lap_sao_luu, daemon=True, name="sao-luu").start()


# ------------------------------------------------------------------ phân quyền
# Ba vai. Ai cũng ĐỌC được; khác nhau ở chỗ ghi và ở quyền quản trị.
VAI = {
    "admin": "Quản trị",        # ghi + quản lý người dùng + xóa sạch dữ liệu
    "sua":   "Sửa dữ liệu",     # ghi, không đụng được người dùng
    "xem":   "Chỉ xem",         # không ghi gì
}
VAI_GHI = {"admin", "sua"}


def nguoi_ghi(user: dict = Depends(current_user)) -> dict:
    """Chặn tài khoản chỉ xem ở TẦNG API. Ẩn nút trên giao diện là tiện lợi, không phải bảo vệ."""
    if str(user.get("role") or "") not in VAI_GHI:
        raise HTTPException(status_code=403, detail="Tài khoản chỉ xem, không sửa được dữ liệu.")
    return user


def nguoi_quan_tri(user: dict = Depends(current_user)) -> dict:
    if str(user.get("role") or "") != "admin":
        raise HTTPException(status_code=403, detail="Việc này chỉ tài khoản quản trị làm được.")
    return user


# ------------------------------------------------------------ người dùng
def user_ra(row: dict) -> dict:
    return {"id": row["id"], "username": row["username"], "fullName": row["full_name"] or "",
            "email": row["email"] or "", "role": row["role"],
            "roleLabel": VAI.get(row["role"], row["role"]), "isActive": row["is_active"],
            "lastLoginAt": stamp(row["last_login_at"]) if row["last_login_at"] else ""}


def doc_vai(payload: dict, mac_dinh: str = "xem") -> str:
    vai = str(payload.get("role") or mac_dinh).strip()
    if vai not in VAI:
        raise HTTPException(status_code=400, detail=f"Vai không hợp lệ: {vai}. Chọn một trong {', '.join(VAI)}.")
    return vai


def con_quan_tri_nao_khong(conn: psycopg.Connection, tru_id: int | None = None) -> int:
    return conn.execute(
        "SELECT count(*) AS n FROM app_user WHERE role = 'admin' AND is_active"
        + (" AND id <> %s" if tru_id else ""),
        (tru_id,) if tru_id else (),
    ).fetchone()["n"]


@app.get("/api/users")
def list_users(user: dict = Depends(nguoi_quan_tri)) -> dict:
    with connect() as conn:
        rows = conn.execute(
            "SELECT id, username, email, full_name, role, is_active, last_login_at"
            " FROM app_user ORDER BY username"
        ).fetchall()
    return {"users": [user_ra(row) for row in rows], "roles": [
        {"code": code, "label": label} for code, label in VAI.items()]}


@app.post("/api/users", status_code=201)
def create_user(payload: dict, user: dict = Depends(nguoi_quan_tri)) -> dict:
    username = str(payload.get("username") or "").strip().lower()
    password = str(payload.get("password") or "")
    if not username:
        raise HTTPException(status_code=400, detail="Thiếu tên đăng nhập.")
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Mật khẩu phải từ 8 ký tự trở lên.")
    vai = doc_vai(payload)
    with connect() as conn:
        if conn.execute("SELECT 1 FROM app_user WHERE username = %s", (username,)).fetchone():
            raise HTTPException(status_code=409, detail=f"Tên đăng nhập {username} đã có.")
        row = conn.execute(
            "INSERT INTO app_user (username, email, full_name, role, password_hash)"
            " VALUES (%s,%s,%s,%s,%s) RETURNING *",
            (username, str(payload.get("email") or "").strip() or None,
             str(payload.get("fullName") or "").strip() or None, vai, hash_password(password)),
        ).fetchone()
        ghi_nhat_ky(conn, user, "them", "user", username,
                    {"role": {"cu": None, "moi": vai}}, "tạo tài khoản mới")
        conn.commit()
    return {"user": user_ra(row)}


@app.put("/api/users/{user_id}")
def update_user(user_id: int, payload: dict, user: dict = Depends(nguoi_quan_tri)) -> dict:
    with connect() as conn:
        truoc = conn.execute("SELECT * FROM app_user WHERE id = %s", (user_id,)).fetchone()
        if not truoc:
            raise HTTPException(status_code=404, detail="Không có tài khoản này.")
        cot: dict = {}
        if "fullName" in payload:
            cot["full_name"] = str(payload.get("fullName") or "").strip() or None
        if "email" in payload:
            cot["email"] = str(payload.get("email") or "").strip() or None
        if "role" in payload:
            cot["role"] = doc_vai(payload, truoc["role"])
        if "isActive" in payload:
            cot["is_active"] = bool(payload.get("isActive"))
        mat_khau = str(payload.get("password") or "")
        if mat_khau:
            if len(mat_khau) < 8:
                raise HTTPException(status_code=400, detail="Mật khẩu phải từ 8 ký tự trở lên.")
            cot["password_hash"] = hash_password(mat_khau)
        if not cot:
            raise HTTPException(status_code=400, detail="Không có gì để sửa.")
        # Hạ vai hoặc khóa tài khoản quản trị CUỐI CÙNG là tự nhốt mình ra ngoài.
        mat_quyen = (cot.get("role", truoc["role"]) != "admin") or (cot.get("is_active", truoc["is_active"]) is False)
        if truoc["role"] == "admin" and truoc["is_active"] and mat_quyen and not con_quan_tri_nao_khong(conn, user_id):
            raise HTTPException(status_code=409, detail="Đây là tài khoản quản trị duy nhất còn hoạt động.")
        sets = ", ".join(f"{k} = %s" for k in cot)
        row = conn.execute(f"UPDATE app_user SET {sets} WHERE id = %s RETURNING *",
                           list(cot.values()) + [user_id]).fetchone()
        theo_doi = {k: v for k, v in cot.items() if k != "password_hash"}
        ghi_nhat_ky(conn, user, "sua", "user", truoc["username"], doi_gi(truoc, theo_doi),
                    "đổi mật khẩu" if "password_hash" in cot else "")
        conn.commit()
    return {"user": user_ra(row)}


@app.delete("/api/users/{user_id}")
def delete_user(user_id: int, user: dict = Depends(nguoi_quan_tri)) -> dict:
    with connect() as conn:
        truoc = conn.execute("SELECT * FROM app_user WHERE id = %s", (user_id,)).fetchone()
        if not truoc:
            raise HTTPException(status_code=404, detail="Không có tài khoản này.")
        if truoc["username"] == user["username"]:
            raise HTTPException(status_code=409, detail="Không xóa được tài khoản đang đăng nhập.")
        if truoc["role"] == "admin" and not con_quan_tri_nao_khong(conn, user_id):
            raise HTTPException(status_code=409, detail="Đây là tài khoản quản trị duy nhất còn hoạt động.")
        conn.execute("DELETE FROM app_user WHERE id = %s", (user_id,))
        ghi_nhat_ky(conn, user, "xoa", "user", truoc["username"],
                    {"role": {"cu": truoc["role"], "moi": None}}, "xóa tài khoản")
        conn.commit()
    return {"deleted": truoc["username"]}


def cau_hinh_ra(cfg: dict) -> dict:
    return {"enabled": cfg["enabled"], "hour": cfg["hour"], "minute": cfg["minute"],
            "keep": cfg["keep"],
            "lastRunAt": stamp(cfg["last_run_at"]) if cfg["last_run_at"] else "",
            "lastStatus": cfg["last_status"] or ""}


@app.get("/api/backup")
def backup_state(user: dict = Depends(nguoi_quan_tri)) -> dict:
    with connect() as conn:
        cfg = doc_cau_hinh_sao_luu(conn)
    files = danh_sach_ban_sao()
    return {"config": cau_hinh_ra(cfg), "files": files,
            "totalBytes": sum(f["bytes"] for f in files), "dir": str(BACKUP_DIR)}


@app.put("/api/backup")
def backup_save(payload: dict, user: dict = Depends(nguoi_quan_tri)) -> dict:
    def so(ten: str, nho: int, lon: int, mac_dinh: int) -> int:
        gia_tri = as_int(payload.get(ten))
        if gia_tri is None:
            return mac_dinh
        if not nho <= gia_tri <= lon:
            raise HTTPException(status_code=400, detail=f"{ten} phải trong khoảng {nho}–{lon}.")
        return gia_tri
    with connect() as conn:
        truoc = doc_cau_hinh_sao_luu(conn)
        cot = {
            "enabled": bool(payload.get("enabled")),
            "hour": so("hour", 0, 23, truoc["hour"]),
            "minute": so("minute", 0, 59, truoc["minute"]),
            "keep": so("keep", 1, 365, truoc["keep"]),
        }
        conn.execute(
            "UPDATE backup_config SET enabled = %s, hour = %s, minute = %s, keep = %s,"
            " updated_at = now() WHERE id = 1",
            (cot["enabled"], cot["hour"], cot["minute"], cot["keep"]),
        )
        ghi_nhat_ky(conn, user, "sua", "backup", None, doi_gi(truoc, cot), "đổi cấu hình sao lưu")
        conn.commit()
        cfg = doc_cau_hinh_sao_luu(conn)
    return {"config": cau_hinh_ra(cfg)}


@app.post("/api/backup/run")
def backup_run(user: dict = Depends(nguoi_quan_tri)) -> dict:
    with connect() as conn:
        cfg = doc_cau_hinh_sao_luu(conn)
        ket = chay_sao_luu(conn, cfg["keep"])
        conn.execute(
            "UPDATE backup_config SET last_run_at = now(), last_status = %s WHERE id = 1",
            (f"chạy tay · {ket['name']}" if ket["ok"] else f"LỖI: {ket.get('error', '')}"[:400],),
        )
        ghi_nhat_ky(conn, user, "sao_luu", "data", None, None,
                    f"sao lưu tay: {ket['name']}" if ket["ok"]
                    else f"sao lưu tay THẤT BẠI: {ket.get('error', '')}"[:300])
        conn.commit()
    if not ket["ok"]:
        raise HTTPException(status_code=500, detail=f"Sao lưu thất bại: {ket.get('error', '')}")
    return {**ket, "files": danh_sach_ban_sao()}


@app.get("/api/audit")
def audit(entity: str = "", entity_id: str = "", limit: int = 100,
          user: dict = Depends(current_user)) -> dict:
    """Nhật ký thao tác. Lọc theo loại đối tượng và theo một bản ghi cụ thể."""
    dieu_kien, tham_so = [], []
    if entity.strip():
        dieu_kien.append("entity = %s")
        tham_so.append(entity.strip())
    if entity_id.strip():
        dieu_kien.append("entity_id = %s")
        tham_so.append(entity_id.strip())
    loc = (" WHERE " + " AND ".join(dieu_kien)) if dieu_kien else ""
    with connect() as conn:
        rows = conn.execute(
            "SELECT at, username, action, entity, entity_id, changes, note"
            f" FROM audit_log{loc} ORDER BY at DESC, id DESC LIMIT %s",
            tham_so + [max(1, min(int(limit or 100), 500))],
        ).fetchall()
    return {"entries": [
        {"at": stamp(row["at"]), "username": row["username"] or "",
         "action": row["action"], "entity": row["entity"], "entityId": row["entity_id"] or "",
         "changes": row["changes"] or {}, "note": row["note"] or ""}
        for row in rows
    ]}


# ------------------------------------------------------- một bản ghi tài sản
# Whitelist trường người dùng được sửa. source_sheet / source_row / review_flags là
# dấu vết lúc nạp file, không cho sửa tay; usage_status_label là chữ nguyên văn của sổ
# nên chỉ bị xóa khi trạng thái đổi (xử lý riêng bên dưới).
ASSET_TEXT = {
    "asset_name", "asset_category", "ip_or_type_raw",
    "capacity", "replacement_target", "handover_status", "purchase_invoice",
    "supplier_code", "supplier_name", "description", "serial",
}
ASSET_DATE = {"usage_start_date", "handover_date", "warranty_end_date"}
ASSET_INT = {"warranty_months", "purchase_price_vnd"}
ASSET_SPECIAL = {
    "usage_status", "datacenter", "current_location", "parent_reference", "ip_address",
    "cluster", "rack_id", "rack_unit", "rack_size_u", "in_store", "asset_type",
}
ASSET_FIELDS = ASSET_TEXT | ASSET_DATE | ASSET_INT | ASSET_SPECIAL

IPV4 = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")


def clean_ip(value: str) -> str | None:
    """Cột ip_address là kiểu INET — chuỗi rác sẽ làm Postgres báo lỗi, chặn sớm cho rõ."""
    raw = str(value or "").strip()
    if not raw:
        return None
    if not IPV4.match(raw) or any(int(part) > 255 for part in raw.split(".")):
        raise HTTPException(status_code=400, detail=f"Địa chỉ IP không hợp lệ: {raw}")
    return raw


def strip_accents(value: str) -> str:
    """Bỏ dấu để so tên không phụ thuộc cách gõ ("Kho" / "kho")."""
    return "".join(ch for ch in unicodedata.normalize("NFD", value)
                   if unicodedata.category(ch) != "Mn")


def ensure_site(conn: psycopg.Connection, name: str) -> None:
    if not name:
        return
    conn.execute(
        "INSERT INTO site (name, kind) VALUES (%s, %s) ON CONFLICT (name) DO NOTHING",
        (name, "datacenter"),
    )


def unit_range(unit: int, size: int | None) -> str:
    """U42 cho thiết bị 1U (hoặc chưa khai số U), U42-43 cho thiết bị 2U."""
    last = unit + max(size or 1, 1) - 1
    return f"U{unit}" if last == unit else f"U{unit}-{last}"


def check_unit_range(conn: psycopg.Connection, rack_id: int, unit: int, size: int | None,
                     exclude: list[str]) -> None:
    """Dải U của thiết bị phải nằm trong rack và không chồng lên dải U của thiết bị khác.
    Thiết bị chưa khai số U được coi là chiếm đúng một U — đúng như cách nó đang hiện ra."""
    last = unit + max(size or 1, 1) - 1
    rack_row = conn.execute("SELECT height_u FROM rack WHERE id = %s", (rack_id,)).fetchone()
    if unit < 1 or last > rack_row["height_u"]:
        raise HTTPException(
            status_code=400,
            detail=(f"Vị trí U phải nằm trong khoảng 1–{rack_row['height_u']} của rack này"
                    + (f" ({unit_range(unit, size)} vượt quá)." if unit >= 1 and last != unit else ".")),
        )
    taken = conn.execute(
        "SELECT asset_id, rack_unit, rack_size_u FROM asset WHERE rack_id = %s AND rack_unit IS NOT NULL"
        " AND rack_unit <= %s AND rack_unit + COALESCE(rack_size_u, 1) - 1 >= %s"
        " AND asset_id <> ALL(%s) ORDER BY rack_unit LIMIT 1",
        (rack_id, last, unit, exclude),
    ).fetchone()
    if taken:
        raise HTTPException(
            status_code=409,
            detail=(f"{unit_range(unit, size)} của rack này đang là chỗ của {taken['asset_id']} "
                    f"({unit_range(taken['rack_unit'], taken['rack_size_u'])})."),
        )


def asset_changes(conn: psycopg.Connection, payload: dict, *, asset_id: str, current: dict | None) -> dict:
    """Payload người dùng -> {cột: giá trị} đã ép kiểu và kiểm tra, chỉ gồm trường được gửi lên."""
    raw = {key: value for key, value in payload.items() if key in ASSET_FIELDS}
    columns: dict[str, Any] = {}
    for key, value in raw.items():
        if key in ASSET_SPECIAL:
            continue
        cleaned = str(value or "").strip()
        if key in ASSET_DATE:
            parsed = as_date(cleaned)
            if cleaned and parsed is None:
                raise HTTPException(status_code=400, detail=f"Ngày không hợp lệ ở trường {key}: {cleaned}")
            columns[key] = parsed
        elif key in ASSET_INT:
            parsed = as_int(cleaned)
            if cleaned and parsed is None:
                raise HTTPException(status_code=400, detail=f"Giá trị phải là số ở trường {key}: {cleaned}")
            columns[key] = parsed
        else:
            columns[key] = cleaned or None

    if "ip_address" in raw:
        columns["ip_address"] = clean_ip(raw["ip_address"])

    if "usage_status" in raw:
        status = str(raw["usage_status"] or "").strip()
        if status:
            known = conn.execute("SELECT code FROM status_catalog WHERE code = %s", (status,)).fetchone()
            if not known:
                raise HTTPException(status_code=400, detail=f"Trạng thái {status} không có trong danh mục.")
        columns["usage_status"] = status or None
        # usage_status_label là chữ NGUYÊN VĂN của sổ Excel. Đổi trạng thái bằng tay thì
        # sổ không còn nói gì về giá trị mới -> để trống, không gán nhãn danh mục vào đó.
        if not current or (current.get("usage_status") or None) != (status or None):
            columns["usage_status_label"] = None

    # Trong kho và đứng ở một site là hai chỗ loại trừ nhau, không thể vừa ở kho vừa ở rack.
    if "in_store" in raw:
        stored = str(raw["in_store"]).strip().lower() in {"1", "true", "yes", "có", "co", "x"}
        columns["in_store"] = stored
        if stored:
            columns.update(datacenter=None, current_location=None,
                           room_id=None, rack_id=None, rack_unit=None)
    if "datacenter" in raw and not columns.get("in_store"):
        site = str(raw["datacenter"] or "").strip()
        ensure_site(conn, site)
        columns["datacenter"] = site or None
        if site:
            columns["in_store"] = False
        if "current_location" not in raw:
            columns["current_location"] = site or None
    if "current_location" in raw:
        columns["current_location"] = str(raw["current_location"] or "").strip() or None

    if "asset_type" in raw:
        # Loại tài sản chọn từ danh mục, không gõ tay -> chặn mã lạ ngay ở API.
        code = str(raw["asset_type"] or "").strip()
        if code and not conn.execute("SELECT 1 FROM asset_type WHERE code = %s", (code,)).fetchone():
            raise HTTPException(status_code=400, detail=f"Loại tài sản {code} không có trong danh mục.")
        columns["asset_type"] = code or None

    if "cluster" in raw:
        # Cụm chọn từ danh mục, không gõ tay -> chặn giá trị lạ ngay ở API.
        name = str(raw["cluster"] or "").strip()
        if name and not conn.execute("SELECT 1 FROM cluster WHERE name = %s", (name,)).fetchone():
            raise HTTPException(status_code=400, detail=f"Cụm {name} không có trong danh mục.")
        columns["cluster"] = name or None

    if "rack_id" in raw and not columns.get("in_store"):
        rack_id = as_int(raw["rack_id"])
        if str(raw["rack_id"] or "").strip() and rack_id is None:
            raise HTTPException(status_code=400, detail=f"Mã rack không hợp lệ: {raw['rack_id']}")
        if rack_id is None:
            columns["rack_id"] = None
            columns["room_id"] = None
        else:
            placement = conn.execute(
                "SELECT r.id, r.room_id, s.name AS site FROM rack r"
                " JOIN room m ON m.id = r.room_id JOIN site s ON s.id = m.site_id WHERE r.id = %s",
                (rack_id,),
            ).fetchone()
            if not placement:
                raise HTTPException(status_code=400, detail=f"Không có rack số {rack_id}.")
            # Rack phải nằm trong chính site đang gán, không thì vị trí tự mâu thuẫn.
            site_now = columns.get("datacenter") if "datacenter" in raw else (current or {}).get("datacenter")
            if site_now and placement["site"] != site_now:
                raise HTTPException(
                    status_code=400,
                    detail=f"Rack {rack_id} thuộc site {placement['site']}, không khớp site {site_now}.",
                )
            columns["rack_id"] = placement["id"]
            columns["room_id"] = placement["room_id"]
    elif "datacenter" in raw and not columns.get("in_store") and (current is None or columns.get("datacenter") != current.get("datacenter")):
        # Đổi site mà không nói gì về rack (vd sửa hàng loạt): rack cũ không còn đúng nữa.
        columns["rack_id"] = None
        columns["room_id"] = None
        columns["rack_unit"] = None

    if "rack_unit" in raw and not columns.get("in_store"):
        unit = as_int(raw["rack_unit"])
        if str(raw["rack_unit"] or "").strip() and unit is None:
            raise HTTPException(status_code=400, detail=f"Vị trí U phải là số: {raw['rack_unit']}")
        columns["rack_unit"] = unit

    # Số U chiếm đi theo thiết bị, không theo rack — nên không bị xoá khi rời rack hay vào kho.
    if "rack_size_u" in raw:
        # So bằng "is None" chứ không bằng "or": số 0 gửi lên là giá trị sai, không phải ô trống.
        size_text = "" if raw["rack_size_u"] is None else str(raw["rack_size_u"]).strip()
        size = as_int(size_text)
        if size_text and (size is None or size < 1):
            raise HTTPException(status_code=400, detail=f"Số U chiếm phải là số nguyên dương: {raw['rack_size_u']}")
        columns["rack_size_u"] = size

    # Vị trí U chỉ có nghĩa khi thiết bị nằm trong một rack, và mỗi U chỉ một thiết bị.
    final_rack = columns["rack_id"] if "rack_id" in columns else (current or {}).get("rack_id")
    final_unit = columns["rack_unit"] if "rack_unit" in columns else (current or {}).get("rack_unit")
    final_size = columns["rack_size_u"] if "rack_size_u" in columns else (current or {}).get("rack_size_u")
    if final_unit is not None:
        if not final_rack:
            raise HTTPException(status_code=400, detail="Có vị trí U thì phải chọn rack trước.")
        # Loại trừ CẢ mã mới lẫn mã hiện tại: lúc đổi mã, hàng trong database vẫn mang mã
        # cũ nên nếu chỉ trừ mã mới thì thiết bị tự thấy chính mình và báo trùng ô U.
        minh_no = [asset_id] + ([current["asset_id"]] if current and current.get("asset_id") else [])
        check_unit_range(conn, final_rack, final_unit, final_size, minh_no)
    elif not final_rack:
        columns["rack_unit"] = None

    if "parent_reference" in raw:
        ref = str(raw["parent_reference"] or "").strip()
        exists = None
        if ref and ref != asset_id:
            exists = conn.execute("SELECT asset_id FROM asset WHERE asset_id = %s", (ref,)).fetchone()
        # Khớp mã -> quan hệ cha thật; không khớp -> chỉ là nhãn cụm, không ép thành cha con.
        columns["parent_asset_id"] = exists["asset_id"] if exists else None
        columns["attachment_label"] = None if exists else (ref or None)

    supplier_code = columns.get("supplier_code")
    if supplier_code:
        conn.execute(
            "INSERT INTO supplier (code, name) VALUES (%s, %s) ON CONFLICT (code) DO NOTHING",
            (supplier_code, columns.get("supplier_name") or supplier_code),
        )
    return columns


def sync_site_ids(conn: psycopg.Connection) -> None:
    conn.execute(
        "UPDATE asset a SET site_id = s.id FROM site s"
        " WHERE s.name = a.datacenter AND a.site_id IS DISTINCT FROM s.id"
    )


def fetch_asset(conn: psycopg.Connection, asset_id: str) -> dict:
    row = conn.execute(ASSET_SELECT + " WHERE a.asset_id = %s", (asset_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail=f"Không có tài sản {asset_id}.")
    return row


def next_pending_code(conn: psycopg.Connection) -> str:
    """Mã tạm cho tài sản chưa biết mã. Lặp cho tới khi ra mã chưa ai dùng, phòng
    trường hợp có người tự gõ đúng một mã CHUA-GAN-#### bằng tay."""
    for _ in range(50):
        number = conn.execute("SELECT nextval('asset_code_seq') AS n").fetchone()["n"]
        code = f"CHUA-GAN-{number:04d}"
        if not conn.execute("SELECT 1 FROM asset WHERE asset_id = %s", (code,)).fetchone():
            return code
    raise HTTPException(status_code=500, detail="Không cấp được mã tạm.")


@app.post("/api/assets", status_code=201)
def create_asset(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    asset_id = str(payload.get("asset_id") or "").strip()
    name = str(payload.get("asset_name") or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Thiếu tên tài sản.")
    with connect() as conn:
        pending = not asset_id
        if pending:
            asset_id = next_pending_code(conn)
        elif conn.execute("SELECT 1 FROM asset WHERE asset_id = %s", (asset_id,)).fetchone():
            raise HTTPException(status_code=409, detail=f"Mã tài sản {asset_id} đã tồn tại.")
        columns = asset_changes(conn, payload, asset_id=asset_id, current=None)
        columns["asset_id"] = asset_id
        columns["asset_name"] = name
        columns["code_pending"] = pending
        columns["origin"] = "manual"      # bản ghi nhập tay, không có dòng nào trong sổ Excel
        names = ", ".join(columns)
        holes = ", ".join(["%s"] * len(columns))
        conn.execute(f"INSERT INTO asset ({names}) VALUES ({holes})", list(columns.values()))
        ghi_nhat_ky(conn, user, "them", "asset", asset_id, doi_gi(None, columns),
                    "mã do hệ thống cấp tạm" if pending else "")
        sync_site_ids(conn)
        conn.commit()
        row = fetch_asset(conn, asset_id)
    return {"asset": asset_row_out(row)}


@app.put("/api/assets/{asset_id}")
def update_asset(asset_id: str, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        current = fetch_asset(conn, asset_id)
        typed = str(payload.get("asset_id") or "").strip()
        # Ô mã để trống với tài sản chưa gán mã = vẫn chưa gán, không phải "xóa mã".
        new_id = typed or asset_id
        if typed and current["code_pending"]:
            columns_extra = {"code_pending": False}
        else:
            columns_extra = {}
        if new_id != asset_id and conn.execute(
            "SELECT 1 FROM asset WHERE asset_id = %s", (new_id,)
        ).fetchone():
            raise HTTPException(status_code=409, detail=f"Mã tài sản {new_id} đã tồn tại.")
        columns = asset_changes(conn, payload, asset_id=new_id, current=current)
        columns.update(columns_extra)
        if "asset_name" in columns and not columns["asset_name"]:
            raise HTTPException(status_code=400, detail="Thiếu tên tài sản.")
        if new_id != asset_id:
            # Đổi mã: các bảng con trỏ tới asset_id nên phải đổi trước khi khóa chính rời đi.
            conn.execute("UPDATE asset SET asset_id = %s WHERE asset_id = %s", (new_id, asset_id))
        if columns:
            sets = ", ".join(f"{key} = %s" for key in columns)
            conn.execute(
                f"UPDATE asset SET {sets}, updated_at = now() WHERE asset_id = %s",
                list(columns.values()) + [new_id],
            )
        ghi_nhat_ky(conn, user, "sua", "asset", new_id, doi_gi(current, columns),
                    f"đổi mã từ {asset_id}" if new_id != asset_id else "")
        sync_site_ids(conn)
        conn.commit()
        row = fetch_asset(conn, new_id)
    return {"asset": asset_row_out(row)}


@app.delete("/api/assets/{asset_id}")
def delete_asset(asset_id: str, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        events = conn.execute(
            "SELECT count(*) AS n FROM asset_event WHERE asset_id = %s", (asset_id,)
        ).fetchone()["n"]
        # Đọc TRƯỚC khi xóa: xóa rồi thì không còn gì để ghi vào nhật ký nữa.
        truoc = conn.execute(
            "SELECT asset_id, asset_name, asset_type, datacenter, parent_asset_id, usage_status"
            " FROM asset WHERE asset_id = %s", (asset_id,)).fetchone()
        result = conn.execute("DELETE FROM asset WHERE asset_id = %s", (asset_id,))
        if not result.rowcount:
            raise HTTPException(status_code=404, detail=f"Không có tài sản {asset_id}.")
        ghi_nhat_ky(conn, user, "xoa", "asset", asset_id,
                    {k: {"cu": None if v is None else str(v), "moi": None}
                     for k, v in dict(truoc).items()} if truoc else None,
                    f"xóa kèm {events} sự kiện" if events else "")
        conn.commit()
    return {"deleted": asset_id, "deletedEvents": events}


# ------------------------------------------------------ sự kiện vòng đời
EVENT_TEXT = {"event_type", "location", "usage_object", "notes"}
EVENT_FIELDS = EVENT_TEXT | {"event_date", "declared_transition_count", "event_sequence"}


def event_changes(payload: dict) -> dict:
    columns: dict[str, Any] = {}
    for key in EVENT_TEXT & payload.keys():
        columns[key] = str(payload[key] or "").strip() or None
    if "event_date" in payload:
        raw = str(payload["event_date"] or "").strip()
        parsed = as_date(raw)
        if raw and parsed is None:
            raise HTTPException(status_code=400, detail=f"Ngày sự kiện không hợp lệ: {raw}")
        columns["event_date"] = parsed
    if "declared_transition_count" in payload:
        raw = str(payload["declared_transition_count"] or "").strip()
        parsed = as_int(raw)
        if raw and parsed is None:
            raise HTTPException(status_code=400, detail=f"Số lần chuyển phải là số: {raw}")
        columns["declared_transition_count"] = parsed
    return columns


@app.post("/api/events", status_code=201)
def create_event(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    asset_id = str(payload.get("asset_id") or "").strip()
    if not asset_id:
        raise HTTPException(status_code=400, detail="Thiếu mã tài sản.")
    with connect() as conn:
        fetch_asset(conn, asset_id)
        columns = event_changes(payload)
        sequence = as_int(payload.get("event_sequence"))
        if sequence is None:
            top = conn.execute(
                "SELECT max(event_sequence) AS top FROM asset_event WHERE asset_id = %s", (asset_id,)
            ).fetchone()["top"]
            sequence = (top or 0) + 1
        if conn.execute(
            "SELECT 1 FROM asset_event WHERE asset_id = %s AND event_sequence = %s", (asset_id, sequence)
        ).fetchone():
            raise HTTPException(status_code=409, detail=f"Tài sản {asset_id} đã có sự kiện số {sequence}.")
        columns["asset_id"] = asset_id
        columns["event_sequence"] = sequence
        columns["origin"] = "manual"
        names = ", ".join(columns)
        holes = ", ".join(["%s"] * len(columns))
        row = conn.execute(
            f"INSERT INTO asset_event ({names}) VALUES ({holes}) RETURNING *",
            list(columns.values()),
        ).fetchone()
        conn.commit()
    return {"event": history_row_out(row)}


@app.put("/api/events/{event_id}")
def update_event(event_id: int, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        current = conn.execute("SELECT * FROM asset_event WHERE id = %s", (event_id,)).fetchone()
        if not current:
            raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện.")
        columns = event_changes(payload)
        target = str(payload.get("asset_id") or current["asset_id"]).strip()
        if target != current["asset_id"]:
            fetch_asset(conn, target)
            top = conn.execute(
                "SELECT max(event_sequence) AS top FROM asset_event WHERE asset_id = %s", (target,)
            ).fetchone()["top"]
            columns["asset_id"] = target
            columns["event_sequence"] = (top or 0) + 1
        if not columns:
            raise HTTPException(status_code=400, detail="Không có gì để sửa.")
        sets = ", ".join(f"{key} = %s" for key in columns)
        row = conn.execute(
            f"UPDATE asset_event SET {sets}, updated_at = now() WHERE id = %s RETURNING *",
            list(columns.values()) + [event_id],
        ).fetchone()
        ghi_nhat_ky(conn, user, "sua", "event", str(event_id), doi_gi(current, columns))
        conn.commit()
    return {"event": history_row_out(row)}


@app.delete("/api/events/{event_id}")
def delete_event(event_id: int, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        truoc = conn.execute("SELECT asset_id, event_date, location FROM asset_event WHERE id = %s",
                             (event_id,)).fetchone()
        result = conn.execute("DELETE FROM asset_event WHERE id = %s", (event_id,))
        if not result.rowcount:
            raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện.")
        ghi_nhat_ky(conn, user, "xoa", "event", str(event_id),
                    {k: {"cu": None if v is None else str(v), "moi": None}
                     for k, v in dict(truoc).items()} if truoc else None)
        conn.commit()
    return {"deleted": event_id}


# ----------------------------------------------------- danh mục trạng thái
TAG_STYLES = {"live", "stock", "warn", "repair", "retired", "idle"}


def status_payload(payload: dict) -> tuple[str, str, str, bool]:
    code = str(payload.get("code") or "").strip()
    label = str(payload.get("label") or "").strip()
    style = str(payload.get("cls") or payload.get("tag_style") or "idle").strip()
    attention = payload.get("attention") in (True, "true", "1", 1)
    if not code or not label:
        raise HTTPException(status_code=400, detail="Mã và tên hiển thị là bắt buộc.")
    if style not in TAG_STYLES:
        raise HTTPException(status_code=400, detail=f"Kiểu hiển thị {style} không hợp lệ.")
    return code, label, style, attention


@app.post("/api/statuses", status_code=201)
def create_status(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    code, label, style, attention = status_payload(payload)
    with connect() as conn:
        if conn.execute("SELECT 1 FROM status_catalog WHERE code = %s", (code,)).fetchone():
            raise HTTPException(status_code=409, detail=f"Mã trạng thái {code} đã tồn tại.")
        top = conn.execute("SELECT max(sort_order) AS top FROM status_catalog").fetchone()["top"]
        conn.execute(
            "INSERT INTO status_catalog (code, label, tag_style, attention, sort_order)"
            " VALUES (%s, %s, %s, %s, %s)",
            (code, label, style, attention, (top or 0) + 1),
        )
        ghi_nhat_ky(conn, user, "them", "status", code, {"label": {"cu": None, "moi": label}})
        conn.commit()
    return {"status": {"code": code, "label": label, "cls": style, "attention": attention}}


@app.put("/api/statuses/{old_code}")
def update_status(old_code: str, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    code, label, style, attention = status_payload(payload)
    with connect() as conn:
        current = conn.execute("SELECT * FROM status_catalog WHERE code = %s", (old_code,)).fetchone()
        if not current:
            raise HTTPException(status_code=404, detail=f"Không có trạng thái {old_code}.")
        moved = 0
        if code != old_code:
            if conn.execute("SELECT 1 FROM status_catalog WHERE code = %s", (code,)).fetchone():
                raise HTTPException(status_code=409, detail=f"Mã trạng thái {code} đã tồn tại.")
            # asset.usage_status là khóa ngoại: thêm mã mới, chuyển tài sản sang, rồi xóa mã cũ.
            conn.execute(
                "INSERT INTO status_catalog (code, label, tag_style, attention, sort_order)"
                " VALUES (%s, %s, %s, %s, %s)",
                (code, label, style, attention, current["sort_order"]),
            )
            moved = conn.execute(
                "UPDATE asset SET usage_status = %s WHERE usage_status = %s", (code, old_code)
            ).rowcount
            conn.execute("DELETE FROM status_catalog WHERE code = %s", (old_code,))
        else:
            conn.execute(
                "UPDATE status_catalog SET label = %s, tag_style = %s, attention = %s WHERE code = %s",
                (label, style, attention, code),
            )
        ghi_nhat_ky(conn, user, "sua", "status", code,
                    {"code": {"cu": old_code, "moi": code}, "label": {"cu": None, "moi": label}},
                    f"chuyển {moved} tài sản sang mã mới" if moved else "")
        conn.commit()
    return {"status": {"code": code, "label": label, "cls": style, "attention": attention}, "movedAssets": moved}


@app.delete("/api/statuses/{code}")
def delete_status(code: str, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        used = conn.execute(
            "SELECT count(*) AS n FROM asset WHERE usage_status = %s", (code,)
        ).fetchone()["n"]
        if used:
            raise HTTPException(
                status_code=409, detail=f"Không xóa được: còn {used} tài sản đang ở trạng thái này."
            )
        result = conn.execute("DELETE FROM status_catalog WHERE code = %s", (code,))
        if not result.rowcount:
            raise HTTPException(status_code=404, detail=f"Không có trạng thái {code}.")
        ghi_nhat_ky(conn, user, "xoa", "status", code)
        conn.commit()
    return {"deleted": code}


# ------------------------------------------------------------ danh mục loại tài sản
def type_payload(payload: dict) -> tuple[str, str, str | None]:
    code = str(payload.get("code") or "").strip()
    label = str(payload.get("label") or "").strip()
    if not code or not label:
        raise HTTPException(status_code=400, detail="Mã và tên hiển thị là bắt buộc.")
    if not re.fullmatch(r"[a-z0-9_]+", code):
        raise HTTPException(
            status_code=400,
            detail=f"Mã loại chỉ gồm chữ thường, số và dấu gạch dưới: {code}",
        )
    return code, label, str(payload.get("note") or "").strip() or None


@app.post("/api/asset-types", status_code=201)
def create_asset_type(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    code, label, note = type_payload(payload)
    with connect() as conn:
        if conn.execute("SELECT 1 FROM asset_type WHERE code = %s", (code,)).fetchone():
            raise HTTPException(status_code=409, detail=f"Mã loại {code} đã tồn tại.")
        top = conn.execute("SELECT max(sort_order) AS top FROM asset_type").fetchone()["top"]
        conn.execute(
            "INSERT INTO asset_type (code, label, note, sort_order) VALUES (%s, %s, %s, %s)",
            (code, label, note, (top or 0) + 1),
        )
        ghi_nhat_ky(conn, user, "them", "asset_type", code, {"label": {"cu": None, "moi": label}})
        conn.commit()
    return {"assetType": {"code": code, "label": label, "note": note or ""}}


@app.put("/api/asset-types/{old_code}")
def update_asset_type(old_code: str, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    code, label, note = type_payload(payload)
    with connect() as conn:
        current = conn.execute("SELECT * FROM asset_type WHERE code = %s", (old_code,)).fetchone()
        if not current:
            raise HTTPException(status_code=404, detail=f"Không có loại {old_code}.")
        moved = 0
        if code != old_code:
            if conn.execute("SELECT 1 FROM asset_type WHERE code = %s", (code,)).fetchone():
                raise HTTPException(status_code=409, detail=f"Mã loại {code} đã tồn tại.")
            conn.execute(
                "UPDATE asset_type SET code = %s, label = %s, note = %s WHERE code = %s",
                (code, label, note, old_code),
            )
            # asset.asset_type là chữ tự do nên phải tự đổi theo, không có khóa ngoại lo giúp.
            moved = conn.execute(
                "UPDATE asset SET asset_type = %s, updated_at = now() WHERE asset_type = %s",
                (code, old_code),
            ).rowcount
        else:
            conn.execute("UPDATE asset_type SET label = %s, note = %s WHERE code = %s",
                         (label, note, old_code))
        ghi_nhat_ky(conn, user, "sua", "asset_type", code,
                    {"code": {"cu": old_code, "moi": code}, "label": {"cu": None, "moi": label}},
                    f"chuyển {moved} tài sản sang mã mới" if moved else "")
        conn.commit()
    return {"assetType": {"code": code, "label": label, "note": note or ""}, "movedAssets": moved}


@app.delete("/api/asset-types/{code}")
def delete_asset_type(code: str, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        used = conn.execute(
            "SELECT count(*) AS n FROM asset WHERE asset_type = %s", (code,)
        ).fetchone()["n"]
        if used:
            raise HTTPException(
                status_code=409, detail=f"Không xóa được: còn {used} tài sản đang thuộc loại này."
            )
        result = conn.execute("DELETE FROM asset_type WHERE code = %s", (code,))
        if not result.rowcount:
            raise HTTPException(status_code=404, detail=f"Không có loại {code}.")
        ghi_nhat_ky(conn, user, "xoa", "asset_type", code)
        conn.commit()
    return {"deleted": code}


# ------------------------------------------------------------------ danh mục cụm
@app.post("/api/clusters", status_code=201)
def create_cluster(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    name = str(payload.get("name") or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Thiếu tên cụm.")
    with connect() as conn:
        if conn.execute("SELECT 1 FROM cluster WHERE name = %s", (name,)).fetchone():
            raise HTTPException(status_code=409, detail=f"Cụm {name} đã có trong danh mục.")
        conn.execute("INSERT INTO cluster (name, note) VALUES (%s, %s)",
                     (name, str(payload.get("note") or "").strip() or None))
        ghi_nhat_ky(conn, user, "them", "cluster", name)
        conn.commit()
    return {"cluster": {"name": name}}


@app.put("/api/clusters/{old_name}")
def update_cluster(old_name: str, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    name = str(payload.get("name") or "").strip()
    note = str(payload.get("note") or "").strip() or None
    if not name:
        raise HTTPException(status_code=400, detail="Thiếu tên cụm.")
    with connect() as conn:
        if not conn.execute("SELECT 1 FROM cluster WHERE name = %s", (old_name,)).fetchone():
            raise HTTPException(status_code=404, detail=f"Không có cụm {old_name}.")
        moved = 0
        if name != old_name:
            if conn.execute("SELECT 1 FROM cluster WHERE name = %s", (name,)).fetchone():
                raise HTTPException(status_code=409, detail=f"Cụm {name} đã có trong danh mục.")
            conn.execute("UPDATE cluster SET name = %s, note = %s WHERE name = %s", (name, note, old_name))
            # asset.cluster là chữ tự do nên phải tự đổi theo, không có khóa ngoại lo giúp.
            moved = conn.execute(
                "UPDATE asset SET cluster = %s, updated_at = now() WHERE cluster = %s", (name, old_name)
            ).rowcount
        else:
            conn.execute("UPDATE cluster SET note = %s WHERE name = %s", (note, old_name))
        ghi_nhat_ky(conn, user, "sua", "cluster", name, {"name": {"cu": old_name, "moi": name}},
                    f"chuyển {moved} tài sản sang cụm mới" if moved else "")
        conn.commit()
    return {"cluster": {"name": name, "note": note or ""}, "movedAssets": moved}


@app.delete("/api/clusters/{name}")
def delete_cluster(name: str, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        used = conn.execute("SELECT count(*) AS n FROM asset WHERE cluster = %s", (name,)).fetchone()["n"]
        if used:
            raise HTTPException(
                status_code=409, detail=f"Không xóa được: còn {used} tài sản đang thuộc cụm này."
            )
        result = conn.execute("DELETE FROM cluster WHERE name = %s", (name,))
        if not result.rowcount:
            raise HTTPException(status_code=404, detail=f"Không có cụm {name}.")
        ghi_nhat_ky(conn, user, "xoa", "cluster", name)
        conn.commit()
    return {"deleted": name}


# ------------------------------------------------------------ vị trí (site / rack)
def split_location_id(location_id: str) -> tuple[str, int]:
    kind, _, raw = location_id.partition("-")
    number = as_int(raw)
    if kind not in {"site", "room", "rack"} or number is None:
        raise HTTPException(status_code=400, detail=f"Mã vị trí không hợp lệ: {location_id}")
    return kind, number


def require_site(conn: psycopg.Connection, name: str) -> dict:
    """Site ở form là ô chọn nên phải có sẵn — không lặng lẽ tạo site mới từ chuỗi gõ nhầm."""
    if not name:
        raise HTTPException(status_code=400, detail="Chưa chọn site.")
    row = conn.execute("SELECT id, name FROM site WHERE name = %s", (name,)).fetchone()
    if not row:
        raise HTTPException(status_code=400, detail=f"Site {name} không có trong danh mục.")
    return row


def resolve_room(conn: psycopg.Connection, site_row: dict, room_id: Any) -> int:
    """Rack phải đứng trong một phòng máy. Chưa xếp phòng thì dùng phòng ngầm định '—'."""
    number = as_int(room_id)
    # KHÔNG khai phòng máy và khai một giá trị đọc không ra là hai chuyện khác nhau. Trước đây
    # cả hai đều rơi vào phòng ngầm định, nên gửi nhầm "room-1" thay vì "1" thì rack lặng lẽ
    # nằm sai chỗ mà không ai biết. Chỉ để trống mới là ý "chưa xếp phòng".
    if number is None and str(room_id or "").strip():
        raise HTTPException(status_code=400, detail=f"Mã phòng máy không đọc được: {room_id}")
    if number is not None:
        found = conn.execute(
            "SELECT id FROM room WHERE id = %s AND site_id = %s", (number, site_row["id"])
        ).fetchone()
        if not found:
            raise HTTPException(
                status_code=400,
                detail=f"Phòng máy đã chọn không thuộc site {site_row['name']}.",
            )
        return found["id"]
    conn.execute(
        "INSERT INTO room (site_id, code) VALUES (%s, %s) ON CONFLICT (site_id, code) DO NOTHING",
        (site_row["id"], "—"),
    )
    return conn.execute(
        "SELECT id FROM room WHERE site_id = %s AND code = %s", (site_row["id"], "—")
    ).fetchone()["id"]


def site_kind(payload: dict, name: str) -> str:
    """Danh mục vị trí chỉ còn datacenter. Kho không phải site — xem cột asset.in_store."""
    return "datacenter"


def save_rack(conn: psycopg.Connection, payload: dict, rack_id: int | None = None) -> int:
    code = str(payload.get("rack") or "").strip()
    if not code:
        raise HTTPException(status_code=400, detail="Thiếu mã rack.")
    site_row = require_site(conn, str(payload.get("site") or "").strip())
    room_id = resolve_room(conn, site_row, payload.get("roomId"))
    height = as_int(payload.get("heightU"))
    if str(payload.get("heightU") or "").strip() and height is None:
        raise HTTPException(status_code=400, detail=f"Số U phải là số: {payload['heightU']}")
    status = str(payload.get("status") or "Đang sử dụng").strip()
    clash = conn.execute(
        "SELECT id FROM rack WHERE room_id = %s AND code = %s", (room_id, code)
    ).fetchone()
    if clash and clash["id"] != rack_id:
        raise HTTPException(status_code=409, detail=f"Rack {code} đã có trong phòng máy này.")
    if rack_id is None:
        return conn.execute(
            "INSERT INTO rack (room_id, code, height_u, status) VALUES (%s, %s, %s, %s) RETURNING id",
            (room_id, code, height or 42, status),
        ).fetchone()["id"]
    conn.execute(
        "UPDATE rack SET room_id = %s, code = %s, height_u = %s, status = %s WHERE id = %s",
        (room_id, code, height or 42, status, rack_id),
    )
    return rack_id


def save_room(conn: psycopg.Connection, payload: dict, room_id: int | None = None) -> int:
    code = str(payload.get("room") or "").strip()
    if not code:
        raise HTTPException(status_code=400, detail="Thiếu mã phòng máy.")
    site_row = require_site(conn, str(payload.get("site") or "").strip())
    name = str(payload.get("roomName") or "").strip() or None
    clash = conn.execute(
        "SELECT id FROM room WHERE site_id = %s AND code = %s", (site_row["id"], code)
    ).fetchone()
    if clash and clash["id"] != room_id:
        raise HTTPException(status_code=409, detail=f"Phòng máy {code} đã có trong {site_row['name']}.")
    if room_id is None:
        return conn.execute(
            "INSERT INTO room (site_id, code, name) VALUES (%s, %s, %s) RETURNING id",
            (site_row["id"], code, name),
        ).fetchone()["id"]
    conn.execute(
        "UPDATE room SET site_id = %s, code = %s, name = %s WHERE id = %s",
        (site_row["id"], code, name, room_id),
    )
    return room_id


@app.post("/api/locations", status_code=201)
def create_location(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    kind = str(payload.get("kind") or "location").strip()
    with connect() as conn:
        if kind == "rack":
            new_id = save_rack(conn, payload)
            conn.commit()
            return {"id": f"rack-{new_id}"}
        if kind == "room":
            new_id = save_room(conn, payload)
            conn.commit()
            return {"id": f"room-{new_id}"}
        name = str(payload.get("site") or "").strip()
        if not name:
            raise HTTPException(status_code=400, detail="Thiếu tên site / datacenter.")
        if conn.execute("SELECT 1 FROM site WHERE name = %s", (name,)).fetchone():
            raise HTTPException(status_code=409, detail=f"Site {name} đã có trong danh mục.")
        row = conn.execute(
            "INSERT INTO site (name, kind, status) VALUES (%s, %s, %s) RETURNING id",
            (name, site_kind(payload, name), str(payload.get("status") or "Đang sử dụng").strip()),
        ).fetchone()
        sync_site_ids(conn)
        conn.commit()
    return {"id": f"site-{row['id']}"}


@app.put("/api/locations/{location_id}")
def update_location(location_id: str, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    kind, number = split_location_id(location_id)
    with connect() as conn:
        if kind == "rack":
            if not conn.execute("SELECT 1 FROM rack WHERE id = %s", (number,)).fetchone():
                raise HTTPException(status_code=404, detail="Không tìm thấy rack.")
            save_rack(conn, payload, rack_id=number)
            conn.commit()
            return {"id": location_id}
        if kind == "room":
            if not conn.execute("SELECT 1 FROM room WHERE id = %s", (number,)).fetchone():
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng máy.")
            save_room(conn, payload, room_id=number)
            conn.commit()
            return {"id": location_id}

        current = conn.execute("SELECT * FROM site WHERE id = %s", (number,)).fetchone()
        if not current:
            raise HTTPException(status_code=404, detail="Không tìm thấy site.")
        name = str(payload.get("site") or "").strip()
        if not name:
            raise HTTPException(status_code=400, detail="Thiếu tên site / datacenter.")
        if name != current["name"] and conn.execute(
            "SELECT 1 FROM site WHERE name = %s", (name,)
        ).fetchone():
            raise HTTPException(status_code=409, detail=f"Site {name} đã có trong danh mục.")
        conn.execute(
            "UPDATE site SET name = %s, kind = %s, status = %s WHERE id = %s",
            (name, site_kind(payload, name), str(payload.get("status") or "Đang sử dụng").strip(), number),
        )
        moved = 0
        if name != current["name"]:
            # Đổi tên site thì tài sản đang ghi tên cũ phải đi theo, không để trỏ vào tên không còn tồn tại.
            moved = conn.execute(
                "UPDATE asset SET datacenter = %s, current_location = %s, updated_at = now()"
                " WHERE datacenter = %s",
                (name, name, current["name"]),
            ).rowcount
        sync_site_ids(conn)
        conn.commit()
    return {"id": location_id, "movedAssets": moved}


@app.delete("/api/locations/{location_id}")
def delete_location(location_id: str, user: dict = Depends(nguoi_ghi)) -> dict:
    kind, number = split_location_id(location_id)
    with connect() as conn:
        if kind == "rack":
            used = conn.execute(
                "SELECT count(*) AS n FROM asset WHERE rack_id = %s", (number,)
            ).fetchone()["n"]
            if used:
                raise HTTPException(
                    status_code=409, detail=f"Không xóa được: còn {used} tài sản đang đặt trong rack này."
                )
            result = conn.execute("DELETE FROM rack WHERE id = %s", (number,))
            if not result.rowcount:
                raise HTTPException(status_code=404, detail="Không tìm thấy rack.")
            conn.commit()
            return {"deleted": location_id}

        if kind == "room":
            racks = conn.execute(
                "SELECT count(*) AS n FROM rack WHERE room_id = %s", (number,)
            ).fetchone()["n"]
            if racks:
                raise HTTPException(
                    status_code=409, detail=f"Không xóa được: còn {racks} rack trong phòng máy này."
                )
            result = conn.execute("DELETE FROM room WHERE id = %s", (number,))
            if not result.rowcount:
                raise HTTPException(status_code=404, detail="Không tìm thấy phòng máy.")
            conn.commit()
            return {"deleted": location_id}

        current = conn.execute("SELECT * FROM site WHERE id = %s", (number,)).fetchone()
        if not current:
            raise HTTPException(status_code=404, detail="Không tìm thấy site.")
        used = conn.execute(
            "SELECT count(*) AS n FROM asset WHERE datacenter = %s", (current["name"],)
        ).fetchone()["n"]
        if used:
            raise HTTPException(
                status_code=409,
                detail=f"Không xóa được: còn {used} tài sản đang ghi vị trí {current['name']}.",
            )
        rooms = conn.execute(
            "SELECT count(*) AS n FROM room WHERE site_id = %s", (number,)
        ).fetchone()["n"]
        if rooms:
            # room/rack nối vào site bằng ON DELETE CASCADE, xóa site là mất luôn cả cây con.
            raise HTTPException(
                status_code=409, detail=f"Không xóa được: còn {rooms} phòng máy trong site này."
            )
        conn.execute("DELETE FROM site WHERE id = %s", (number,))
        conn.commit()
    return {"deleted": location_id}
# ---------------------------------------------------------------- ghi dữ liệu
def prepare_asset(conn: psycopg.Connection, row: dict, all_ids: set[str] | None = None,
                  register: bool = True) -> dict:
    """Một dòng file -> đúng bộ {cột: giá trị} sẽ nằm trong bảng asset.

    Dùng chung cho cả GHI THẬT và XEM TRƯỚC, để bản xem trước không bao giờ nói một đằng
    rồi ghi một nẻo. `register=False` là chế độ xem trước: chỉ tính giá trị, không tạo
    thêm site / cụm / nhà cung cấp / trạng thái trong danh mục.
    """
    asset_id = str(row.get("asset_id", "")).strip()
    parent_raw = str(row.get("parent_reference") or row.get("parent_asset_id") or "").strip()
    if all_ids is None:
        resolves = bool(parent_raw) and bool(
            conn.execute("SELECT 1 FROM asset WHERE asset_id = %s", (parent_raw,)).fetchone()
        )
    else:
        resolves = parent_raw in all_ids
    parent_id = parent_raw if resolves and parent_raw != asset_id else None
    label = "" if parent_id else parent_raw
    # Nhãn không khớp mã nào nhưng TRÙNG TÊN MỘT CỤM đã khai thì đó là CỤM, không phải thiết bị
    # cha. Cụm và vị trí là hai chiều độc lập (một tủ phục vụ nhiều cụm, một cụm trải nhiều tủ)
    # nên đưa về đúng trường cụm, đừng để nằm lẫn ở nhãn cha rồi không ai lọc ra được.
    cum_tu_nhan = ""
    if label:
        found = conn.execute(
            "SELECT name FROM cluster WHERE lower(name) = lower(%s)", (label,)
        ).fetchone()
        if found:
            cum_tu_nhan = found["name"]
            label = ""

    status = str(row.get("usage_status") or "").strip() or None
    if status and register:
        conn.execute(
            "INSERT INTO status_catalog (code, label, sort_order) VALUES (%s, %s, 99) "
            "ON CONFLICT (code) DO NOTHING",
            (status, str(row.get("usage_status_label") or status)),
        )
    stored = str(row.get("in_store") or "").strip().lower() in {"1", "true", "yes", "có", "co", "x"}
    site = "" if stored else str(row.get("datacenter") or "").strip()
    # KHO KHÔNG PHẢI MỘT SITE. File nhập hay ghi "Kho" ở cột Datacenter; nếu cứ thế tạo site
    # thì danh mục Vị trí mọc ra một site rỗng. Coi đó là tín hiệu đang nằm kho.
    if site and strip_accents(site).lower() == "kho":
        stored, site = True, ""
    group = str(row.get("cluster") or "").strip() or cum_tu_nhan
    supplier_code = str(row.get("supplier_code") or "").strip()
    if register and not stored:
        ensure_site(conn, site)
    if register:
        if group:
            # Cụm lạ trong file vẫn phải quản lý được, ghi luôn vào danh mục thay vì bỏ qua.
            # Khóa duy nhất phân biệt hoa thường nên "BACKUP" và "backup" sẽ thành HAI cụm —
            # dùng lại tên đã có nếu chỉ khác cách viết, đừng đẻ thêm bản ghi trùng nghĩa.
            da_co = conn.execute(
                "SELECT name FROM cluster WHERE lower(name) = lower(%s)", (group,)
            ).fetchone()
            if da_co:
                group = da_co["name"]
            else:
                conn.execute("INSERT INTO cluster (name) VALUES (%s) ON CONFLICT (name) DO NOTHING", (group,))
        kind = str(row.get("asset_type") or "").strip()
        if kind:
            conn.execute(
                "INSERT INTO asset_type (code, label, sort_order) VALUES (%s, %s, 50)"
                " ON CONFLICT (code) DO NOTHING", (kind, kind))
        if supplier_code:
            conn.execute(
                "INSERT INTO supplier (code, name) VALUES (%s, %s) ON CONFLICT (code) DO NOTHING",
                (supplier_code, str(row.get("supplier_name") or supplier_code)),
            )

    rack_code = str(row.get("rack") or "").strip()
    rack_id = room_id = None
    rack_unit = as_int(row.get("rack_unit"))
    rack_size = as_int(row.get("rack_size_u"))
    if rack_code and site and not stored:
        found = conn.execute(
            "SELECT r.id, r.room_id FROM rack r JOIN room m ON m.id = r.room_id"
            " JOIN site s ON s.id = m.site_id WHERE s.name = %s AND r.code = %s",
            (site, rack_code),
        ).fetchone()
        if found:
            rack_id, room_id = found["id"], found["room_id"]
    if rack_id is None:
        rack_unit = None      # không có rack thì vị trí U vô nghĩa, không giữ lại

    values = {
        "asset_id": asset_id,
        "code_pending": str(row.get("code_pending") or "").strip() in {"1", "true", "yes"},
        "asset_name": str(row.get("asset_name") or asset_id),
        "asset_type": str(row.get("asset_type") or "") or None,
        "asset_category": str(row.get("asset_category") or "") or None,
        "ip_address": str(row.get("ip_address") or "").strip() or None,
        "ip_or_type_raw": str(row.get("ip_or_type_raw") or "") or None,
        "cluster": group or None,
        "in_store": stored,
        "datacenter": site or None,
        "current_location": None if stored else (str(row.get("current_location") or site or "") or None),
        "rack_id": rack_id,
        "room_id": room_id,
        "rack_unit": rack_unit,
        "parent_asset_id": parent_id,
        "attachment_label": label or None,
        "capacity": str(row.get("capacity") or "") or None,
        "replacement_target": str(row.get("replacement_target") or "") or None,
        "usage_status": status,
        "usage_status_label": str(row.get("usage_status_label") or "") or None,
        "usage_start_date": as_date(row.get("usage_start_date")),
        "handover_date": as_date(row.get("handover_date")),
        "handover_status": str(row.get("handover_status") or "") or None,
        "purchase_invoice": str(row.get("purchase_invoice") or "") or None,
        "purchase_price_vnd": as_int(row.get("purchase_price_vnd")),
        "supplier_code": supplier_code or None,
        "supplier_name": str(row.get("supplier_name") or "") or None,
        "warranty_months": as_int(row.get("warranty_months")),
        "warranty_end_date": as_date(row.get("warranty_end_date")),
        "serial": str(row.get("serial") or "") or None,
        "description": str(row.get("description") or "") or None,
        "source_sheet": str(row.get("source_sheet") or "") or None,
        "source_row": as_int(row.get("source_row")),
        "review_flags": as_flags(row.get("review_flags")),
    }
    # Cột này mới có sau: file nhập cũ không mang nó thì GIỮ giá trị đang có, không xoá trắng.
    if "rack_size_u" in row:
        values["rack_size_u"] = rack_size
    return values


# Hai nguồn đánh mã độc lập nhau: người gõ tay vào sổ, và ứng dụng sinh tự động từ hiện
# trạng thật. Cùng một mã ở hai nguồn là HAI VẬT KHÁC NHAU, không phải một vật được sửa.
# Nếu không phân biệt, một lần nhập sổ sẽ lặng lẽ đè lên tài sản đang lắp trong máy và
# ứng dụng chỉ báo "cập nhật" như mọi lần sửa bình thường.
def code_conflict(stored: dict | None, row: dict) -> str:
    """Trả lý do nếu mã này đã thuộc về một NGUỒN KHÁC; chuỗi rỗng nghĩa là nhập bình thường."""
    if not stored:
        return ""
    cu_nguon = str(stored.get("source_sheet") or "").strip()
    moi_nguon = str(row.get("source_sheet") or "").strip()
    # Thiếu dấu vết nguồn ở một trong hai phía thì không kết luận được -> để yên, không chặn.
    if not cu_nguon or not moi_nguon or cu_nguon == moi_nguon:
        return ""
    cho = stored.get("parent_asset_id") or stored.get("datacenter") or ""
    return (f"mã này đang là «{stored.get('asset_name') or stored['asset_id']}»"
            f"{f' lắp trong {cho}' if stored.get('parent_asset_id') else (f' tại {cho}' if cho else '')}"
            f", nguồn {cu_nguon} — file đang nhập có nguồn {moi_nguon}")


def upsert_assets(conn: psycopg.Connection, rows: list[dict], skip: set[str] | None = None,
                  allow_conflicts: bool = False) -> dict:
    skip = skip or set()
    stored = {row["asset_id"]: row for row in conn.execute(
        "SELECT asset_id, asset_name, source_sheet, parent_asset_id, datacenter FROM asset").fetchall()}
    known = set(stored)
    # Bỏ chuỗi rỗng: dòng để trống mã sẽ được cấp mã tạm sau, nhưng nếu để "" lọt vào đây
    # thì một parent_reference rỗng lại "khớp" với nó và bị ghi thành parent_asset_id = ''.
    incoming_ids = {ma for row in rows if (ma := str(row.get("asset_id", "")).strip())}
    all_ids = known | incoming_ids
    added = updated = skipped = 0
    conflicts: list[str] = []
    for row in rows:
        asset_id = str(row.get("asset_id", "")).strip()
        if not asset_id:
            # Dòng không có mã: cấp mã tạm thay vì lặng lẽ bỏ qua cả dòng dữ liệu.
            asset_id = next_pending_code(conn)
            row = {**row, "asset_id": asset_id, "code_pending": "1"}
        if asset_id in skip:
            skipped += 1
            continue
        va_cham = code_conflict(stored.get(asset_id), row)
        if va_cham and not allow_conflicts:
            # KHÔNG ghi đè. Bỏ qua và báo tên ra, để người nhập biết chính xác cái gì đã được cứu.
            conflicts.append(f"{asset_id}: {va_cham}")
            skipped += 1
            continue
        values = prepare_asset(conn, row, all_ids=all_ids, register=True)
        names = list(values)
        assignments = ", ".join(f"{name} = EXCLUDED.{name}" for name in names if name != "asset_id")
        conn.execute(
            f"INSERT INTO asset ({', '.join(names)}) VALUES ({', '.join(['%s'] * len(names))})"
            f" ON CONFLICT (asset_id) DO UPDATE SET {assignments}, updated_at = now()",
            list(values.values()),
        )
        if asset_id in known:
            updated += 1
        else:
            added += 1
            known.add(asset_id)
    sync_site_ids(conn)
    return {"added": added, "updated": updated, "skipped": skipped, "conflicts": conflicts}


def prepare_event(row: dict) -> dict:
    return {
        "asset_id": str(row.get("asset_id", "")).strip(),
        "event_sequence": as_int(row.get("event_sequence")) or 0,
        "event_type": str(row.get("event_type") or "") or None,
        "event_date": as_date(row.get("event_date")),
        "location": str(row.get("location") or "") or None,
        "usage_object": str(row.get("usage_object") or "") or None,
        "notes": str(row.get("notes") or "") or None,
        "declared_transition_count": as_int(row.get("declared_transition_count")),
        "source_column": str(row.get("source_column") or "") or None,
        "source_row": as_int(row.get("source_row")),
        "review_flags": as_flags(row.get("review_flags")),
    }


def upsert_events(conn: psycopg.Connection, rows: list[dict], skip: set[str] | None = None) -> dict:
    skip = skip or set()
    known = {row["asset_id"] for row in conn.execute("SELECT asset_id FROM asset").fetchall()}
    applied = unknown = skipped = 0
    for row in rows:
        values = prepare_event(row)
        if not values["asset_id"] or values["asset_id"] not in known:
            unknown += 1
            continue
        if f"{values['asset_id']}#{values['event_sequence']}" in skip:
            skipped += 1
            continue
        names = list(values)
        assignments = ", ".join(
            f"{name} = EXCLUDED.{name}" for name in names if name not in {"asset_id", "event_sequence"}
        )
        conn.execute(
            f"INSERT INTO asset_event ({', '.join(names)}) VALUES ({', '.join(['%s'] * len(names))})"
            f" ON CONFLICT (asset_id, event_sequence) DO UPDATE SET {assignments}, updated_at = now()",
            list(values.values()),
        )
        applied += 1
    return {"added": applied, "updated": 0, "skipped": skipped + unknown, "applied": applied,
            "skipped_unknown_asset": unknown, "skipped_by_user": skipped}
# ------------------------------------------------------- template XLSX để nhập liệu
# Sinh tại chỗ từ danh mục đang có trong database, nên ô chọn trong file luôn khớp
# với site / rack / cụm / trạng thái thật, không phải bản cứng chép tay.
ASSET_COLUMN_GUIDE: dict[str, tuple[str, str]] = {
    "asset_id": ("Mã tài sản", "Khóa duy nhất. Trùng mã = cập nhật đè bản ghi cũ. Bỏ trống thì hệ thống cấp mã tạm CHUA-GAN-#### và đánh dấu là chưa gán mã."),
    "code_pending": ("Chưa gán mã", "Điền 1 nếu mã ở cột bên trái chỉ là mã tạm. Hệ thống tự điền, không cần gõ tay."),
    "asset_name": ("Tên tài sản", "BẮT BUỘC. Tên đầy đủ để người vận hành nhận ra thiết bị."),
    "asset_type": ("Loại thiết bị", "Chọn từ danh sách. Bỏ trống = chưa xác định."),
    "asset_category": ("Nhóm", "Tự do. Ví dụ: component, device."),
    "ip_address": ("Địa chỉ IP", "Dạng 10.0.0.1. Sai định dạng sẽ bị từ chối cả dòng."),
    "ip_or_type_raw": ("Giá trị gốc cột IP", "Chữ nguyên văn lúc nhập lần đầu. Để trống khi nhập mới."),
    "cluster": ("Cụm vận hành", "Chọn từ danh sách. Tên mới sẽ được thêm vào danh mục."),
    "in_store": ("Đang nằm trong kho", "Điền 1 nếu thiết bị đang ở kho. Khi đó BỎ TRỐNG Site, Rack, Vị trí U — kho không phải một site."),
    "datacenter": ("Site / Datacenter", "Chọn từ danh sách. Tên mới sẽ được thêm vào danh mục."),
    "current_location": ("Vị trí hiện tại", "Bỏ trống thì hệ thống lấy theo Site."),
    "rack": ("Mã rack", "Chọn từ danh sách. Rack phải có sẵn trong đúng Site ở trên."),
    "rack_unit": ("Vị trí U trong rack", "Chỉ chữ số. U1 là đáy rack. Mỗi U chỉ một thiết bị. Bỏ trống nếu chưa xếp."),
    "rack_size_u": ("Số U chiếm", "Chỉ chữ số. Máy 2U đặt ở U42 thì chiếm U42–43. Bỏ trống nếu chưa biết."),
    "parent_reference": ("Thiết bị cha / nhãn cụm", "Khớp mã tài sản có thật = quan hệ cha-con; không khớp = giữ làm nhãn."),
    "capacity": ("Dung lượng / cấu hình", "Tự do. Ví dụ: 1.92TB, 2x Xeon Gold."),
    "replacement_target": ("Nơi thay thế", "Thiết bị hoặc vị trí sẽ thay thế cho thiết bị này."),
    "usage_status": ("Trạng thái", "Chọn từ danh sách. Phải là MÃ trạng thái, không phải tên hiển thị."),
    "usage_status_label": ("Chữ trạng thái nguyên văn", "Chữ trong sổ gốc. Để trống khi nhập mới."),
    "usage_start_date": ("Ngày bắt đầu sử dụng", "Dạng YYYY-MM-DD. Không có thì để TRỐNG, đừng đoán."),
    "handover_date": ("Ngày bàn giao", "Dạng YYYY-MM-DD."),
    "handover_status": ("Tình trạng bàn giao", "Tự do. Ví dụ: Đã bàn giao."),
    "purchase_invoice": ("Số hóa đơn", "Tự do."),
    "purchase_price_vnd": ("Giá mua (VNĐ)", "Chỉ chữ số, không dấu chấm phân cách."),
    "supplier_code": ("Mã nhà cung cấp", "Tự do."),
    "supplier_name": ("Tên nhà cung cấp", "Tự do."),
    "warranty_months": ("Bảo hành (tháng)", "Chỉ chữ số."),
    "warranty_end_date": ("Ngày hết bảo hành", "Dạng YYYY-MM-DD."),
    "serial": ("Số serial / license", "Số hãng cấp riêng cho máy này. Không sửa hàng loạt được."),
    "description": ("Mô tả", "Tự do."),
    "source_sheet": ("Sheet nguồn", "Dấu vết truy ngược về sổ gốc. Để trống khi nhập mới."),
    "source_row": ("Dòng nguồn", "Dấu vết truy ngược về sổ gốc. Để trống khi nhập mới."),
    "review_flags": ("Cờ cần rà soát", "Hệ thống tự gắn khi bóc dữ liệu. Để trống khi nhập mới."),
}
HISTORY_COLUMN_GUIDE: dict[str, tuple[str, str]] = {
    "asset_id": ("Mã tài sản", "BẮT BUỘC. Phải là mã đã có trong hệ thống, không thì dòng bị bỏ qua."),
    "event_sequence": ("Số thứ tự sự kiện", "BẮT BUỘC. Cùng một mã tài sản thì số này phải khác nhau."),
    "event_type": ("Loại sự kiện", "Tự do. Ví dụ: handover_received."),
    "event_date": ("Ngày sự kiện", "Dạng YYYY-MM-DD. Không rõ thì để TRỐNG."),
    "location": ("Vị trí", "Nơi thiết bị nằm tại thời điểm của sự kiện."),
    "usage_object": ("Đối tượng / mục đích sử dụng", "Tự do."),
    "notes": ("Mô tả", "Tự do."),
    "declared_transition_count": ("Số lần chuyển ghi trong sổ", "Chỉ chữ số."),
    "source_column": ("Cột nguồn", "Dấu vết truy ngược. Để trống khi nhập mới."),
    "source_row": ("Dòng nguồn", "Dấu vết truy ngược. Để trống khi nhập mới."),
    "review_flags": ("Cờ cần rà soát", "Hệ thống tự gắn. Để trống khi nhập mới."),
}
TEMPLATE_ROWS = 500      # số dòng được gắn sẵn ô chọn trong Excel

GUIDE_TEXT = [
    ("Template nhập liệu Device Management", True),
    ("", False),
    ("Dữ liệu của hệ thống nằm trong database. File này chỉ là đường nạp dữ liệu vào —", False),
    ("điền xong thì vào màn Nhập / Xuất, tải file này lên, hệ thống ghi vào database.", False),
    ("", False),
    ("Cách dùng", True),
    ("1. Điền vào sheet \"Tài sản\" và/hoặc sheet \"Lịch sử\". Đừng đổi dòng tiêu đề.", False),
    ("2. Rê chuột vào ô tiêu đề để xem giải thích từng cột.", False),
    ("3. Các ô có mũi tên xổ xuống thì CHỌN, đừng gõ tay — gõ sai sẽ bị từ chối.", False),
    ("4. Tải lên ở màn Nhập / Xuất. Cùng một file dùng được cho cả hai ô nhập:", False),
    ("   hệ thống tự tìm đúng sheet theo bộ cột.", False),
    ("", False),
    ("Quy tắc quan trọng", True),
    ("• Trùng asset_id = CẬP NHẬT ĐÈ bản ghi cũ, không phải thêm mới.", False),
    ("• Ô nào không có dữ liệu thì để TRỐNG. Không điền \"chưa rõ\", \"N/A\" hay giá trị đoán —", False),
    ("  hệ thống hiển thị ô trống là Null, như vậy đúng hơn là một giá trị bịa.", False),
    ("• Ngày luôn viết YYYY-MM-DD (ví dụ 2026-09-14).", False),
    ("• Cột usage_status điền MÃ (in_use), không phải tên hiển thị (Đang vận hành).", False),
    ("• Sheet \"Lịch sử\": asset_id phải là mã đã có; dòng không khớp mã sẽ bị bỏ qua và báo lại.", False),
    ("• Rack phải có sẵn trong đúng Site ghi ở cùng dòng, nếu không thì ô rack bị bỏ qua.", False),
    ("", False),
    ("Các cột source_sheet, source_row, review_flags, usage_status_label là dấu vết của lần", False),
    ("bóc dữ liệu từ sổ Excel gốc. Khi nhập bản ghi mới thì để trống.", False),
]


def build_template(conn: psycopg.Connection) -> bytes:
    try:
        from openpyxl import Workbook
        from openpyxl.comments import Comment
        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.utils import get_column_letter
        from openpyxl.worksheet.datavalidation import DataValidation
    except ImportError:  # pragma: no cover
        raise HTTPException(status_code=500, detail="Máy chủ chưa cài openpyxl để dựng template.")

    statuses = conn.execute("SELECT code, label FROM status_catalog ORDER BY sort_order, code").fetchall()
    sites = conn.execute("SELECT name FROM site ORDER BY name").fetchall()
    racks = conn.execute(
        "SELECT DISTINCT r.code FROM rack r ORDER BY r.code"
    ).fetchall()
    clusters = conn.execute("SELECT name FROM cluster ORDER BY name").fetchall()
    types = conn.execute("SELECT code FROM asset_type ORDER BY sort_order, code").fetchall()

    head_fill = PatternFill("solid", fgColor="1F3B36")
    head_font = Font(color="FFFFFF", bold=True, size=10)
    note_font = Font(color="6B7672", italic=True, size=10)

    book = Workbook()
    guide = book.active
    guide.title = "Hướng dẫn"
    guide.column_dimensions["A"].width = 100
    for index, (line, strong) in enumerate(GUIDE_TEXT, start=1):
        cell = guide.cell(row=index, column=1, value=line)
        cell.font = Font(bold=True, size=13) if strong else Font(size=11)
        cell.alignment = Alignment(vertical="center")

    def data_sheet(title: str, columns: list[str], guide_map: dict[str, tuple[str, str]]):
        sheet = book.create_sheet(title)
        for index, name in enumerate(columns, start=1):
            cell = sheet.cell(row=1, column=index, value=name)
            cell.fill = head_fill
            cell.font = head_font
            cell.alignment = Alignment(horizontal="left", vertical="center")
            label, hint = guide_map.get(name, (name, ""))
            cell.comment = Comment(f"{label}\n\n{hint}", "Device Management", height=120, width=280)
            sheet.column_dimensions[get_column_letter(index)].width = max(14, min(30, len(name) + 8))
        sheet.freeze_panes = "A2"
        sheet.auto_filter.ref = f"A1:{get_column_letter(len(columns))}1"
        return sheet

    assets_sheet = data_sheet("Tài sản", ASSET_COLUMNS, ASSET_COLUMN_GUIDE)
    history_sheet = data_sheet("Lịch sử", HISTORY_COLUMNS, HISTORY_COLUMN_GUIDE)

    # Sheet danh mục: vừa để tra cứu, vừa là nguồn cho các ô chọn bên sheet Tài sản.
    catalog = book.create_sheet("Danh mục")
    lists = [
        ("Mã trạng thái", [row["code"] for row in statuses]),
        ("Tên trạng thái", [row["label"] for row in statuses]),
        ("Site / Datacenter", [row["name"] for row in sites]),
        ("Mã rack", [row["code"] for row in racks]),
        ("Cụm vận hành", [row["name"] for row in clusters]),
        ("Loại thiết bị", [row["code"] for row in types]),
    ]
    for index, (title, values) in enumerate(lists, start=1):
        letter = get_column_letter(index)
        catalog.column_dimensions[letter].width = max(18, len(title) + 6)
        head = catalog.cell(row=1, column=index, value=title)
        head.fill = head_fill
        head.font = head_font
        for offset, value in enumerate(values, start=2):
            catalog.cell(row=offset, column=index, value=value)
    catalog.cell(row=len(statuses) + 3, column=1,
                 value="Bảng này sinh từ dữ liệu đang có trong hệ thống lúc tải file.").font = note_font

    # Gắn ô chọn cho các cột có danh mục. Cột rỗng thì bỏ qua, tránh tạo ô chọn không có gì.
    column_index = {name: position for position, name in enumerate(ASSET_COLUMNS, start=1)}
    bindings = [
        ("usage_status", 1, len(statuses)),
        ("datacenter", 3, len(sites)),
        ("rack", 4, len(racks)),
        ("cluster", 5, len(clusters)),
        ("asset_type", 6, len(types)),
    ]
    for name, catalog_column, count in bindings:
        if not count or name not in column_index:
            continue
        letter = get_column_letter(catalog_column)
        rule = DataValidation(
            type="list",
            formula1=f"='Danh mục'!${letter}$2:${letter}${count + 1}",
            allow_blank=True,
            errorTitle="Giá trị ngoài danh mục",
            error="Hãy chọn một giá trị trong danh sách xổ xuống.",
        )
        assets_sheet.add_data_validation(rule)
        target = get_column_letter(column_index[name])
        rule.add(f"{target}2:{target}{TEMPLATE_ROWS + 1}")

    # "Hướng dẫn" để đầu tiên: mở file ra là thấy luật điền trước khi gõ dòng nào.
    # Thứ tự sheet không ảnh hưởng lúc nhập vì hệ thống dò sheet theo bộ cột.
    book.active = 0
    buffer = io.BytesIO()
    book.save(buffer)
    return buffer.getvalue()


@app.get("/api/template/device-import-template.xlsx")
def download_template(user: dict = Depends(current_user)) -> StreamingResponse:
    with connect() as conn:
        payload = build_template(conn)
    return StreamingResponse(
        iter([payload]),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": 'attachment; filename="device-import-template.xlsx"'},
    )


# ------------------------------------------------- nhập file (CSV / XLSX)
MAX_UPLOAD = 10 * 1024 * 1024


def rows_from_csv(raw: bytes) -> list[dict]:
    try:
        body = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="File CSV phải mã hóa UTF-8.")
    return list(csv.DictReader(io.StringIO(body)))


def sheet_header(sheet) -> list[str]:
    for line in sheet.iter_rows(min_row=1, max_row=1, values_only=True):
        return [str(cell).strip() if cell is not None else "" for cell in line]
    return []


def rows_from_xlsx(raw: bytes, want: str) -> list[dict]:
    """File template có nhiều sheet (Tài sản / Lịch sử / Danh mục / Hướng dẫn) nên phải
    chọn sheet theo bộ cột chứ không cứ lấy sheet đầu tiên."""
    try:
        from openpyxl import load_workbook
    except ImportError:  # pragma: no cover — chỉ xảy ra nếu image chưa cài openpyxl
        raise HTTPException(status_code=500, detail="Máy chủ chưa cài openpyxl để đọc XLSX.")
    try:
        book = load_workbook(io.BytesIO(raw), read_only=True, data_only=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Không đọc được file XLSX.")

    picked = None
    for title in book.sheetnames:
        header = set(sheet_header(book[title]))
        if "asset_id" not in header:
            continue
        is_history = "event_sequence" in header
        if (want == "history") == is_history:
            picked = book[title]
            break
    if picked is None:
        book.close()
        which = "asset_id + event_sequence" if want == "history" else "asset_id"
        raise HTTPException(status_code=400, detail=f"Không có sheet nào chứa cột {which}.")

    rows = picked.iter_rows(values_only=True)
    header = [str(cell).strip() if cell is not None else "" for cell in next(rows, ())]
    out = []
    for line in rows:
        record = {}
        for index, name in enumerate(header):
            if not name:
                continue
            value = line[index] if index < len(line) else None
            record[name] = "" if value is None else text(value).strip()
        if any(record.values()):
            out.append(record)
    book.close()
    return out


def read_upload(upload: UploadFile, want: str) -> tuple[list[dict], str]:
    raw = upload.file.read()
    if len(raw) > MAX_UPLOAD:
        raise HTTPException(status_code=413, detail="File vượt quá 10MB.")
    name = (upload.filename or "").lower()
    kind = "xlsx" if name.endswith((".xlsx", ".xlsm")) else "csv"
    rows = rows_from_xlsx(raw, want) if kind == "xlsx" else rows_from_csv(raw)
    if not rows:
        raise HTTPException(status_code=400, detail="File không có dòng dữ liệu nào.")
    if "asset_id" not in rows[0]:
        raise HTTPException(status_code=400, detail="Thiếu cột asset_id.")
    if want == "history" and "event_sequence" not in rows[0]:
        raise HTTPException(status_code=400, detail="Thiếu cột event_sequence.")
    return rows, kind


def ghi_nhat_ky(conn: psycopg.Connection, user: dict, action: str, entity: str,
                entity_id: str | None = None, changes: dict | None = None, note: str = "") -> None:
    """Ghi một dòng nhật ký thao tác. KHÔNG bao giờ để lỗi ghi nhật ký làm hỏng việc chính."""
    try:
        conn.execute(
            "INSERT INTO audit_log (username, action, entity, entity_id, changes, note)"
            " VALUES (%s,%s,%s,%s,%s,%s)",
            (user.get("username"), action, entity, entity_id,
             Json(changes) if changes else None, note or None),
        )
    except Exception:
        pass


def doi_gi(truoc: dict | None, cot: dict) -> dict:
    """{cột: {cu, moi}} — chỉ giữ cột THỰC SỰ đổi giá trị, để nhật ký không đầy dòng vô nghĩa."""
    ra: dict = {}
    for ten, moi in (cot or {}).items():
        cu_gt = (truoc or {}).get(ten)
        if str(cu_gt if cu_gt is not None else "") != str(moi if moi is not None else ""):
            ra[ten] = {"cu": None if cu_gt is None else str(cu_gt),
                       "moi": None if moi is None else str(moi)}
    return ra


def log_import(conn: psycopg.Connection, kind: str, upload: UploadFile, file_type: str,
               rows: int, result: dict, username: str) -> None:
    conn.execute(
        "INSERT INTO import_log (kind, file_name, file_type, rows_read, added, updated, skipped, username)"
        " VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
        (kind, upload.filename or "—", file_type, rows, result.get("added", 0),
         result.get("updated", 0), result.get("skipped", 0), username),
    )


@app.post("/api/import/assets")
def import_assets(file: UploadFile = File(...), skip: str = Form(""),
                  allow_conflicts: str = Form(""),
                  user: dict = Depends(nguoi_ghi)) -> dict:
    rows, file_type = read_upload(file, "assets")
    # Ghi đè tài sản của nguồn khác phải là hành động CỐ Ý, khai rõ trên từng lần nhập.
    cho_phep = str(allow_conflicts).strip().lower() in {"1", "true", "yes", "có", "co"}
    with connect() as conn:
        result = upsert_assets(conn, rows, skip_set(skip), allow_conflicts=cho_phep)
        log_import(conn, "assets", file, file_type, len(rows), result, user["username"])
        ghi_nhat_ky(conn, user, "nhap", "asset", None, None,
                    f"nhập {file.filename or '—'}: thêm {result['added']}, ghi đè {result['updated']}"
                    f", bỏ qua {result['skipped']}"
                    + (f", {len(result.get('conflicts') or [])} đụng mã không nạp"
                       if result.get('conflicts') else "")
                    + (" · CÓ KHAI allow_conflicts" if cho_phep else ""))
        conn.commit()
    return {"rows": len(rows), "fileType": file_type, **result}


@app.post("/api/import/history")
def import_history(file: UploadFile = File(...), skip: str = Form(""),
                   user: dict = Depends(nguoi_ghi)) -> dict:
    rows, file_type = read_upload(file, "history")
    with connect() as conn:
        result = upsert_events(conn, rows, skip_set(skip))
        log_import(conn, "history", file, file_type, len(rows), result, user["username"])
        ghi_nhat_ky(conn, user, "nhap", "event", None, None,
                    f"nhập lịch sử {file.filename or '—'}: {result.get('added', 0)} sự kiện")
        conn.commit()
    return {"rows": len(rows), "fileType": file_type, **result}


# ------------------------------------------- xem trước thay đổi khi nhập file
# Nhập file là thao tác ghi đè, nên phải cho xem trước: cái gì thêm mới, cái gì bị
# đè và đè bằng giá trị nào. Chọn bỏ qua thì bản ghi đó giữ nguyên.
# Cả xem trước lẫn ghi thật đều đi qua cùng một hàm dựng giá trị, không có đường thứ hai.

# Chỉ so những cột người nhập thực sự đưa vào; site_id/room_id là khóa nội bộ, không so.
ASSET_DIFF_FIELDS = [
    "asset_name", "asset_type", "asset_category", "ip_address", "ip_or_type_raw",
    "cluster", "datacenter", "current_location", "rack", "rack_unit", "rack_size_u", "parent_reference",
    "capacity", "replacement_target", "usage_status", "usage_status_label",
    "usage_start_date", "handover_date", "handover_status", "purchase_invoice",
    "purchase_price_vnd", "supplier_code", "supplier_name", "warranty_months",
    "warranty_end_date", "serial", "description", "source_sheet", "source_row", "review_flags",
]
EVENT_DIFF_FIELDS = [
    "event_type", "event_date", "location", "usage_object", "notes",
    "declared_transition_count", "source_column", "source_row", "review_flags",
]


def field_label(name: str, history: bool = False) -> str:
    guide = HISTORY_COLUMN_GUIDE if history else ASSET_COLUMN_GUIDE
    return guide.get(name, (name, ""))[0]


def asset_compare_row(conn: psycopg.Connection, row: dict) -> dict:
    """Dòng file -> bộ giá trị sẽ nằm trong database, ở dạng chuỗi để so sánh."""
    prepared = prepare_asset(conn, row, all_ids=None, register=False)
    out = {key: text(value) for key, value in prepared.items()}
    out["parent_reference"] = text(prepared.get("parent_asset_id") or prepared.get("attachment_label"))
    out["rack"] = text(row.get("rack") or "").strip()
    return out


def existing_compare_row(row: dict) -> dict:
    out = {key: text(row.get(key)) for key in ASSET_DIFF_FIELDS}
    out["parent_reference"] = text(row.get("parent_asset_id") or row.get("attachment_label"))
    out["rack"] = text(row.get("rack_code"))
    return out


def diff_of(before: dict, after: dict, fields: list[str], history: bool = False) -> list[dict]:
    changes = []
    for name in fields:
        old = (before.get(name) or "").strip()
        new = (after.get(name) or "").strip()
        if old != new:
            changes.append({"field": name, "label": field_label(name, history), "old": old, "new": new})
    return changes


@app.post("/api/import/preview")
def import_preview(kind: str = Form("assets"), file: UploadFile = File(...),
                   user: dict = Depends(nguoi_ghi)) -> dict:
    want = "history" if kind == "history" else "assets"
    rows, file_type = read_upload(file, want)
    added: list[dict] = []
    updated: list[dict] = []
    conflicts: list[dict] = []
    unchanged = 0
    unknown: list[str] = []

    with connect() as conn:
        if want == "assets":
            current = {row["asset_id"]: row for row in conn.execute(ASSET_SELECT).fetchall()}
            seen: set[str] = set()
            for row in rows:
                asset_id = str(row.get("asset_id", "")).strip()
                if not asset_id or asset_id in seen:
                    continue
                seen.add(asset_id)
                after = asset_compare_row(conn, row)
                if asset_id not in current:
                    added.append({
                        "key": asset_id, "name": after.get("asset_name") or asset_id,
                        "summary": " · ".join(part for part in (
                            after.get("asset_type"), after.get("datacenter"), after.get("usage_status")) if part),
                    })
                    continue
                va_cham = code_conflict(current[asset_id], row)
                if va_cham:
                    # Đụng mã giữa hai nguồn KHÔNG phải là cập nhật — gộp chung là đánh lừa
                    # người nhập, họ thấy chữ "cập nhật" rồi bấm qua.
                    conflicts.append({
                        "key": asset_id,
                        "name": current[asset_id]["asset_name"] or asset_id,
                        "reason": va_cham,
                        "incoming": after.get("asset_name") or asset_id,
                    })
                    continue
                # File không có cột số U chiếm thì không đụng tới nó -> cũng không báo là đổi.
                fields = [f for f in ASSET_DIFF_FIELDS if f != "rack_size_u" or f in after]
                changes = diff_of(existing_compare_row(current[asset_id]), after, fields)
                if changes:
                    updated.append({"key": asset_id, "name": current[asset_id]["asset_name"], "changes": changes})
                else:
                    unchanged += 1
        else:
            known = {row["asset_id"] for row in conn.execute("SELECT asset_id FROM asset").fetchall()}
            current = {
                f"{row['asset_id']}#{row['event_sequence']}": row
                for row in conn.execute("SELECT * FROM asset_event").fetchall()
            }
            for row in rows:
                asset_id = str(row.get("asset_id", "")).strip()
                if not asset_id or asset_id not in known:
                    if asset_id:
                        unknown.append(asset_id)
                    continue
                sequence = as_int(row.get("event_sequence")) or 0
                key = f"{asset_id}#{sequence}"
                after = {name: text(prepare_event(row).get(name)) for name in EVENT_DIFF_FIELDS}
                if key not in current:
                    added.append({
                        "key": key, "name": f"{asset_id} · sự kiện {sequence}",
                        "summary": " · ".join(part for part in (after.get("event_date"), after.get("location")) if part),
                    })
                    continue
                before = {name: text(current[key].get(name)) for name in EVENT_DIFF_FIELDS}
                changes = diff_of(before, after, EVENT_DIFF_FIELDS, history=True)
                if changes:
                    updated.append({"key": key, "name": f"{asset_id} · sự kiện {sequence}", "changes": changes})
                else:
                    unchanged += 1
    return {
        "kind": want, "fileType": file_type, "rows": len(rows),
        "added": added, "updated": updated, "conflicts": conflicts, "unchanged": unchanged,
        "skippedUnknown": sorted(set(unknown)),
    }


def skip_set(raw: str | None) -> set[str]:
    if not raw:
        return set()
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        return {part.strip() for part in str(raw).split(",") if part.strip()}
    return {str(item).strip() for item in parsed if str(item).strip()}


# --------------------------------------------------------------- xoá sạch dữ liệu
# Tài khoản, danh mục trạng thái và danh mục loại tài sản KHÔNG bao giờ bị xoá: xoá tài
# khoản là tự khóa mình ra ngoài, xoá hai danh mục kia là form không còn gì để chọn.
WIPE_PHRASE = "XOA SACH"
WIPE_RECORDS = ["asset_event", "asset", "import_log"]
WIPE_CATALOGS = ["placement", "rack", "room", "site", "cluster", "supplier"]


@app.post("/api/data/wipe")
def wipe_data(payload: dict, user: dict = Depends(nguoi_quan_tri)) -> dict:
    if str(payload.get("confirm") or "").strip().upper() != WIPE_PHRASE:
        raise HTTPException(status_code=400, detail=f"Gõ đúng “{WIPE_PHRASE}” để xác nhận.")
    scope = str(payload.get("scope") or "records").strip()
    if scope not in {"records", "all"}:
        raise HTTPException(status_code=400, detail="Phạm vi xoá không hợp lệ.")
    tables = WIPE_RECORDS + (WIPE_CATALOGS if scope == "all" else [])
    removed: dict[str, int] = {}
    with connect() as conn:
        for table in tables:
            before = conn.execute(f"SELECT count(*) AS n FROM {table}").fetchone()["n"]
            conn.execute(f"DELETE FROM {table}")
            removed[table] = before
        ghi_nhat_ky(conn, user, "xoa_sach", "data", scope,
                    {t: {"cu": str(n), "moi": "0"} for t, n in removed.items()},
                    f"xóa sạch phạm vi «{scope}», tổng {sum(removed.values())} bản ghi")
        conn.commit()
    return {"scope": scope, "removed": removed, "total": sum(removed.values())}

# --------------------------------------------------------- sửa/xóa hàng loạt
# Tên cột ghép thẳng vào câu SQL nên BẮT BUỘC whitelist — dùng chung whitelist với sửa một bản ghi.
# Trừ ba trường riêng của từng máy: tên, IP và vị trí chi tiết không thể gán chung cho cả lô.
BULK_FIELDS = ASSET_FIELDS - {"current_location", "asset_name", "ip_address", "rack_unit", "serial"}


def bulk_ids(payload: dict) -> list[str]:
    ids = [str(item).strip() for item in (payload.get("ids") or []) if str(item).strip()]
    if not ids:
        raise HTTPException(status_code=400, detail="Chưa chọn tài sản nào.")
    if len(ids) > 5000:
        raise HTTPException(status_code=400, detail="Tối đa 5000 tài sản mỗi lần.")
    return ids


@app.post("/api/assets/bulk-update")
def bulk_update(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    ids = bulk_ids(payload)
    raw = {
        key: str(value).strip()
        for key, value in (payload.get("changes") or {}).items()
        if key in BULK_FIELDS
    }
    if not raw:
        raise HTTPException(status_code=400, detail="Chưa chọn trường nào để sửa.")
    with connect() as conn:
        if raw.get("rack_id") and "datacenter" not in raw:
            # Gán rack mà không nói site: site phải đi theo rack, không để vị trí tự mâu thuẫn.
            found = conn.execute(
                "SELECT s.name FROM rack r JOIN room m ON m.id = r.room_id"
                " JOIN site s ON s.id = m.site_id WHERE r.id = %s",
                (as_int(raw["rack_id"]),),
            ).fetchone()
            if not found:
                raise HTTPException(status_code=400, detail=f"Không có rack số {raw['rack_id']}.")
            raw["datacenter"] = found["name"]
        # current=None: sửa hàng loạt luôn coi trạng thái là mới -> xóa chữ nguyên văn của sổ.
        columns = asset_changes(conn, raw, asset_id="", current=None)
        if not columns:
            raise HTTPException(status_code=400, detail="Chưa chọn trường nào để sửa.")
        sets = ", ".join(f"{key} = %s" for key in columns)
        params = list(columns.values()) + [ids]
        if columns.get("parent_asset_id"):
            # Không cho thiết bị tự làm cha của chính nó.
            result = conn.execute(
                f"UPDATE asset SET {sets}, updated_at = now()"
                " WHERE asset_id = ANY(%s) AND asset_id <> %s",
                params + [columns["parent_asset_id"]],
            )
        else:
            result = conn.execute(
                f"UPDATE asset SET {sets}, updated_at = now() WHERE asset_id = ANY(%s)", params
            )
        updated = result.rowcount
        ghi_nhat_ky(conn, user, "sua", "asset", None,
                    {k: {"cu": None, "moi": None if v is None else str(v)} for k, v in columns.items()},
                    f"sửa hàng loạt {updated} tài sản: {', '.join(ids[:8])}{'…' if len(ids) > 8 else ''}")
        sync_site_ids(conn)
        conn.commit()
    return {"updated": updated, "fields": sorted(columns)}


@app.post("/api/assets/bulk-delete")
def bulk_delete(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    ids = bulk_ids(payload)
    with connect() as conn:
        truoc = conn.execute(
            "SELECT asset_id, asset_name FROM asset WHERE asset_id = ANY(%s) ORDER BY asset_id", (ids,)
        ).fetchall()
        result = conn.execute("DELETE FROM asset WHERE asset_id = ANY(%s)", (ids,))
        deleted = result.rowcount
        # Xóa hàng loạt là thao tác không lùi được -> nhật ký phải giữ ĐỦ tên từng bản ghi.
        ghi_nhat_ky(conn, user, "xoa", "asset", None,
                    {r["asset_id"]: {"cu": r["asset_name"], "moi": None} for r in truoc},
                    f"xóa hàng loạt {deleted} tài sản")
        conn.commit()
    return {"deleted": deleted}


# ---------------------------------------------------------------- luân chuyển
# Luân chuyển là một việc riêng, không phải "sửa trường vị trí": nó dời thiết bị KÈM
# linh kiện đang lắp trong nó, và ghi một dòng lịch sử cho từng bản ghi được dời.
# Muốn để lại một linh kiện thì tháo nó ra (đổi thiết bị cha) TRƯỚC khi bấm luân chuyển.


def descendants(conn: psycopg.Connection, asset_id: str) -> list[str]:
    """Toàn bộ linh kiện lắp trong thiết bị, kể cả linh kiện của linh kiện."""
    rows = conn.execute(
        """
        WITH RECURSIVE tree AS (
            SELECT asset_id FROM asset WHERE parent_asset_id = %s
            UNION
            SELECT a.asset_id FROM asset a JOIN tree t ON a.parent_asset_id = t.asset_id
        )
        SELECT asset_id FROM tree ORDER BY asset_id
        """,
        (asset_id,),
    ).fetchall()
    return [row["asset_id"] for row in rows]


def place_label(site: str, room: str | None, rack: str | None, unit: Any) -> str:
    parts = [site]
    if room and room != "—":
        parts.append(room)
    if rack:
        parts.append(f"rack {rack}" + (f" U{unit}" if unit else ""))
    return " · ".join(part for part in parts if part)


def log_event(conn: psycopg.Connection, asset_id: str, when: date | None, where: str, note: str) -> None:
    top = conn.execute(
        "SELECT max(event_sequence) AS top FROM asset_event WHERE asset_id = %s", (asset_id,)
    ).fetchone()["top"]
    conn.execute(
        "INSERT INTO asset_event (asset_id, event_sequence, event_type, event_date, location,"
        " notes, origin) VALUES (%s, %s, 'transfer', %s, %s, %s, 'manual')",
        (asset_id, (top or 0) + 1, when, where or None, note or None),
    )


@app.post("/api/assets/transfer")
def transfer_assets(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    ids = bulk_ids(payload)
    site_name = str(payload.get("datacenter") or "").strip()
    when = as_date(payload.get("event_date"))
    if str(payload.get("event_date") or "").strip() and when is None:
        raise HTTPException(status_code=400, detail=f"Ngày luân chuyển không hợp lệ: {payload['event_date']}")
    note = str(payload.get("notes") or "").strip()

    # Kho không phải site: đích của luân chuyển là "vào kho" (in_store) HOẶC một site.
    warehouse = str(payload.get("in_store") or "").strip().lower() in {"1", "true", "yes"}
    with connect() as conn:
        site = None if warehouse else require_site(conn, site_name)
        if warehouse:
            site_name = ""

        room_id = rack_id = None
        room_code = rack_code = None
        if not warehouse and str(payload.get("rack_id") or "").strip():
            rack = conn.execute(
                "SELECT r.id, r.code, r.height_u, r.room_id, m.code AS room, s.name AS site"
                " FROM rack r JOIN room m ON m.id = r.room_id JOIN site s ON s.id = m.site_id"
                " WHERE r.id = %s",
                (as_int(payload["rack_id"]),),
            ).fetchone()
            if not rack:
                raise HTTPException(status_code=400, detail=f"Không có rack số {payload['rack_id']}.")
            if rack["site"] != site_name:
                raise HTTPException(
                    status_code=400,
                    detail=f"Rack {rack['code']} thuộc site {rack['site']}, không khớp site {site_name}.",
                )
            rack_id, room_id = rack["id"], rack["room_id"]
            rack_code, room_code = rack["code"], rack["room"]
        elif not warehouse and str(payload.get("room_id") or "").strip():
            room = conn.execute(
                "SELECT m.id, m.code, m.site_id FROM room m WHERE m.id = %s",
                (as_int(payload["room_id"]),),
            ).fetchone()
            if not room or room["site_id"] != site["id"]:
                raise HTTPException(
                    status_code=400, detail=f"Phòng máy đã chọn không thuộc site {site_name}."
                )
            room_id, room_code = room["id"], room["code"]

        unit = as_int(payload.get("rack_unit"))
        if warehouse:
            unit = None      # trong kho thì không có vị trí U
        if not warehouse and str(payload.get("rack_unit") or "").strip() and unit is None:
            raise HTTPException(status_code=400, detail=f"Vị trí U phải là số: {payload['rack_unit']}")
        if unit is not None:
            if len(ids) > 1:
                raise HTTPException(
                    status_code=400, detail="Mỗi U chỉ một thiết bị — chuyển nhiều máy thì để trống vị trí U."
                )
            if not rack_id:
                raise HTTPException(status_code=400, detail="Có vị trí U thì phải chọn rack trước.")
            # Máy 2U đặt ở U42 thì chiếm cả U43 — kiểm theo dải U, không chỉ U bắt đầu.
            size_row = conn.execute("SELECT rack_size_u FROM asset WHERE asset_id = %s", (ids[0],)).fetchone()
            check_unit_range(conn, rack_id, unit, size_row["rack_size_u"] if size_row else None, ids)

        # Kho là nơi lưu trữ: về kho thì mặc định thành "trong kho", trừ khi người dùng chọn khác.
        status = str(payload.get("usage_status") or "").strip()
        if not status and warehouse:
            status = "in_stock"
        if status and not conn.execute(
            "SELECT 1 FROM status_catalog WHERE code = %s", (status,)
        ).fetchone():
            raise HTTPException(status_code=400, detail=f"Trạng thái {status} không có trong danh mục.")

        where = "Kho" if warehouse else place_label(site_name, room_code, rack_code, unit)
        moved: list[dict] = []
        for asset_id in ids:
            if not conn.execute("SELECT 1 FROM asset WHERE asset_id = %s", (asset_id,)).fetchone():
                raise HTTPException(status_code=404, detail=f"Không có tài sản {asset_id}.")
            # Linh kiện đi theo thiết bị: cùng site, cùng phòng, cùng rack — nhưng không có
            # vị trí U riêng, vì chúng nằm trong máy chứ không chiếm ô rack nào.
            for index, target in enumerate([asset_id] + descendants(conn, asset_id)):
                conn.execute(
                    "UPDATE asset SET in_store = %s, datacenter = %s, current_location = %s,"
                    " room_id = %s, rack_id = %s, rack_unit = %s, updated_at = now()"
                    " WHERE asset_id = %s",
                    (warehouse, site_name or None, site_name or None, room_id, rack_id,
                     unit if index == 0 else None, target),
                )
                if status:
                    # usage_status_label là chữ nguyên văn của sổ; đổi trạng thái tay thì bỏ.
                    conn.execute(
                        "UPDATE asset SET usage_status = %s, usage_status_label = NULL WHERE asset_id = %s",
                        (status, target),
                    )
                log_event(conn, target, when, where, note)
                moved.append({"assetId": target, "part": index > 0})
        sync_site_ids(conn)
        conn.commit()
    return {
        "moved": len(moved),
        "devices": sum(1 for item in moved if not item["part"]),
        "parts": sum(1 for item in moved if item["part"]),
        "location": where,
        "status": status or "",
        "warehouse": warehouse,
        "inStore": warehouse,
    }


# ------------------------------------------------------ xuất file (CSV / XLSX)
def export_assets_rows() -> list[dict]:
    with connect() as conn:
        rows = conn.execute(
            ASSET_SELECT + " ORDER BY a.source_row NULLS LAST, a.created_at, a.asset_id"
        ).fetchall()
    payload = []
    for row in rows:
        item = dict(row)
        item["parent_reference"] = row["parent_asset_id"] or row["attachment_label"]
        item["rack"] = row.get("rack_code")
        for flag in ("in_store", "code_pending"):
            item[flag] = "1" if row.get(flag) else ""
        payload.append(item)
    return payload


def export_history_rows() -> list[dict]:
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM asset_event ORDER BY source_row NULLS LAST, asset_id, event_sequence"
        ).fetchall()
    return [dict(row) for row in rows]


def csv_response(filename: str, columns: list[str], rows: list[dict]) -> StreamingResponse:
    buffer = io.StringIO()
    buffer.write("﻿")  # BOM để Excel mở đúng tiếng Việt
    writer = csv.DictWriter(buffer, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    for row in rows:
        writer.writerow({key: text(row.get(key)) for key in columns})
    buffer.seek(0)
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def xlsx_response(filename: str, columns: list[str], rows: list[dict]) -> StreamingResponse:
    try:
        from openpyxl import Workbook
    except ImportError:  # pragma: no cover
        raise HTTPException(status_code=500, detail="Máy chủ chưa cài openpyxl để ghi XLSX.")
    book = Workbook(write_only=True)
    sheet = book.create_sheet("Device Management")
    sheet.append(columns)
    for row in rows:
        sheet.append([text(row.get(key)) for key in columns])
    buffer = io.BytesIO()
    book.save(buffer)
    buffer.seek(0)
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.get("/api/export/assets.csv")
def export_assets_csv(user: dict = Depends(current_user)) -> StreamingResponse:
    return csv_response("asset_export.csv", ASSET_COLUMNS, export_assets_rows())


@app.get("/api/export/history.csv")
def export_history_csv(user: dict = Depends(current_user)) -> StreamingResponse:
    return csv_response("asset_history_export.csv", HISTORY_COLUMNS, export_history_rows())


@app.get("/api/export/assets.xlsx")
def export_assets_xlsx(user: dict = Depends(current_user)) -> StreamingResponse:
    return xlsx_response("asset_export.xlsx", ASSET_COLUMNS, export_assets_rows())


@app.get("/api/export/history.xlsx")
def export_history_xlsx(user: dict = Depends(current_user)) -> StreamingResponse:
    return xlsx_response("asset_history_export.xlsx", HISTORY_COLUMNS, export_history_rows())


# ------------------------------------------------------------ mẫu file cho phòng ban khác
# Mỗi phòng ban cần một hình dạng file khác nhau: bên nạp ERP cần đúng tên trường của ERP,
# bên kiểm kê cần cột đọc được bằng mắt. Ghim từng mẫu vào code thì đổi một cột là phải sửa
# code rồi triển khai lại — nên mẫu được KHAI trong database và file dựng theo khai báo đó.
#
# Khuôn của một cột (`mau`) là chuỗi trộn chữ thường với tham chiếu:
#     Thiết Bị System Admin          -> hằng số, mọi dòng như nhau
#     $asset_id                      -> lấy thẳng giá trị
#     ${usage_status|trang_thai_erp} -> lấy giá trị rồi tra qua bảng đổi từ vựng
#     $site-$cluster-$loai_nhan      -> ghép nhiều trường với chữ xen giữa
#     $$                             -> một dấu $ thật

THAM_CHIEU = re.compile(r"\$\{\s*([a-z0-9_]+)\s*(?:\|\s*([a-z0-9_]+)\s*)?\}|\$([a-z0-9_]+)")
DAU_DOLLAR = "\x00dollar\x00"

# Trường dựng thêm, không có sẵn trong bảng asset. Để người khai biết mình gõ được gì.
TRUONG_THEM: list[tuple[str, str]] = [
    ("stt", "Số thứ tự dòng trong file (1, 2, 3…)"),
    ("ma_hien_thi", "Mã tài sản, ĐỂ TRỐNG nếu là mã tạm chưa gán — dùng cho file gửi ra ngoài"),
    ("ma_tien_to", "Tiền tố của mã tài sản (ssd, hdd, svr, cab…)"),
    ("loai_nhan", "Tên loại tài sản (Ổ cứng, Máy chủ…)"),
    ("trang_thai_nhan", "Tên trạng thái (Đang sử dụng, Trong kho…)"),
    ("site", "Tên site"),
    ("rack", "Mã rack"),
    ("phong", "Mã phòng máy"),
    ("noi_luu", "Kho nếu đang trong kho, ngược lại là tên site"),
]


def truong_dung_duoc() -> list[dict]:
    return ([{"ten": t, "mo_ta": "Cột của tài sản"} for t in ASSET_COLUMNS]
            + [{"ten": t, "mo_ta": m} for t, m in TRUONG_THEM])


def gia_tri_cua_dong(row: dict, nhan_loai: dict, nhan_trang_thai: dict) -> dict:
    """Bộ giá trị mà khuôn mẫu tham chiếu được, cho MỘT tài sản."""
    gt = {ten: text(row.get(ten)) for ten in ASSET_COLUMNS}
    ma = gt.get("asset_id") or ""
    gt["ma_tien_to"] = ma.split("-")[0] if "-" in ma else ma
    # Mã tạm CHUA-GAN-#### là chỗ trống chờ admin điền, không phải danh tính của vật. Gửi nó
    # ra ngoài là bên nhận tưởng đó là mã thật rồi ghi vào sổ của họ. $asset_id vẫn giữ mã thật
    # để xuất/nhập nội bộ khớp lại được; file cho phòng ban khác thì dùng $ma_hien_thi.
    gt["ma_hien_thi"] = "" if str(row.get("code_pending") or "") == "1" else ma
    gt["loai_nhan"] = nhan_loai.get(gt.get("asset_type") or "", "")
    gt["trang_thai_nhan"] = nhan_trang_thai.get(gt.get("usage_status") or "", "")
    gt["rack"] = text(row.get("rack") or row.get("rack_code"))
    gt["phong"] = text(row.get("room_code"))
    gt["site"] = text(row.get("datacenter") or row.get("rack_site"))
    gt["noi_luu"] = "Kho" if str(row.get("in_store") or "") == "1" else gt["site"]
    return gt


def dung_chuoi(mau: str, gt: dict, bang_doi: dict) -> str:
    """Khuôn -> chuỗi. Không có tham chiếu thì chính nó là giá trị cố định."""
    if not mau:
        return ""
    if "$" not in mau:
        return mau
    def thay(m: "re.Match[str]") -> str:
        ten = m.group(1) or m.group(3) or ""
        bang = m.group(2)
        v = str(gt.get(ten, ""))
        if bang:
            tra = bang_doi.get(bang) or {}
            v = str(tra.get(v, tra.get("*", v)))
        return v
    return THAM_CHIEU.sub(thay, mau.replace("$$", DAU_DOLLAR)).replace(DAU_DOLLAR, "$")


def loc_pham_vi(rows: list[dict], scope: dict) -> list[dict]:
    """Mẫu chỉ lấy phần tài sản mà phòng ban đó cần, không phải lúc nào cũng cả kho."""
    scope = scope or {}
    kho = str(scope.get("in_store") or "")
    loai = set(scope.get("asset_type") or [])
    trang_thai = set(scope.get("usage_status") or [])
    site = set(scope.get("datacenter") or [])
    ra = []
    for r in rows:
        trong_kho = str(r.get("in_store") or "") == "1"
        if kho == "1" and not trong_kho:
            continue
        if kho == "0" and trong_kho:
            continue
        if loai and str(r.get("asset_type") or "") not in loai:
            continue
        if trang_thai and str(r.get("usage_status") or "") not in trang_thai:
            continue
        if site and text(r.get("datacenter")) not in site:
            continue
        ra.append(r)
    return ra


def dung_bang(mau: dict, gioi_han: int | None = None) -> dict:
    """Dựng tiêu đề + các dòng của một mẫu. Dùng chung cho xem trước và xuất file thật."""
    with connect() as conn:
        nhan_loai = {r["code"]: r["label"]
                     for r in conn.execute("SELECT code, label FROM asset_type").fetchall()}
        nhan_tt = {r["code"]: r["label"]
                   for r in conn.execute("SELECT code, label FROM status_catalog").fetchall()}
    rows = loc_pham_vi(export_assets_rows(), mau.get("scope") or {})
    cot = mau.get("col_defs") or []
    bang_doi = mau.get("maps") or {}
    so_dong_td = max(1, min(int(mau.get("header_rows") or 1), 2))
    tieu_de = [[str(c.get("header1") or "") for c in cot]]
    if so_dong_td >= 2:
        tieu_de.append([str(c.get("header2") or "") for c in cot])
    ra = []
    for thu_tu, row in enumerate(rows[:gioi_han] if gioi_han else rows, 1):
        gt = gia_tri_cua_dong(row, nhan_loai, nhan_tt)
        gt["stt"] = str(thu_tu)
        dong = []
        for c in cot:
            v = dung_chuoi(str(c.get("mau") or ""), gt, bang_doi)
            ten_bang = str(c.get("bang") or "").strip()
            if ten_bang:
                tra = bang_doi.get(ten_bang) or {}
                v = str(tra.get(v, tra.get("*", v)))
            dong.append(v)
        ra.append(dong)
    return {"headers": tieu_de, "rows": ra, "total": len(rows), "cols": cot}


def ep_kieu(v: str, kieu: str):
    """Ô Excel phải đúng kiểu, không thì bên nhận đọc số thành chữ rồi báo lỗi nạp."""
    if not v:
        return None
    if kieu == "so":
        try:
            so = float(str(v).replace(",", ""))
            return int(so) if so.is_integer() else so
        except ValueError:
            return v
    if kieu == "ngay":
        for khuon in ("%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%d %H:%M:%S"):
            try:
                return datetime.strptime(str(v)[:19], khuon).date()
            except ValueError:
                continue
        return v
    return v


def ten_sheet_sach(ten: str) -> str:
    """Excel cấm []:*?/\\ trong tên sheet và chặn quá 31 ký tự."""
    sach = re.sub(r"[\[\]:*?/\\]", "-", str(ten or "").strip()) or "Sheet1"
    return sach[:31]


def xlsx_byte(sheet_name: str, bang: dict) -> bytes:
    """Dựng nội dung file. Tách khỏi phần trả HTTP để kiểm được mà không cần dựng response."""
    try:
        from openpyxl import Workbook
    except ImportError:  # pragma: no cover
        raise HTTPException(status_code=500, detail="Máy chủ chưa cài openpyxl để ghi XLSX.")
    book = Workbook(write_only=True)
    sheet = book.create_sheet(ten_sheet_sach(sheet_name))
    for hang in bang["headers"]:
        sheet.append(hang)
    kieu_cot = [str((c or {}).get("kieu") or "chu") for c in bang.get("cols") or []]
    for dong in bang["rows"]:
        sheet.append([ep_kieu(v, kieu_cot[i] if i < len(kieu_cot) else "chu")
                      for i, v in enumerate(dong)])
    buffer = io.BytesIO()
    book.save(buffer)
    return buffer.getvalue()


def xlsx_tu_bang(file_name: str, sheet_name: str, bang: dict) -> StreamingResponse:
    noi_dung = xlsx_byte(sheet_name, bang)
    ten = file_name if str(file_name or "").lower().endswith(".xlsx") else f"{file_name}.xlsx"
    # Tên mẫu là tiếng Việt nên phải khai cả hai kiểu: bản ASCII cho trình duyệt cũ,
    # filename* (RFC 5987) cho bản có dấu. Chỉ đưa tên có dấu vào là một số trình duyệt cắt cụt.
    ascii_ten = re.sub(r"[^A-Za-z0-9._-]+", "-", strip_accents(ten)).strip("-") or "export.xlsx"
    return StreamingResponse(
        iter([noi_dung]),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition":
                 f'attachment; filename="{ascii_ten}"; filename*=UTF-8\'\'{quote(ten)}'},
    )


KIEU_COT = {"chu", "so", "ngay"}


def doc_khai_bao(payload: dict) -> dict:
    """Kiểm khai báo của một mẫu. Tham chiếu tới trường không có thì BÁO LỖI, không lặng lẽ
    để trống — người khai gõ nhầm tên trường mà file vẫn xuất ra là kiểu sai khó tìm nhất."""
    ten = str(payload.get("name") or "").strip()
    if not ten:
        raise HTTPException(status_code=400, detail="Thiếu tên mẫu.")
    cot_vao = payload.get("col_defs")
    if not isinstance(cot_vao, list) or not cot_vao:
        raise HTTPException(status_code=400, detail="Mẫu phải có ít nhất một cột.")
    bang_doi = payload.get("maps") or {}
    if not isinstance(bang_doi, dict):
        raise HTTPException(status_code=400, detail="Bảng đổi từ vựng phải là một đối tượng.")
    for ten_bang, tra in bang_doi.items():
        if not isinstance(tra, dict):
            raise HTTPException(status_code=400, detail=f"Bảng đổi '{ten_bang}' phải là cặp giá trị.")
    hop_le = {t["ten"] for t in truong_dung_duoc()}
    thieu_truong: set[str] = set()
    thieu_bang: set[str] = set()
    cot_ra = []
    for i, c in enumerate(cot_vao, 1):
        c = c or {}
        h1 = str(c.get("header1") or "").strip()
        if not h1:
            raise HTTPException(status_code=400, detail=f"Cột thứ {i} chưa có tiêu đề.")
        khuon = str(c.get("mau") or "")
        for m in THAM_CHIEU.finditer(khuon.replace("$$", DAU_DOLLAR)):
            ten_truong = m.group(1) or m.group(3) or ""
            if ten_truong not in hop_le:
                thieu_truong.add(ten_truong)
            if m.group(2) and m.group(2) not in bang_doi:
                thieu_bang.add(m.group(2))
        ten_bang_cot = str(c.get("bang") or "").strip()
        if ten_bang_cot and ten_bang_cot not in bang_doi:
            thieu_bang.add(ten_bang_cot)
        kieu = str(c.get("kieu") or "chu").strip() or "chu"
        if kieu not in KIEU_COT:
            raise HTTPException(status_code=400,
                                detail=f"Cột {i} có kiểu lạ '{kieu}'. Chọn chu, so hoặc ngay.")
        cot_ra.append({"header1": h1, "header2": str(c.get("header2") or "").strip(),
                       "mau": khuon, "bang": ten_bang_cot, "kieu": kieu})
    if thieu_truong:
        raise HTTPException(
            status_code=400,
            detail="Khuôn mẫu nhắc tới trường không có: " + ", ".join(sorted(thieu_truong))
                   + ". Xem danh sách trường dùng được ở ngay dưới ô khuôn.")
    if thieu_bang:
        raise HTTPException(status_code=400,
                            detail="Khuôn mẫu gọi bảng đổi chưa khai: " + ", ".join(sorted(thieu_bang)))
    return {
        "name": ten,
        "note": str(payload.get("note") or "").strip() or None,
        "file_name": str(payload.get("file_name") or "").strip() or None,
        "sheet_name": str(payload.get("sheet_name") or "").strip() or "Sheet1",
        "header_rows": max(1, min(int(payload.get("header_rows") or 1), 2)),
        "scope": payload.get("scope") if isinstance(payload.get("scope"), dict) else {},
        "maps": bang_doi,
        "col_defs": cot_ra,
    }


def mau_ra(row: dict) -> dict:
    return {"id": row["id"], "name": row["name"], "note": row["note"] or "",
            "fileName": row["file_name"] or "", "sheetName": row["sheet_name"],
            "headerRows": row["header_rows"], "scope": row["scope"] or {},
            "maps": row["maps"] or {}, "colDefs": row["col_defs"] or [],
            "updatedAt": stamp(row["updated_at"]) if row.get("updated_at") else ""}


def lay_mau(conn: psycopg.Connection, mau_id: int) -> dict:
    row = conn.execute("SELECT * FROM export_template WHERE id = %s", (mau_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Không có mẫu này.")
    return row


@app.get("/api/export-templates")
def list_export_templates(user: dict = Depends(current_user)) -> dict:
    with connect() as conn:
        rows = conn.execute("SELECT * FROM export_template ORDER BY name").fetchall()
    return {"templates": [mau_ra(r) for r in rows], "fields": truong_dung_duoc()}


@app.post("/api/export-templates", status_code=201)
def create_export_template(payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    khai = doc_khai_bao(payload)
    with connect() as conn:
        if conn.execute("SELECT 1 FROM export_template WHERE name = %s", (khai["name"],)).fetchone():
            raise HTTPException(status_code=409, detail=f"Đã có mẫu tên {khai['name']}.")
        row = conn.execute(
            "INSERT INTO export_template (name, note, file_name, sheet_name, header_rows,"
            " scope, maps, col_defs) VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *",
            (khai["name"], khai["note"], khai["file_name"], khai["sheet_name"],
             khai["header_rows"], Json(khai["scope"]), Json(khai["maps"]), Json(khai["col_defs"])),
        ).fetchone()
        ghi_nhat_ky(conn, user, "them", "export_template", str(row["id"]), None,
                    f"{khai['name']} — {len(khai['col_defs'])} cột")
        conn.commit()
    return {"template": mau_ra(row)}


@app.put("/api/export-templates/{mau_id}")
def update_export_template(mau_id: int, payload: dict, user: dict = Depends(nguoi_ghi)) -> dict:
    khai = doc_khai_bao(payload)
    with connect() as conn:
        truoc = lay_mau(conn, mau_id)
        trung = conn.execute("SELECT 1 FROM export_template WHERE name = %s AND id <> %s",
                             (khai["name"], mau_id)).fetchone()
        if trung:
            raise HTTPException(status_code=409, detail=f"Đã có mẫu tên {khai['name']}.")
        row = conn.execute(
            "UPDATE export_template SET name=%s, note=%s, file_name=%s, sheet_name=%s,"
            " header_rows=%s, scope=%s, maps=%s, col_defs=%s, updated_at=now()"
            " WHERE id=%s RETURNING *",
            (khai["name"], khai["note"], khai["file_name"], khai["sheet_name"],
             khai["header_rows"], Json(khai["scope"]), Json(khai["maps"]),
             Json(khai["col_defs"]), mau_id),
        ).fetchone()
        doi = doi_gi({"name": truoc["name"], "so_cot": len(truoc["col_defs"] or [])},
                     {"name": khai["name"], "so_cot": len(khai["col_defs"])})
        ghi_nhat_ky(conn, user, "sua", "export_template", str(mau_id), doi or None, khai["name"])
        conn.commit()
    return {"template": mau_ra(row)}


@app.delete("/api/export-templates/{mau_id}")
def delete_export_template(mau_id: int, user: dict = Depends(nguoi_ghi)) -> dict:
    with connect() as conn:
        row = lay_mau(conn, mau_id)
        conn.execute("DELETE FROM export_template WHERE id = %s", (mau_id,))
        ghi_nhat_ky(conn, user, "xoa", "export_template", str(mau_id), None, row["name"])
        conn.commit()
    return {"deleted": row["name"]}


@app.post("/api/export-templates/preview")
def preview_export_template(payload: dict, user: dict = Depends(current_user)) -> dict:
    """Xem trước ngay trên khai báo ĐANG SỬA, chưa cần lưu — sửa khuôn là thấy kết quả liền."""
    khai = doc_khai_bao(payload)
    gioi_han = max(1, min(int(payload.get("limit") or 10), 50))
    bang = dung_bang(khai, gioi_han)
    return {"headers": bang["headers"], "rows": bang["rows"], "total": bang["total"],
            "shown": len(bang["rows"])}


@app.get("/api/export/template/{mau_id}.xlsx")
def export_by_template(mau_id: int, user: dict = Depends(current_user)) -> StreamingResponse:
    with connect() as conn:
        row = lay_mau(conn, mau_id)
    mau = dict(row)
    bang = dung_bang(mau)
    ten_file = mau.get("file_name") or f"{mau['name']}.xlsx"
    return xlsx_tu_bang(ten_file, mau.get("sheet_name") or "Sheet1", bang)


# ------------------------------------------------------------ mẫu gieo sẵn
# Ba mẫu cho ba tác vụ khác nhau, gieo MỘT LẦN khi bảng còn rỗng. Đây là điểm xuất phát để
# sửa, không phải bản cứng: mọi cột, khuôn và bảng đổi từ vựng đều sửa được trên giao diện.

GIEO_MAU: list[dict] = [
    {
        "name": "Kiểm kê thiết bị SA → ERP",
        "sheet_name": "Dữ liệu làm sạch sẽ up lên ERP",
        "file_name": "Kiem ke thiet bi SA - ERP.xlsx",
        "header_rows": 2,
        "note": ("Dựng theo file NB-HR-Kiem ke thiet bi SA. Dòng tiêu đề thứ HAI là đường dẫn "
                 "trường của ERP — sai một chữ là ERP từ chối cả file, đừng sửa nếu không có "
                 "yêu cầu từ bên nhận. Ba chỗ còn CHỜ CHỐT: (1) cột NƠI BẢO QUẢN trong file gốc "
                 "ghép 5 mảnh site-cụm-loại-nơi gắn-đối tượng sử dụng, app chưa có 'đối tượng "
                 "sử dụng' theo từng tài sản nên tạm ghép 3 mảnh; (2) trạng thái hỏng và suy "
                 "giảm đang xếp tạm; (3) bốn cột THƯƠNG HIỆU, NHÂN VIÊN, NHÀ CUNG CẤP, NGÀY HẾT "
                 "BẢO HÀNH để trống đúng như file gốc dù app có sẵn dữ liệu."),
        "scope": {},
        "maps": {
            # Tra theo CẶP loại + tiền tố mã: ERP tách SSD với HDD trong khi app chỉ có một
            # loại "disk", còn tiền tố das lại dùng cho cả máy chủ DAS lẫn adapter.
            "ten_erp": {
                "disk/ssd": "SSD", "disk/hdd": "HDD", "disk/raid": "SSD", "disk/CHUA": "",
                "cable/cab": "Cáp", "cable/cap": "Cáp",
                "server/svr": "Máy chủ", "server/das": "DAS",
                "switch/sw": "Switch", "optical_module/module": "Module",
                "hsm/hsm": "HSM", "nic/card": "Card", "adapter/das": "Card",
                "firewall/fw": "Firewall", "storage/sto": "NAS",
                "raid_card/card": "Card", "network_or_host/svr": "Máy chủ",
                "unknown/card": "Card", "*": "",
            },
            "trang_thai_erp": {
                "in_use": "Đang sử dụng", "in_use_needs_replacement": "Đang sử dụng",
                "in_stock": "Sẵn sàng", "not_in_use": "Sẵn sàng",
                "degraded": "Đang sử dụng", "broken": "Chờ hủy/thanh lý",
                "pending_disposal": "Chờ hủy/thanh lý", "retired": "Đã thanh lý", "*": "",
            },
        },
        "col_defs": [
            {"header1": "PHÂN LOẠI TÀI SẢN", "header2": "Equipment/Equipment Category/Category Name",
             "mau": "Thiết Bị System Admin", "bang": "", "kieu": "chu"},
            {"header1": "TÊN TÀI SẢN", "header2": "Equipment/Name",
             "mau": "$asset_type/$ma_tien_to", "bang": "ten_erp", "kieu": "chu"},
            {"header1": "MÔ TẢ TÀI SẢN", "header2": "Equipment/Description",
             "mau": "$description", "bang": "", "kieu": "chu"},
            {"header1": "MÃ TÀI SẢN/SỐ SERI", "header2": "Equipment/Product Information/Serial Number",
             "mau": "$ma_hien_thi", "bang": "", "kieu": "chu"},
            {"header1": "Mã tài sản/ phân bổ - FI", "header2": "",
             "mau": "$purchase_invoice", "bang": "", "kieu": "chu"},
            {"header1": "THƯƠNG HIỆU", "header2": "Equipment/Product Information/Model",
             "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "TÌNH TRẠNG PHÂN BỔ/KHẤU HAO", "header2": "Allocation Status (Việt)",
             "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "TÌNH TRẠNG PHÂN BỔ/KHẤU HAO", "header2": "Allocation Status (Anh)",
             "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "TRẠNG THÁI SỬ DỤNG", "header2": "Equipment/Equipment state (Việt)",
             "mau": "${usage_status|trang_thai_erp}", "bang": "", "kieu": "chu"},
            {"header1": "TRẠNG THÁI SỬ DỤNG", "header2": "Equipment/Equipment state (Anh)",
             "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "Used by", "header2": "Used by", "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "PHÒNG BAN", "header2": "Equipment/Used by/Department",
             "mau": "System Admin", "bang": "", "kieu": "chu"},
            {"header1": "NHÂN VIÊN/PHÒNG BAN SỬ DỤNG", "header2": "Equipment/Used by/Employee",
             "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "NƠI BẢO QUẢN", "header2": "Equipment/Used in location",
             "mau": "$noi_luu-$cluster-$loai_nhan", "bang": "", "kieu": "chu"},
            {"header1": "NGÀY NHẬP KHO", "header2": "Equipment/Product Information/Effective Date",
             "mau": "$handover_date", "bang": "", "kieu": "ngay"},
            {"header1": "GIÁ MUA (GỒM VAT)", "header2": "Equipment/Product Information/Cost",
             "mau": "$purchase_price_vnd", "bang": "", "kieu": "so"},
            {"header1": "NHÀ CUNG CẤP", "header2": "Equipment/Product Information/Vendor",
             "mau": "", "bang": "", "kieu": "chu"},
            {"header1": "NGÀY HẾT BẢO HÀNH",
             "header2": "Equipment/Product Information/Warranty Expiration Date",
             "mau": "", "bang": "", "kieu": "ngay"},
            {"header1": "Số PO", "header2": "Equipment/Product Information/Vendor Reference",
             "mau": "", "bang": "", "kieu": "chu"},
        ],
    },
    {
        "name": "Biên bản bàn giao thiết bị",
        "sheet_name": "Bàn giao",
        "file_name": "Bien ban ban giao thiet bi.xlsx",
        "header_rows": 1,
        "note": "Mẫu đọc bằng mắt: một dòng tiêu đề tiếng Việt, chỉ lấy thiết bị đang vận hành.",
        "scope": {"in_store": "0"},
        "maps": {},
        "col_defs": [
            {"header1": "STT", "header2": "", "mau": "$stt", "bang": "", "kieu": "so"},
            {"header1": "Mã tài sản", "header2": "", "mau": "$ma_hien_thi", "bang": "", "kieu": "chu"},
            {"header1": "Tên thiết bị", "header2": "", "mau": "$asset_name", "bang": "", "kieu": "chu"},
            {"header1": "Loại", "header2": "", "mau": "$loai_nhan", "bang": "", "kieu": "chu"},
            {"header1": "Site", "header2": "", "mau": "$noi_luu", "bang": "", "kieu": "chu"},
            {"header1": "Rack", "header2": "", "mau": "$rack", "bang": "", "kieu": "chu"},
            {"header1": "Ô U", "header2": "", "mau": "$rack_unit", "bang": "", "kieu": "so"},
            {"header1": "Cụm", "header2": "", "mau": "$cluster", "bang": "", "kieu": "chu"},
            {"header1": "Trạng thái", "header2": "", "mau": "$trang_thai_nhan", "bang": "", "kieu": "chu"},
            {"header1": "Số serial / license", "header2": "", "mau": "$serial", "bang": "", "kieu": "chu"},
            {"header1": "Ngày bàn giao", "header2": "", "mau": "$handover_date", "bang": "", "kieu": "ngay"},
        ],
    },
    {
        "name": "Kiểm kê hàng trong kho",
        "sheet_name": "Tồn kho",
        "file_name": "Kiem ke hang trong kho.xlsx",
        "header_rows": 1,
        "note": "Chỉ tài sản đang trong kho. Dùng khi đối chiếu số lượng tồn với bộ phận khác.",
        "scope": {"in_store": "1"},
        "maps": {},
        "col_defs": [
            {"header1": "STT", "header2": "", "mau": "$stt", "bang": "", "kieu": "so"},
            {"header1": "Mã tài sản", "header2": "", "mau": "$ma_hien_thi", "bang": "", "kieu": "chu"},
            {"header1": "Tên", "header2": "", "mau": "$asset_name", "bang": "", "kieu": "chu"},
            {"header1": "Loại", "header2": "", "mau": "$loai_nhan", "bang": "", "kieu": "chu"},
            {"header1": "Dung lượng / cấu hình", "header2": "", "mau": "$capacity", "bang": "", "kieu": "chu"},
            {"header1": "Trạng thái", "header2": "", "mau": "$trang_thai_nhan", "bang": "", "kieu": "chu"},
            {"header1": "Mô tả", "header2": "", "mau": "$description", "bang": "", "kieu": "chu"},
        ],
    },
]


def gieo_mau_xuat(conn: psycopg.Connection) -> None:
    """Gieo mẫu mở đầu khi bảng còn rỗng. Xoá hết rồi khởi động lại thì gieo lại — đó là
    đường quay về bản gốc, không phải lỗi."""
    if conn.execute("SELECT 1 FROM export_template LIMIT 1").fetchone():
        return
    for mau in GIEO_MAU:
        conn.execute(
            "INSERT INTO export_template (name, note, file_name, sheet_name, header_rows,"
            " scope, maps, col_defs) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)"
            " ON CONFLICT (name) DO NOTHING",
            (mau["name"], mau["note"], mau["file_name"], mau["sheet_name"], mau["header_rows"],
             Json(mau["scope"]), Json(mau["maps"]), Json(mau["col_defs"])),
        )
