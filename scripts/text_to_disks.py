"""Khối mô tả máy gõ tay -> bồi thông tin máy + file nhập ổ cứng.

    text_to_disks.py <khối mô tả>.txt <ảnh chụp asset>.csv <file nhập>.csv

Khác `host_to_disks.py` ở chỗ nguồn không phải bản xuất CSV mà là khối chữ người quản trị
gõ, và **mã tài sản đã cho sẵn** nên không phải nối IP. Mỗi máy một khối, ngăn bằng dòng trống:

    odsvps02 svr-d12-u31          <- tên máy + mã tài sản đã có trong hệ thống
    10.10.70.12                   <- IP quản trị (có thể không có)
    Intel(R) Xeon(R) CPU ...      <- CPU (có thể không có)
    RAM 251.8 GiB · SSD 4×1.92 TB + HDD 6×4.00 TB

Dùng chung DISK_KINDS với host_to_disks.py — một chỗ duy nhất quyết định tiền tố mã ổ.
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from host_to_disks import COLUMNS, DISK_KINDS  # noqa: E402

SOURCE, SNAPSHOT, OUTPUT = (Path(a) for a in sys.argv[1:4])

# Cùng một loại ổ được hai công cụ ghi hai kiểu ("1.9TB" / "1.92 TB", "4.0TB" / "4.00 TB").
# Gộp về CÁCH GHI ĐANG DÙNG trong database để danh mục không có hai tên cho một loại ổ.
SIZE_ALIAS = {"1.92TB": "1.9TB", "4.00TB": "4.0TB", "240GB": "240.06GB", "960GB": "960.20GB",
              "480GB": "480.10GB", "2.00TB": "2TB"}

known = {row[0] for row in csv.reader(SNAPSHOT.open(encoding="utf-8"))}
counters: dict[str, int] = {}
for asset_id in known:
    found = re.match(r"^(.+)-(\d{3,})$", asset_id)
    if found:
        counters[found.group(1)] = max(counters.get(found.group(1), 0), int(found.group(2)))
site_rack = {row[0]: (row[5], row[3]) for row in csv.reader(SNAPSHOT.open(encoding="utf-8"))
             if len(row) > 5}

blocks = [b for b in re.split(r"\n\s*\n", SOURCE.read_text(encoding="utf-8")) if b.strip()]
updates, disks, problems = [], [], []

for block in blocks:
    lines = [l.strip() for l in block.splitlines() if l.strip()]
    head = lines[0].split()
    if len(head) < 2:
        problems.append(f"khối «{lines[0]}»: thiếu mã tài sản")
        continue
    label, code = " ".join(head[:-1]), head[-1]
    if code not in known:
        problems.append(f"{code} ({label}): không có trong hệ thống")
        continue
    site, rack = site_rack.get(code, ("", ""))
    rest = "\n".join(lines[1:])

    ip = next((l for l in lines[1:] if re.fullmatch(r"\d{1,3}(\.\d{1,3}){3}", l)), "")
    cpu = next((l for l in lines[1:] if "CPU" in l or "Xeon" in l), "")
    ram = re.search(r"RAM\s+([\d.]+\s*[MGT]i?B)", rest)
    capacity = " · ".join(p for p in (cpu, f"RAM {ram.group(1)}" if ram else "") if p)
    if ip or capacity:
        updates.append({"asset_id": code, "ip_address": ip, "capacity": capacity})

    # "SSD 4×1.92 TB", "HDD 6×4.00 TB", "SSD 1x240GB"
    found = re.findall(r"(SSD|HDD|RAID)\s*(\d+)\s*[×x]\s*([\d.]+)\s*(TB|GB)", rest, re.I)
    if not found:
        problems.append(f"{code} ({label}): không đọc được ổ nào")
    for media, count, number, unit in found:
        raw = f"{number}{unit.upper()}"
        size = SIZE_ALIAS.get(raw, raw)
        key = (media.upper(), size)
        if key not in DISK_KINDS:
            problems.append(f"{code}: chưa biết đặt mã cho ổ {media.upper()} {raw}")
            continue
        prefix, disk_label = DISK_KINDS[key]
        for _ in range(int(count)):
            counters[prefix] = counters.get(prefix, 0) + 1
            disks.append({
                "asset_id": f"{prefix}-{counters[prefix]:03d}",
                "asset_name": disk_label, "asset_type": "disk", "capacity": size,
                "parent_reference": code, "datacenter": site, "current_location": site,
                "rack": rack, "usage_status": "in_use", "source_sheet": SOURCE.name,
            })
    got = [d for d in disks if d["parent_reference"] == code]
    print(f"   {code:<14}{label:<12}{ip:<14}{len(got):>3} ổ   {capacity[:46]}")

with OUTPUT.open("w", encoding="utf-8-sig", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=COLUMNS, extrasaction="ignore")
    writer.writeheader()
    for item in disks:
        writer.writerow({key: item.get(key, "") for key in COLUMNS})
import json  # noqa: E402
Path(str(OUTPUT) + ".updates.json").write_text(json.dumps(updates, ensure_ascii=False, indent=1),
                                               encoding="utf-8")
sizes = sorted({d["capacity"] for d in disks})
print(f"\n{len(blocks)} máy · bồi {len(updates)} máy · dựng {len(disks)} ổ -> {OUTPUT.name}")
print("Tổng:", " · ".join(f"{sum(1 for d in disks if d['capacity'] == s)} ổ {s}" for s in sizes))
print("vấn đề:", problems if problems else "không có")
