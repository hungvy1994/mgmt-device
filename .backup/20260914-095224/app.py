"""Atlas Ops API — đọc/ghi dữ liệu tài sản trong Postgres, nhập/xuất CSV.

Trả dữ liệu đúng hình dạng của data/atlas-data.js ({meta, assetRows, historyRows})
để trang tĩnh dùng lại nguyên bộ mapper phía client, không phải viết mapper thứ hai.
"""
from __future__ import annotations

import base64
import csv
import hashlib
import hmac
import io
import os
import secrets
import time
from datetime import date, datetime, timedelta, timezone
from typing import Any

import psycopg
from fastapi import Depends, FastAPI, HTTPException, Request, Response, UploadFile, File
from fastapi.responses import StreamingResponse
from psycopg.rows import dict_row

DSN = os.environ.get("DATABASE_URL", "postgresql://atlas:atlas@db:5432/atlas")
COOKIE_NAME = "atlas_session"
COOKIE_SECURE = os.environ.get("COOKIE_SECURE", "").lower() in {"1", "true", "yes"}
SESSION_HOURS = int(os.environ.get("SESSION_HOURS", "8"))

ASSET_COLUMNS = [
    "asset_id", "asset_name", "asset_type", "asset_category", "ip_address",
    "ip_or_type_raw", "cluster", "datacenter", "current_location", "parent_reference",
    "capacity", "replacement_target", "usage_status", "usage_status_label",
    "usage_start_date", "handover_date", "handover_status", "purchase_invoice",
    "purchase_price_vnd", "supplier_code", "supplier_name", "warranty_months",
    "warranty_end_date", "description", "source_sheet", "source_row", "review_flags",
]
HISTORY_COLUMNS = [
    "asset_id", "event_sequence", "event_type", "event_date", "location",
    "usage_object", "notes", "declared_transition_count", "source_column",
    "source_row", "review_flags",
]

app = FastAPI(title="Atlas Ops API", docs_url="/api/docs", openapi_url="/api/openapi.json")


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


AUTH_SCHEMA = """
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
"""


@app.on_event("startup")
def ensure_auth_schema() -> None:
    """Volume database cũ không chạy lại db/schema.sql nên tạo bảng tài khoản tại đây."""
    with connect() as conn:
        conn.execute(AUTH_SCHEMA)
        conn.execute("DELETE FROM user_session WHERE expires_at < now()")
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
def asset_row_out(row: dict) -> dict:
    """Một dòng asset trong DB -> đúng bộ cột của asset_import.csv (bỏ ô rỗng)."""
    out = {
        "asset_id": row["asset_id"],
        "asset_name": row["asset_name"],
        "asset_type": row["asset_type"],
        "asset_category": row["asset_category"],
        "ip_address": row["ip_address"],
        "ip_or_type_raw": row["ip_or_type_raw"],
        "cluster": row["cluster"],
        "datacenter": row["datacenter"],
        "current_location": row["current_location"],
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
        "description": row["description"],
        "source_sheet": row["source_sheet"],
        "source_row": row["source_row"],
        "review_flags": row["review_flags"],
    }
    return {key: text(value) for key, value in out.items() if text(value)}


def history_row_out(row: dict) -> dict:
    out = {key: row.get(key) for key in HISTORY_COLUMNS}
    return {key: text(value) for key, value in out.items() if text(value) or key == "event_sequence"}


@app.get("/api/health")
def health() -> dict:
    with connect() as conn:
        conn.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/api/data")
def data(user: dict = Depends(current_user)) -> dict:
    with connect() as conn:
        assets = conn.execute("SELECT * FROM asset ORDER BY source_row NULLS LAST, asset_id").fetchall()
        events = conn.execute(
            "SELECT * FROM asset_event ORDER BY source_row NULLS LAST, asset_id, event_sequence"
        ).fetchall()
        statuses = conn.execute("SELECT * FROM status_catalog ORDER BY sort_order, code").fetchall()
    return {
        "meta": {
            "source": "postgres",
            "sourceWorkbook": "BAO CAO THEO DOI SERVER (HR+SA).xlsx",
            "sourceSheet": "TỔNG HỢP",
            "assetFile": "database",
            "historyFile": "database",
            "generatedAt": datetime.now().isoformat(timespec="seconds"),
            "assetCount": len(assets),
            "eventCount": len(events),
            "assetsFlagged": sum(1 for row in assets if row["review_flags"]),
            "eventsFlagged": sum(1 for row in events if row["review_flags"]),
        },
        "statuses": [
            {"code": row["code"], "label": row["label"], "cls": row["tag_style"], "attention": row["attention"]}
            for row in statuses
        ],
        "assetRows": [asset_row_out(row) for row in assets],
        "historyRows": [history_row_out(row) for row in events],
    }


