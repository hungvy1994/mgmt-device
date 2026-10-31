"""Sinh cáp cho những rack có ĐÚNG 2 switch storage, theo quy tắc đấu nối của hệ thống.

    rack_cables.py <ảnh chụp asset>.csv <file nhập>.csv

Quy tắc (do người quản trị đặt):
  - rack có đúng 2 switch storage  ->  mỗi switch 1 sợi 10Gbps + 1 sợi 20Gbps
  - cùng rack đó                   ->  mỗi server thêm 2 sợi 10Gbps

Cáp là LINH KIỆN gắn vào thiết bị (parent_reference), cùng site/rack với thiết bị nhưng
không chiếm ô U — giống cách ổ cứng đang gắn. Cáp của server gắn vào chính server, để
server chuyển đi thì cáp theo cùng và nhìn sơ đồ biết ngay máy nào có mấy sợi.

Rack có 0 hoặc 1 switch storage thì KHÔNG đụng tới, và script in ra để người đọc thấy vì sao.
"""
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

SNAPSHOT = Path(sys.argv[1])
OUTPUT = Path(sys.argv[2])

# Cáp: (tiền tố, nhãn, mô tả). Quy ước <loại>-<thông số>-<số thứ tự> như ssd-/hdd-/raid-.
CABLE_10G = ("cab-10g", "Cáp 10Gbps")
CABLE_20G = ("cab-20g", "Cáp 20Gbps")
RULE = "Sinh theo quy tắc: rack có 2 switch storage"

COLUMNS = [
    "asset_id", "code_pending", "asset_name", "asset_type", "asset_category", "ip_address",
    "ip_or_type_raw", "cluster", "in_store", "datacenter", "current_location", "rack",
    "rack_unit", "parent_reference", "capacity", "replacement_target", "usage_status",
    "usage_status_label", "usage_start_date", "handover_date", "handover_status",
    "purchase_invoice", "purchase_price_vnd", "supplier_code", "supplier_name",
    "warranty_months", "warranty_end_date", "serial", "description", "source_sheet",
    "source_row", "review_flags",
]


def is_storage_switch(row: dict) -> bool:
    """Switch storage nhận ra bằng TÊN. NetBox có Role 'Layer2 Storage' chuẩn hơn nhưng
    role không được lưu vào database, nên tên là thứ duy nhất tra được tại chỗ."""
    return row["asset_type"] == "switch" and "storage" in row["asset_name"].lower()


rows = []
for line in csv.reader(SNAPSHOT.open(encoding="utf-8")):
    if not line or line[0] == "asset_id":
        continue
    rows.append(dict(zip(("asset_id", "asset_name", "asset_type", "rack", "rack_unit", "site"),
                         line[:6])))

# Số thứ tự chạy tiếp theo cáp đã có, không đánh lại từ 001.
counters = {CABLE_10G[0]: 0, CABLE_20G[0]: 0}
for row in rows:
    found = re.match(r"^(.+)-(\d{3,})$", row["asset_id"])
    if found and found.group(1) in counters:
        counters[found.group(1)] = max(counters[found.group(1)], int(found.group(2)))

by_rack = defaultdict(list)
for row in rows:
    if row["rack"]:
        by_rack[row["rack"]].append(row)

cables, skipped = [], []


def add(prefix_label: tuple, host: dict, note: str) -> None:
    prefix, label = prefix_label
    counters[prefix] += 1
    cables.append({
        "asset_id": f"{prefix}-{counters[prefix]:03d}",
        "asset_name": label,
        "asset_type": "cable",
        "parent_reference": host["asset_id"],
        "datacenter": host["site"],
        "current_location": host["site"],
        "rack": host["rack"],          # cùng chỗ với thiết bị; cáp không chiếm ô U nào
        "usage_status": "in_use",
        "description": note,
        "source_sheet": RULE,
    })


for rack in sorted(by_rack):
    items = by_rack[rack]
    switches = sorted([r for r in items if is_storage_switch(r)], key=lambda r: r["asset_id"])
    servers = sorted([r for r in items if r["asset_type"] == "server"], key=lambda r: r["asset_id"])
    if len(switches) != 2:
        skipped.append(f"{rack}: {len(switches)} switch storage — bỏ qua "
                       f"({', '.join(s['asset_id'] for s in switches) or 'không có'})")
        continue
    for switch in switches:
        add(CABLE_10G, switch, "Cáp 10Gbps của switch storage")
        add(CABLE_20G, switch, "Cáp 20Gbps của switch storage")
    for server in servers:
        for _ in range(2):
            add(CABLE_10G, server, "Cáp 10Gbps nối server với switch storage")
    print(f"   {rack:<6}{len(switches)} switch storage ({', '.join(s['asset_id'] for s in switches)})"
          f" · {len(servers)} server -> {len(switches) * 2 + len(servers) * 2} sợi")

with OUTPUT.open("w", encoding="utf-8-sig", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=COLUMNS, extrasaction="ignore")
    writer.writeheader()
    for item in cables:
        writer.writerow({key: item.get(key, "") for key in COLUMNS})

ten = sum(1 for c in cables if c["asset_name"] == CABLE_10G[1])
print(f"\nDựng {len(cables)} sợi -> {OUTPUT.name}   ({ten} × 10Gbps · {len(cables) - ten} × 20Gbps)")
print("\nRack không áp quy tắc:")
for line in skipped:
    print("   ", line)
