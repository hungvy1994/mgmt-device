"""netbox_devices (1).csv -> file nhập của Device Management.

Sổ NetBox không có mã tài sản. Theo quy tắc anh đưa: mã = loại thiết bị + rack + vị trí U
(vd server ở tủ P07 vị trí U42 -> svr-p07-u42). Mã rack lấy theo ĐÚNG tên trong danh mục
vị trí của hệ thống (CSV ghi "P7", danh mục ghi "P07"), không thì lúc nhập rack không khớp.
"""
import csv
import sys
import unicodedata
from pathlib import Path

SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else "netbox_devices (1).csv")
OUTPUT = Path(sys.argv[2] if len(sys.argv) > 2 else "netbox_assets_import.csv")

# Tên rack trong CSV -> tên rack trong danh mục vị trí. Chỉ một chỗ lệch.
RACK_ALIAS = {"P7": "P07"}

# Role trong NetBox -> (tiền tố mã, mã loại tài sản trong danh mục)
ROLE_MAP = {
    "Compute & Storage": ("svr", "server"),
    "Compute": ("svr", "server"),
    "Standalone Server": ("svr", "server"),
    "Core Switch": ("sw", "switch"),
    "Access Switch": ("sw", "switch"),
    # Cisco Nexus làm mạng lưu trữ — vẫn là switch, không phải thiết bị lưu trữ
    "Layer2 Storage": ("sw", "switch"),
    "Firewall": ("fw", "firewall"),
    "HSM": ("hsm", "hsm"),
    "NAS": ("sto", "storage"),
}
# Hãng ghi rõ là tủ đĩa thì đi theo hãng, không theo Role (DAS đang để Role "Standalone Server")
MAKER_OVERRIDE = {"DAS": ("sto", "storage"), "NAS 2U": ("sto", "storage")}

COLUMNS = [
    "asset_id", "code_pending", "asset_name", "asset_type", "asset_category", "ip_address",
    "ip_or_type_raw", "cluster", "in_store", "datacenter", "current_location", "rack",
    "rack_unit", "parent_reference", "capacity", "replacement_target", "usage_status",
    "usage_status_label", "usage_start_date", "handover_date", "handover_status",
    "purchase_invoice", "purchase_price_vnd", "supplier_code", "supplier_name",
    "warranty_months", "warranty_end_date", "description", "source_sheet", "source_row",
    "review_flags",
]


def slug(value: str) -> str:
    stripped = unicodedata.normalize("NFD", value)
    return "".join(ch for ch in stripped if unicodedata.category(ch) != "Mn").lower()


rows = list(csv.DictReader(SOURCE.open(encoding="utf-8-sig")))
out: list[dict] = []
used: dict[str, str] = {}
problems: list[str] = []

for index, row in enumerate(rows, start=2):
    name = row["Name"].strip()
    rack = RACK_ALIAS.get(row["Rack"].strip(), row["Rack"].strip())
    site = row["Site"].strip()
    maker = row["Manufacturer"].strip()
    role = row["Role"].strip()
    prefix, kind = MAKER_OVERRIDE.get(maker) or ROLE_MAP.get(role, ("dev", "unknown"))
    if role not in ROLE_MAP and maker not in MAKER_OVERRIDE:
        problems.append(f"dòng {index}: chưa biết xếp loại '{role}' ({name})")

    try:
        unit = int(float(row["Position"]))
    except ValueError:
        problems.append(f"dòng {index}: vị trí U không đọc được '{row['Position']}' ({name})")
        continue

    # U đệm 2 chữ số cho khớp cách đặt tên rack (P07, M08) và để sắp xếp đúng thứ tự
    code = f"{prefix}-{slug(rack)}-u{unit:02d}"
    if code in used:
        problems.append(f"dòng {index}: mã {code} trùng với {used[code]}")
        continue
    used[code] = name

    out.append({
        "asset_id": code,
        "asset_name": name,
        "asset_type": kind,
        "datacenter": site,
        "current_location": site,
        "rack": rack,
        "rack_unit": unit,
        # NetBox chỉ có Active; đối chiếu danh mục trạng thái của hệ thống là "đang vận hành"
        "usage_status": "in_use" if row["Status"].strip() == "Active" else "",
        # Hãng + model là thông tin thật, không cột nào khác giữ nó
        "description": " ".join(part for part in (maker, row["Type"].strip()) if part),
        "source_sheet": SOURCE.name,
        "source_row": index,
        "code_pending": "",
        "in_store": "",
    })

with OUTPUT.open("w", encoding="utf-8-sig", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=COLUMNS, extrasaction="ignore")
    writer.writeheader()
    for item in out:
        writer.writerow({key: item.get(key, "") for key in COLUMNS})

print(f"Đọc {len(rows)} dòng · dựng {len(out)} tài sản -> {OUTPUT.name}")
from collections import Counter
print("theo loại :", dict(Counter(item['asset_type'] for item in out)))
print("theo site :", dict(Counter(item['datacenter'] for item in out)))
print("theo rack :", dict(Counter(item['rack'] for item in out)))
print("\nví dụ mã:")
for item in out[:6]:
    print(f"   {item['asset_id']:<16} {item['asset_name'][:34]:<34} {item['datacenter']} / {item['rack']} U{item['rack_unit']}")
print("\nvấn đề:", problems if problems else "không có")
