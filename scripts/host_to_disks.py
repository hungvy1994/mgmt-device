"""host_*.csv (bản xuất hệ thống ảo hóa) -> bồi thông tin máy + dựng file nhập ổ cứng.

Sổ nguồn cho mỗi máy: IP quản trị, CPU, RAM, danh sách ổ, số license. Máy đã có sẵn trong
hệ thống nên chỉ BỒI THÊM chứ không tạo lại; ổ cứng thì dựng mới thành linh kiện gắn vào máy.

    host_to_disks.py <host.csv> <file nhập> <map.json> [<mã tài sản đang có.csv>]

`map.json` do scripts/build_host_map.py dựng: IP -> {asset_id, site, rack}. Không gõ tay
bảng IP vào script — mỗi bản xuất là một tủ khác, gõ tay là lúc gán nhầm ổ sang máy khác.

Ổ phân biệt theo PHƯƠNG TIỆN (SSD / HDD / RAID) chứ không chỉ dung lượng — xem DISK_KINDS.

Số thứ tự ổ chạy TIẾP theo kho ổ đang có (đọc từ file mã tài sản hiện tại), không đánh lại
từ 001: mã ổ không mang thông tin vị trí nên ổ rút ra cắm sang máy khác vẫn giữ nguyên mã.
"""
import csv
import json
import re
import sys
from pathlib import Path

# (phương tiện, dung lượng) -> (tiền tố mã, tên hiển thị).
# PHẢI phân biệt phương tiện: HDD là đĩa quay, SSD là bộ nhớ, RAID là volume logic do card
# dựng chứ không phải một ổ vật lý. Gọi chung là "ssd" thì mã ghi sai bản chất thiết bị.
# Nhãn giữ nguyên chữ đã dùng cho ổ cùng tiền tố đang có trong database, đừng đổi tùy hứng.
DISK_KINDS = {
    ("SSD", "240.06GB"): ("ssd-240", "Ổ cứng SSD 240GB"),
    ("SSD", "480.10GB"): ("ssd-480", "Ổ cứng SSD 480GB"),
    ("SSD", "960.20GB"): ("ssd-960", "Ổ cứng SSD 960GB"),
    ("SSD", "1.9TB"):    ("ssd-2tb", "Ổ cứng SSD 1.9TB"),
    ("SSD", "2TB"):      ("ssd-2tb", "Ổ cứng SSD 2TB"),
    ("SSD", "7.7TB"):    ("ssd-8tb", "Ổ cứng SSD 7.7TB"),
    ("HDD", "4.0TB"):    ("hdd-4tb", "Ổ cứng HDD 4TB"),
    # Volume RAID: tiền tố riêng để không lẫn vào số đếm ổ vật lý. Dung lượng giữ nguyên
    # chữ của bản xuất (239.00 / 239.51) vì đây là dung lượng volume, không phải cỡ ổ.
    ("RAID", "239.00GB"): ("raid-240", "Volume RAID 239.00GB"),
    ("RAID", "239.51GB"): ("raid-240", "Volume RAID 239.51GB"),
    ("RAID", "479.00GB"): ("raid-480", "Volume RAID 479.00GB"),
    ("RAID", "999.00GB"): ("raid-960", "Volume RAID 999.00GB"),
}
# Serial "để trống từ nhà máy": cùng một chuỗi trên nhiều máy thì không phải serial thật.
# Ghi vào là ghi dữ liệu sai — để trống và báo ra, đúng quy tắc "hiện chỗ thiếu, không đoán".
PLACEHOLDER_SERIALS = {"0123456789", "123456789", "0000000000", "1234567890",
                       "to be filled by o.e.m."}
# Bản xuất khai là HDD nhưng thực chất là thẻ khởi động của máy (microSD / USB DOM), không
# phải ổ dữ liệu. Bỏ qua CÓ CHỦ Ý — script vẫn liệt kê ra chứ không im lặng nuốt mất.
IGNORED_DISKS = {("HDD", "8.05GB"): "thẻ khởi động (microSD / USB DOM), không phải ổ dữ liệu"}

COLUMNS = [
    "asset_id", "code_pending", "asset_name", "asset_type", "asset_category", "ip_address",
    "ip_or_type_raw", "cluster", "in_store", "datacenter", "current_location", "rack",
    "rack_unit", "parent_reference", "capacity", "replacement_target", "usage_status",
    "usage_status_label", "usage_start_date", "handover_date", "handover_status",
    "purchase_invoice", "purchase_price_vnd", "supplier_code", "supplier_name",
    "warranty_months", "warranty_end_date", "serial", "description", "source_sheet",
    "source_row", "review_flags",
]


def parse_specs(text: str) -> dict:
    """'CPU: 2*Intel... (48 Cores)\\n Memory: 256.0GB\\n Disk: SSD(14*7.7TB)+SSD(2*240.06GB)'"""
    out = {"cpu": "", "memory": "", "disks": []}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("CPU:"):
            out["cpu"] = line[4:].strip()
        elif line.startswith("Memory:"):
            out["memory"] = line[7:].strip()
        elif line.startswith("Disk:"):
            # SSD(2*240.06GB)+HDD(4*4.0TB) -> [('SSD', 2, '240.06GB'), ('HDD', 4, '4.0TB')]
            for media, count, size in re.findall(r"(\w+)\((\d+)\*([^)]+)\)", line):
                out["disks"].append((media.strip().upper(), int(count), size.strip()))
    return out


