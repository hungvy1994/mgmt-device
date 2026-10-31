"""Nạp hai file CSV vào Postgres. Chạy được nhiều lần (upsert theo khóa).

Trong docker compose đây là service `seed` chạy một lần rồi thoát.
Chạy tay:  docker compose run --rm seed
"""
from __future__ import annotations

import csv
import os
import secrets
import sys
from pathlib import Path

from app import SCHEMA_PATCH, connect, hash_password, upsert_assets, upsert_events

DATA_DIR = Path(os.environ.get("SEED_DIR", "/data"))
ASSET_CSV = DATA_DIR / "asset_import.csv"
HISTORY_CSV = DATA_DIR / "asset_history_import.csv"
FORCE = os.environ.get("SEED_FORCE", "").lower() in {"1", "true", "yes"}


def read_csv(path: Path) -> list[dict]:
    if not path.exists():
        sys.exit(f"Không tìm thấy {path}")
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def ensure_admin(conn) -> None:
    """Tạo tài khoản quản trị đầu tiên. Mật khẩu lấy từ ADMIN_PASSWORD; không đặt thì
    sinh ngẫu nhiên và in ra đúng một lần — không có mật khẩu mặc định nằm trong repo."""
    conn.execute(SCHEMA_PATCH)
    username = os.environ.get("ADMIN_USERNAME", "admin").strip().lower()
    if not username:
        print("Bỏ qua tạo tài khoản: chưa đặt ADMIN_USERNAME.")
        return
    existing = conn.execute("SELECT id FROM app_user WHERE lower(username) = %s", (username,)).fetchone()
    if existing and not FORCE:
        print(f"Tài khoản {username} đã có — bỏ qua. Đặt SEED_FORCE=1 để đặt lại mật khẩu.")
        return
    password = os.environ.get("ADMIN_PASSWORD", "").strip()
    generated = not password
    if generated:
        password = secrets.token_urlsafe(12)
    conn.execute(
        """
        INSERT INTO app_user (username, email, full_name, role, password_hash)
        VALUES (%s, %s, %s, 'admin', %s)
        ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash,
            email = EXCLUDED.email, full_name = EXCLUDED.full_name, is_active = TRUE
        """,
        (username, os.environ.get("ADMIN_EMAIL") or None,
         os.environ.get("ADMIN_NAME", "Quản trị viên"), hash_password(password)),
    )
    conn.execute("DELETE FROM user_session WHERE user_id IN (SELECT id FROM app_user WHERE lower(username) = %s)", (username,))
    action = "Đã tạo" if not existing else "Đã đặt lại mật khẩu"
    print(f"{action} tài khoản quản trị: {username}")
    if generated:
        print(f"  Mật khẩu sinh ngẫu nhiên (chỉ hiện một lần): {password}")


def main() -> None:
    with connect() as conn:
        ensure_admin(conn)
        conn.commit()
        existing = conn.execute("SELECT count(*) AS n FROM asset").fetchone()["n"]
        if existing and not FORCE:
            print(f"Database đã có {existing} tài sản — bỏ qua. Đặt SEED_FORCE=1 để nạp đè.")
            return
        assets = read_csv(ASSET_CSV)
        events = read_csv(HISTORY_CSV)
        asset_result = upsert_assets(conn, assets)
        event_result = upsert_events(conn, events)
        conn.commit()
        counts = conn.execute(
            "SELECT (SELECT count(*) FROM asset) AS assets,"
            " (SELECT count(*) FROM asset_event) AS events,"
            " (SELECT count(*) FROM site) AS sites,"
            " (SELECT count(*) FROM status_catalog) AS statuses,"
            " (SELECT count(*) FROM asset WHERE review_flags <> '{}') AS flagged"
        ).fetchone()
    print(f"asset_import.csv: {len(assets)} dòng -> {asset_result}")
    print(f"asset_history_import.csv: {len(events)} dòng -> {event_result}")
    print(
        f"Trong database: {counts['assets']} tài sản, {counts['events']} sự kiện, "
        f"{counts['sites']} site, {counts['statuses']} trạng thái, {counts['flagged']} bản ghi có cờ review"
    )


if __name__ == "__main__":
    main()