# ---------------------------------------------------------------- ghi dữ liệu
def upsert_assets(conn: psycopg.Connection, rows: list[dict]) -> dict:
    known = {row["asset_id"] for row in conn.execute("SELECT asset_id FROM asset").fetchall()}
    incoming_ids = {str(row.get("asset_id", "")).strip() for row in rows}
    all_ids = known | incoming_ids
    added = updated = 0
    for row in rows:
        asset_id = str(row.get("asset_id", "")).strip()
        if not asset_id:
            continue
        parent_raw = str(row.get("parent_reference") or row.get("parent_asset_id") or "").strip()
        parent_id = parent_raw if parent_raw in all_ids and parent_raw != asset_id else None
        label = "" if parent_id else parent_raw
        status = str(row.get("usage_status") or "").strip() or None
        if status:
            conn.execute(
                "INSERT INTO status_catalog (code, label, sort_order) VALUES (%s, %s, 99) "
                "ON CONFLICT (code) DO NOTHING",
                (status, str(row.get("usage_status_label") or status)),
            )
        site = str(row.get("datacenter") or "").strip()
        if site:
            conn.execute(
                "INSERT INTO site (name, kind) VALUES (%s, %s) ON CONFLICT (name) DO NOTHING",
                (site, "warehouse" if site.lower().startswith("kho") else "datacenter"),
            )
        supplier_code = str(row.get("supplier_code") or "").strip()
        if supplier_code:
            conn.execute(
                "INSERT INTO supplier (code, name) VALUES (%s, %s) ON CONFLICT (code) DO NOTHING",
                (supplier_code, str(row.get("supplier_name") or supplier_code)),
            )
        ip = str(row.get("ip_address") or "").strip() or None
        params = (
            asset_id,
            str(row.get("asset_name") or asset_id),
            str(row.get("asset_type") or "") or None,
            str(row.get("asset_category") or "") or None,
            ip,
            str(row.get("ip_or_type_raw") or "") or None,
            str(row.get("cluster") or "") or None,
            site or None,
            str(row.get("current_location") or site or "") or None,
            parent_id,
            label or None,
            str(row.get("capacity") or "") or None,
            str(row.get("replacement_target") or "") or None,
            status,
            str(row.get("usage_status_label") or "") or None,
            as_date(row.get("usage_start_date")),
            as_date(row.get("handover_date")),
            str(row.get("handover_status") or "") or None,
            str(row.get("purchase_invoice") or "") or None,
            as_int(row.get("purchase_price_vnd")),
            supplier_code or None,
            str(row.get("supplier_name") or "") or None,
            as_int(row.get("warranty_months")),
            as_date(row.get("warranty_end_date")),
            str(row.get("description") or "") or None,
            str(row.get("source_sheet") or "") or None,
            as_int(row.get("source_row")),
            as_flags(row.get("review_flags")),
        )
        conn.execute(
            """
            INSERT INTO asset (asset_id, asset_name, asset_type, asset_category, ip_address,
                ip_or_type_raw, cluster, datacenter, current_location, parent_asset_id,
                attachment_label, capacity, replacement_target, usage_status, usage_status_label,
                usage_start_date, handover_date, handover_status, purchase_invoice,
                purchase_price_vnd, supplier_code, supplier_name, warranty_months,
                warranty_end_date, description, source_sheet, source_row, review_flags)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (asset_id) DO UPDATE SET
                asset_name = EXCLUDED.asset_name, asset_type = EXCLUDED.asset_type,
                asset_category = EXCLUDED.asset_category, ip_address = EXCLUDED.ip_address,
                ip_or_type_raw = EXCLUDED.ip_or_type_raw, cluster = EXCLUDED.cluster,
                datacenter = EXCLUDED.datacenter, current_location = EXCLUDED.current_location,
                parent_asset_id = EXCLUDED.parent_asset_id, attachment_label = EXCLUDED.attachment_label,
                capacity = EXCLUDED.capacity, replacement_target = EXCLUDED.replacement_target,
                usage_status = EXCLUDED.usage_status, usage_status_label = EXCLUDED.usage_status_label,
                usage_start_date = EXCLUDED.usage_start_date, handover_date = EXCLUDED.handover_date,
                handover_status = EXCLUDED.handover_status, purchase_invoice = EXCLUDED.purchase_invoice,
                purchase_price_vnd = EXCLUDED.purchase_price_vnd, supplier_code = EXCLUDED.supplier_code,
                supplier_name = EXCLUDED.supplier_name, warranty_months = EXCLUDED.warranty_months,
                warranty_end_date = EXCLUDED.warranty_end_date, description = EXCLUDED.description,
                source_sheet = EXCLUDED.source_sheet, source_row = EXCLUDED.source_row,
                review_flags = EXCLUDED.review_flags, updated_at = now()
            """,
            params,
        )
        if asset_id in known:
            updated += 1
        else:
            added += 1
            known.add(asset_id)
    conn.execute(
        "UPDATE asset a SET site_id = s.id FROM site s WHERE s.name = a.datacenter AND a.site_id IS DISTINCT FROM s.id"
    )
    return {"added": added, "updated": updated}