def main() -> None:
    SOURCE = Path(sys.argv[1])
    OUTPUT = Path(sys.argv[2])
    HOSTS = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
    EXISTING = Path(sys.argv[4]) if len(sys.argv) > 4 else None

    # Đánh số tiếp từ mã ổ lớn nhất đang có, không đè lên ổ cũ.
    counters = {prefix: 0 for prefix, _ in DISK_KINDS.values()}
    if EXISTING and EXISTING.exists():
        for row in csv.reader(EXISTING.open(encoding="utf-8")):
            found = re.match(r"^(.+)-(\d{3,})$", (row[0] if row else "").strip())
            if found and found.group(1) in counters:
                counters[found.group(1)] = max(counters[found.group(1)], int(found.group(2)))
        print("số thứ tự ổ chạy tiếp từ:",
              ", ".join(f"{p}-{n:03d}" for p, n in sorted(counters.items()) if n) or "(kho ổ đang rỗng)")

    rows = list(csv.DictReader(SOURCE.open(encoding="utf-8-sig")))
    updates, disks, problems, no_serial, ignored = [], [], [], [], []

    for index, row in enumerate(rows, start=2):
        ip = row["Management interface IP"].strip()
        host = HOSTS.get(ip)
        if not host:
            problems.append(f"dòng {index}: IP {ip} không khớp máy nào đã có")
            continue
        spec = parse_specs(row["Specifications"])
        serial = row["Server License"].strip()
        if serial.lower() in PLACEHOLDER_SERIALS:
            no_serial.append(f"{host['asset_id']} ({ip}) ghi «{serial}»")
            serial = ""
        updates.append({
            "asset_id": host["asset_id"],
            "ip_address": ip,
            # CPU + RAM là cấu hình máy -> đúng chỗ của cột "Dung lượng / cấu hình"
            "capacity": " · ".join(part for part in (spec["cpu"], f"RAM {spec['memory']}" if spec["memory"] else "") if part),
            "serial": serial,
        })
        if not spec["disks"]:
            problems.append(f"dòng {index}: {host['asset_id']} không đọc được ổ nào")
        for media, count, size in spec["disks"]:
            if (media, size) in IGNORED_DISKS:
                ignored.append(f"{host['asset_id']}: {count} × {media} {size}"
                               f" — {IGNORED_DISKS[(media, size)]}")
                continue
            if (media, size) not in DISK_KINDS:
                problems.append(f"dòng {index}: chưa biết đặt mã cho ổ {media} {size}")
                continue
            prefix, label = DISK_KINDS[(media, size)]
            for _ in range(count):
                counters[prefix] += 1
                disks.append({
                    "asset_id": f"{prefix}-{counters[prefix]:03d}",
                    "asset_name": label,
                    "asset_type": "disk",
                    "capacity": size,
                    "parent_reference": host["asset_id"],   # ổ là linh kiện lắp trong máy
                    "datacenter": host["site"],
                    "current_location": host["site"],
                    "rack": host["rack"],        # cùng chỗ với máy chứa; ổ không chiếm ô U nào
                    "usage_status": "in_use",
                    "source_sheet": SOURCE.name,
                    "source_row": index,
                })

    with OUTPUT.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, extrasaction="ignore")
        writer.writeheader()
        for item in disks:
            writer.writerow({key: item.get(key, "") for key in COLUMNS})
    Path(str(OUTPUT) + ".updates.json").write_text(json.dumps(updates, ensure_ascii=False, indent=1), encoding="utf-8")

    print(f"\nĐọc {len(rows)} máy · bồi thông tin {len(updates)} máy · dựng {len(disks)} ổ -> {OUTPUT.name}")
    print("\nỔ theo từng máy:")
    sizes = sorted({d["capacity"] for d in disks}, key=lambda s: -len(s))
    for item in updates:
        mine = [d for d in disks if d["parent_reference"] == item["asset_id"]]
        parts = []
        for size in sizes:
            same = [d for d in mine if d["capacity"] == size]
            if same:
                parts.append(f"{len(same)} × {size} ({same[0]['asset_id']}…{same[-1]['asset_id']})")
        print(f"   {item['asset_id']:<14}{item['ip_address']:<16}" + "  +  ".join(parts))
    print("\nTổng:", " · ".join(f"{sum(1 for d in disks if d['capacity'] == s)} ổ {s}" for s in sizes))
    if no_serial:
        print(f"\nserial để trống ({len(no_serial)} máy — sổ ghi số mẫu, không phải serial thật):")
        for line in no_serial:
            print("   ", line)
    if ignored:
        print(f"\nbỏ qua có chủ ý ({len(ignored)}):")
        for line in ignored:
            print("   ", line)
    print("\nvấn đề:", problems if problems else "không có")


if __name__ == "__main__":
    main()
