"""Dựng ánh xạ IP quản trị -> mã tài sản cho bản xuất host_*.csv, có bằng chứng.

Bản xuất hệ thống ảo hóa chỉ có IP; hệ thống lại đặt mã theo rack + vị trí U. Nối hai
đầu bằng SỔ EXCEL GỐC (asset_import.csv) — sổ này có cả IP lẫn rack/U của từng máy:

    IP (host csv)  ->  sổ gốc: tên máy + rack + vị trí U  ->  mã tài sản đang dùng

Mỗi mắt xích phải khớp, lệch một chỗ là dừng chứ không đoán. Ghi ra map.json để
host_to_disks.py dùng, kèm bản đối chiếu in ra màn hình cho người đọc kiểm lại.
"""
import csv
import json
import re
import sys
from pathlib import Path

HOST_CSV = Path(sys.argv[1])       # bản xuất hệ thống ảo hóa
WORKBOOK_CSV = Path(sys.argv[2])   # asset_import.csv (bóc từ sổ Excel gốc)
DB_CSV = Path(sys.argv[3])         # ảnh chụp asset hiện tại trong database
OUT = Path(sys.argv[4])

ips = [row["Management interface IP"].strip()
       for row in csv.DictReader(HOST_CSV.open(encoding="utf-8-sig"))]

# --- mắt xích 1: sổ Excel gốc, IP -> (rack, vị trí U, tên máy) ---------------
book = {}
for row in csv.DictReader(WORKBOOK_CSV.open(encoding="utf-8-sig")):
    ip = (row.get("ip_address") or "").strip()
    if not ip:
        continue
    # Mã cũ trong sổ có dạng SVR-AQ53-3031 = rack AQ53, máy chiếm U30-31 -> lấy U đầu
    found = re.match(r"^[A-Z]+-([A-Z]+\d+)-(\d{2})\d*$", (row.get("asset_id") or "").strip())
    if found:
        book[ip] = {"rack": found.group(1), "unit": int(found.group(2)),
                    "name": (row.get("asset_name") or "").strip(),
                    "old_code": row["asset_id"].strip()}

# --- mắt xích 2: database, (rack, U) -> mã tài sản đang dùng -----------------
live = {}
for row in csv.reader(DB_CSV.open(encoding="utf-8")):
    if row[0] == "asset_id":
        continue
    asset_id, name, rack, unit, site = row[:5]
    if rack and unit:
        live[(rack, int(unit))] = {"asset_id": asset_id, "name": name, "site": site}

mapping, table, problems = {}, [], []
for ip in ips:
    entry = book.get(ip)
    if not entry:
        problems.append(f"{ip}: sổ Excel gốc không có IP này")
        continue
    target = live.get((entry["rack"], entry["unit"]))
    if not target:
        problems.append(f"{ip}: sổ ghi {entry['rack']} U{entry['unit']} nhưng database không có máy nào ở đó")
        continue
    mapping[ip] = {"asset_id": target["asset_id"], "site": target["site"], "rack": entry["rack"]}
    table.append((ip, entry["old_code"], entry["name"], f"{entry['rack']} U{entry['unit']}",
                  target["asset_id"], target["name"]))

print(f"{len(ips)} IP trong bản xuất · nối được {len(mapping)}\n")
print(f"{'IP':<16}{'mã sổ cũ':<16}{'tên sổ':<10}{'vị trí':<12}{'mã đang dùng':<15}tên trong hệ thống")
for line in table:
    print(f"{line[0]:<16}{line[1]:<16}{line[2]:<10}{line[3]:<12}{line[4]:<15}{line[5]}")

codes = [v["asset_id"] for v in mapping.values()]
if len(set(codes)) != len(codes):
    problems.append("hai IP cùng trỏ về một mã tài sản")
print("\nvấn đề:", problems if problems else "không có")
if problems:
    sys.exit(1)
OUT.write_text(json.dumps(mapping, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"-> {OUT.name}")