def upsert_events(conn: psycopg.Connection, rows: list[dict]) -> dict:
    known = {row["asset_id"] for row in conn.execute("SELECT asset_id FROM asset").fetchall()}
    applied = skipped = 0
    for row in rows:
        asset_id = str(row.get("asset_id", "")).strip()
        if not asset_id or asset_id not in known:
            skipped += 1
            continue
        conn.execute(
            """
            INSERT INTO asset_event (asset_id, event_sequence, event_type, event_date, location,
                usage_object, notes, declared_transition_count, source_column, source_row, review_flags)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (asset_id, event_sequence) DO UPDATE SET
                event_type = EXCLUDED.event_type, event_date = EXCLUDED.event_date,
                location = EXCLUDED.location, usage_object = EXCLUDED.usage_object,
                notes = EXCLUDED.notes, declared_transition_count = EXCLUDED.declared_transition_count,
                source_column = EXCLUDED.source_column, source_row = EXCLUDED.source_row,
                review_flags = EXCLUDED.review_flags
            """,
            (
                asset_id,
                as_int(row.get("event_sequence")) or 0,
                str(row.get("event_type") or "") or None,
                as_date(row.get("event_date")),
                str(row.get("location") or "") or None,
                str(row.get("usage_object") or "") or None,
                str(row.get("notes") or "") or None,
                as_int(row.get("declared_transition_count")),
                str(row.get("source_column") or "") or None,
                as_int(row.get("source_row")),
                as_flags(row.get("review_flags")),
            ),
        )
        applied += 1
    return {"applied": applied, "skipped_unknown_asset": skipped}


def read_upload(upload: UploadFile) -> list[dict]:
    raw = upload.file.read()
    if len(raw) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File vượt quá 10MB.")
    try:
        body = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="File phải là CSV mã hóa UTF-8.")
    rows = list(csv.DictReader(io.StringIO(body)))
    if not rows:
        raise HTTPException(status_code=400, detail="File không có dòng dữ liệu nào.")
    return rows


@app.post("/api/import/assets")
def import_assets(file: UploadFile = File(...), user: dict = Depends(current_user)) -> dict:
    rows = read_upload(file)
    if "asset_id" not in (rows[0].keys()):
        raise HTTPException(status_code=400, detail="Thiếu cột asset_id.")
    with connect() as conn:
        result = upsert_assets(conn, rows)
        conn.commit()
    return {"rows": len(rows), **result}


@app.post("/api/import/history")
def import_history(file: UploadFile = File(...), user: dict = Depends(current_user)) -> dict:
    rows = read_upload(file)
    if "asset_id" not in (rows[0].keys()):
        raise HTTPException(status_code=400, detail="Thiếu cột asset_id.")
    with connect() as conn:
        result = upsert_events(conn, rows)
        conn.commit()
    return {"rows": len(rows), **result}


# --------------------------------------------------------- sửa/xóa hàng loạt
# Tên cột ghép thẳng vào câu SQL nên BẮT BUỘC whitelist, chia theo kiểu để ép giá trị đúng.
BULK_TEXT = {
    "cluster", "replacement_target", "asset_type", "capacity",
    "handover_status", "purchase_invoice", "supplier_code", "supplier_name",
}
BULK_DATE = {"usage_start_date", "handover_date", "warranty_end_date"}
BULK_INT = {"warranty_months", "purchase_price_vnd"}
# Ba trường dưới đây cần xử lý riêng, không ghi thẳng vào cột cùng tên.
BULK_SPECIAL = {"usage_status", "datacenter", "parent_reference"}
BULK_FIELDS = BULK_TEXT | BULK_DATE | BULK_INT | BULK_SPECIAL


def bulk_ids(payload: dict) -> list[str]:
    ids = [str(item).strip() for item in (payload.get("ids") or []) if str(item).strip()]
    if not ids:
        raise HTTPException(status_code=400, detail="Chưa chọn tài sản nào.")
    if len(ids) > 5000:
        raise HTTPException(status_code=400, detail="Tối đa 5000 tài sản mỗi lần.")
    return ids


