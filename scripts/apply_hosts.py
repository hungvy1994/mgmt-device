"""Bồi thông tin cho 7 server (PUT từng trường, không ghi đè cả bản ghi)."""
import json, subprocess, sys, urllib.error, urllib.request
BASE = "http://127.0.0.1:8084"
OPENER = urllib.request.build_opener(urllib.request.HTTPCookieProcessor())

def call(path, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{BASE}{path}", data=data, method=method,
                                 headers={"Content-Type": "application/json"} if data else {})
    try:
        with OPENER.open(req) as r: return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read().decode())

call("/api/login", "POST", {"username": "admin", "password": sys.argv[1]})
updates = json.load(open(sys.argv[2], encoding="utf-8"))
for item in updates:
    code = item.pop("asset_id")
    status, body = call(f"/api/assets/{code}", "PUT", item)
    mark = "OK " if status == 200 else f"{status}"
    # Khối nào không có trường nào thì bỏ qua trường đó — đừng giả định đủ khóa
    shown = " ".join(f"{k}={v}" for k, v in item.items() if v)
    print(f"   {mark} {code}  {shown}")
    if status != 200:
        print("      ", body)
