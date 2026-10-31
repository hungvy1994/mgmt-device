"""Tên máy tủ J3/J4 mang sẵn đuôi IP ("Node ClusterX113 - 49.167") -> nối thẳng bằng tên.

Khác tủ AQ53/AQ54 (tên là "Node VNPT104", không mang IP, phải đi vòng qua sổ Excel gốc).
Vẫn đối chiếu chéo lại với sổ gốc ở những IP sổ có, và dừng nếu một IP khớp 0 hoặc >1 máy.
"""
import csv
import json
import re
import sys
from pathlib import Path

HOST_CSV, DB_CSV, BOOK_CSV, OUT = (Path(a) for a in sys.argv[1:5])
RACKS = set(sys.argv[5].split(","))
# Mặc định một IP không nối được là DỪNG. Bỏ qua phải là hành động cố ý, khai báo rõ,
# vì bỏ qua im lặng nghĩa là ổ của máy đó biến mất mà không ai biết.
SKIP_UNMATCHED = "--bo-qua-khong-khop" in sys.argv
# Máy đổi IP: tên trong sổ đăng ký vẫn mang IP CŨ nên nối bằng tên sẽ trượt. Khai
# --ip-cu <IP mới>=<IP cũ> để nối bằng IP cũ, còn IP ghi vào hồ sơ vẫn là IP mới.
IP_ALIAS = dict(a.split("=", 1) for a in sys.argv[1:] if a.startswith("103.") and "=" in a)

ips = [r["Management interface IP"].strip()
       for r in csv.DictReader(HOST_CSV.open(encoding="utf-8-sig"))]

by_frag: dict[str, list] = {}
for row in csv.reader(DB_CSV.open(encoding="utf-8")):
    if not row or row[0] == "asset_id":
        continue
    asset_id, name, rack, unit, site = row[:5]
    found = re.search(r"(\d{1,3}\.\d{1,3})\s*$", name)     # đuôi "- 49.167"
    if found and rack in RACKS:
        by_frag.setdefault(found.group(1), []).append({"asset_id": asset_id, "site": site,
                                                       "rack": rack, "name": name, "unit": unit})

book = {}
for row in csv.DictReader(BOOK_CSV.open(encoding="utf-8-sig")):
    ip = (row.get("ip_address") or "").strip()
    if ip:
        book[ip] = (row.get("asset_id") or "").strip()

mapping, problems, crossed = {}, [], 0
print(f"{'IP':<16}{'mã đang dùng':<13}{'rack':<6}{'tên trong hệ thống':<30}đối chiếu sổ gốc")
for ip in ips:
    lookup = IP_ALIAS.get(ip, ip)          # tra bằng IP cũ nếu máy đã đổi IP
    hit = by_frag.get(".".join(lookup.split(".")[2:]), [])
    if len(hit) != 1:
        problems.append(f"{ip}: khớp {len(hit)} máy — không nối")
        continue
    one = hit[0]
    mapping[ip] = {"asset_id": one["asset_id"], "site": one["site"], "rack": one["rack"]}
    old = book.get(lookup, "")
    if old:
        # mã cũ SVR-J4-2324 = rack J4, máy chiếm U23-24 -> phải khớp cả rack lẫn U
        found = re.match(r"^[A-Z]+-([A-Z]+\d+)-(\d{2})\d*$", old)
        ok = bool(found) and found.group(1) == one["rack"] and int(found.group(2)) == int(one["unit"])
        crossed += ok
        note = f"{old} {'khớp' if ok else 'LỆCH'}"
        if not ok:
            problems.append(f"{ip}: sổ gốc ghi {old} nhưng hệ thống là {one['asset_id']}")
    else:
        note = "(sổ gốc không có IP này)"
    if ip in IP_ALIAS:
        note += f" · nối qua IP cũ {IP_ALIAS[ip]}"
    print(f"{ip:<16}{one['asset_id']:<13}{one['rack']:<6}{one['name']:<30}{note}")

print(f"\n{len(ips)} IP · nối được {len(mapping)} · đối chiếu chéo khớp {crossed}")
codes = [v["asset_id"] for v in mapping.values()]
if len(set(codes)) != len(codes):
    problems.append("hai IP cùng trỏ về một mã tài sản")
print("vấn đề:", problems if problems else "không có")
if problems and not SKIP_UNMATCHED:
    sys.exit(1)
if problems:
    print("=> BỎ QUA có chủ ý: những máy trên không được bồi thông tin và ổ của chúng KHÔNG được tạo.")
OUT.write_text(json.dumps(mapping, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"-> {OUT.name}")