@app.post("/api/assets/bulk-update")
def bulk_update(payload: dict, user: dict = Depends(current_user)) -> dict:
    ids = bulk_ids(payload)
    raw = {
        key: str(value).strip()
        for key, value in (payload.get("changes") or {}).items()
        if key in BULK_FIELDS
    }
    if not raw:
        raise HTTPException(status_code=400, detail="Chưa chọn trường nào để sửa.")
    with connect() as conn:
        columns_values: dict[str, Any] = {}
        for key, value in raw.items():
            if key in BULK_SPECIAL:
                continue
            if key in BULK_DATE:
                parsed = as_date(value)
                if value and parsed is None:
                    raise HTTPException(status_code=400, detail=f"Ngày không hợp lệ ở trường {key}: {value}")
                columns_values[key] = parsed
            elif key in BULK_INT:
                parsed = as_int(value)
                if value and parsed is None:
                    raise HTTPException(status_code=400, detail=f"Giá trị phải là số ở trường {key}: {value}")
                columns_values[key] = parsed
            else:
                columns_values[key] = value or None

        if "usage_status" in raw:
            status = raw["usage_status"]
            known = conn.execute("SELECT code FROM status_catalog WHERE code = %s", (status,)).fetchone()
            if not known:
                raise HTTPException(status_code=400, detail=f"Trạng thái {status} không có trong danh mục.")
            columns_values["usage_status"] = status
            # usage_status_label là chữ NGUYÊN VĂN của sổ Excel. Đổi trạng thái bằng tay thì
            # sổ không còn nói gì về giá trị mới -> để trống, không gán nhãn danh mục vào đó.
            columns_values["usage_status_label"] = None
        if "datacenter" in raw:
            site = raw["datacenter"]
            if site:
                conn.execute(
                    "INSERT INTO site (name, kind) VALUES (%s, %s) ON CONFLICT (name) DO NOTHING",
                    (site, "warehouse" if site.lower().startswith("kho") else "datacenter"),
                )
            columns_values["datacenter"] = site or None
            columns_values["current_location"] = site or None
        if "parent_reference" in raw:
            ref = raw["parent_reference"]
            exists = conn.execute("SELECT asset_id FROM asset WHERE asset_id = %s", (ref,)).fetchone() if ref else None
            # Khớp mã -> quan hệ cha thật; không khớp -> chỉ là nhãn cụm, không ép thành cha con.
            columns_values["parent_asset_id"] = exists["asset_id"] if exists else None
            columns_values["attachment_label"] = None if exists else (ref or None)

        columns = ", ".join(f"{key} = %s" for key in columns_values)
        params = list(columns_values.values()) + [ids]
        if "parent_asset_id" in columns_values and columns_values["parent_asset_id"]:
            # Không cho thiết bị tự làm cha của chính nó.
            result = conn.execute(
                f"UPDATE asset SET {columns}, updated_at = now()"
                " WHERE asset_id = ANY(%s) AND asset_id <> %s",
                params + [columns_values["parent_asset_id"]],
            )
        else:
            result = conn.execute(
                f"UPDATE asset SET {columns}, updated_at = now() WHERE asset_id = ANY(%s)", params
            )
        updated = result.rowcount
        conn.execute(
            "UPDATE asset a SET site_id = s.id FROM site s"
            " WHERE s.name = a.datacenter AND a.site_id IS DISTINCT FROM s.id"
        )
        conn.commit()
    return {"updated": updated, "fields": sorted(columns_values)}


@app.post("/api/assets/bulk-delete")
def bulk_delete(payload: dict, user: dict = Depends(current_user)) -> dict:
    ids = bulk_ids(payload)
    with connect() as conn:
        result = conn.execute("DELETE FROM asset WHERE asset_id = ANY(%s)", (ids,))
        deleted = result.rowcount
        conn.commit()
    return {"deleted": deleted}


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


@app.get("/api/export/assets.csv")
def export_assets(user: dict = Depends(current_user)) -> StreamingResponse:
    with connect() as conn:
        rows = conn.execute("SELECT * FROM asset ORDER BY source_row NULLS LAST, asset_id").fetchall()
    payload = []
    for row in rows:
        item = dict(row)
        item["parent_reference"] = row["parent_asset_id"] or row["attachment_label"]
        payload.append(item)
    return csv_response("asset_export.csv", ASSET_COLUMNS, payload)


@app.get("/api/export/history.csv")
def export_history(user: dict = Depends(current_user)) -> StreamingResponse:
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM asset_event ORDER BY source_row NULLS LAST, asset_id, event_sequence"
        ).fetchall()
    return csv_response("asset_history_export.csv", HISTORY_COLUMNS, [dict(row) for row in rows])
