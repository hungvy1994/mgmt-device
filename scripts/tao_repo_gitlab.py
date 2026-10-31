"""Tạo repo trên GitLab và đẩy README lên. KHÔNG đẩy mã nguồn.

    GITLAB_TOKEN=<token> python3 scripts/tao_repo_gitlab.py [--host gitlab.infra.matbao.io] [--ten mgmt-device]

Token phải là Personal Access Token có quyền `api` của CHÍNH người chạy — không dùng
token của người khác, kể cả token đang có sẵn trong workspace (xem CLAUDE.md, mục Identity).
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--host", default="gitlab.infra.matbao.io")
parser.add_argument("--ten", default="mgmt-device")
parser.add_argument("--nhom", default="", help="namespace_id hoặc để trống = tài khoản cá nhân")
parser.add_argument("--readme", default="docs/README-gitlab.md")
args = parser.parse_args()

token = os.environ.get("GITLAB_TOKEN", "").strip()
if not token:
    sys.exit("Thiếu GITLAB_TOKEN. Lấy ở GitLab → Settings → Access Tokens (quyền: api).")

API = f"https://{args.host}/api/v4"


def goi(duong_dan: str, method: str = "GET", body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{duong_dan}", data=data, method=method,
        headers={"PRIVATE-TOKEN": token, **({"Content-Type": "application/json"} if data else {})},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {duong_dan} → {e.code}: {e.read().decode()[:300]}")


toi = goi("/user")
print(f"đăng nhập với: {toi['username']} ({toi.get('public_email') or '—'})")

# Repo đã có thì dùng lại, không tạo trùng.
tim = goi(f"/projects?search={urllib.parse.quote(args.ten)}&owned=true")
du_an = next((p for p in tim if p["path"] == args.ten), None)
if du_an:
    print(f"repo đã có: {du_an['web_url']}")
else:
    than = {"name": args.ten, "path": args.ten, "visibility": "private",
            "description": "Quản lý tài sản hạ tầng Mắt Bão — team sa",
            "initialize_with_readme": False}
    if args.nhom:
        than["namespace_id"] = int(args.nhom)
    du_an = goi("/projects", "POST", than)
    print(f"đã tạo repo: {du_an['web_url']}")

noi_dung = Path(args.readme).read_text(encoding="utf-8")
duong = f"/projects/{du_an['id']}/repository/files/README.md"
than = {"branch": du_an.get("default_branch") or "main", "content": noi_dung,
        "commit_message": "Thêm README: mô tả ứng dụng và kế hoạch dự án"}
try:
    goi(duong, "POST", than)
    print("đã tạo README.md")
except SystemExit as loi:
    if "already exists" not in str(loi):
        raise
    goi(duong, "PUT", {**than, "commit_message": "Cập nhật README"})
    print("đã cập nhật README.md")
print(f"xong → {du_an['web_url']}")
