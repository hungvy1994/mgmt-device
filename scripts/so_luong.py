"""So sánh SỐ LƯỢNG giữa sổ Excel và ứng dụng.

Hai sổ sách phục vụ hai việc khác nhau: file Excel giám sát SỐ LƯỢNG (mua sắm), ứng dụng
quản lý VIỆC SỬ DỤNG (lắp ở đâu). Nên không khớp danh tính từng món — chỉ quy hai bên về
cùng một cách gọi "loại + dung lượng" rồi đếm.
"""
import csv
import re
from collections import Counter
from pathlib import Path

BOOK = Path("/home/coder/vydh/mgmt-device/asset_import.csv")
APP = Path("db_full.csv")

# --- quy hai bên về cùng một nhãn -------------------------------------------
def nhan_so(row: dict) -> str:
    code = (row["asset_id"] or "").upper()
    name = (row["asset_name"] or "")
    kind = (row["asset_type"] or "").strip()
    text = f"{code} {name}"
    if kind == "disk":
        for pat, label in ((r"7\.68\s*TB", "Ổ SSD 7.68TB"), (r"1\.92\s*TB|SSD-2TB", "Ổ SSD 1.92TB"),
                           (r"960\s*G|SSD-SS", "Ổ SSD 960GB"), (r"480", "Ổ SSD 480GB"),
                           (r"240\s*G|SSD-240", "Ổ SSD 240GB"), (r"4\s*TB", "Ổ HDD 4TB")):
            if re.search(pat, text, re.I):
                return label
        return "Ổ cứng khác"
    if kind in ("cable", "raid_cable"):
        for pat, label in ((r"CAP-RAID|SAS", "Cáp RAID/SAS"), (r"CAP-DAS", "Cáp DAS"),
                           (r"STACK", "Cáp stack"), (r"40\s*G", "Cáp 40G"),
                           (r"20\s*G", "Cáp 20G"), (r"10\s*G", "Cáp 10G")):
            if re.search(pat, text, re.I):
                return label
        return "Cáp khác"
    return {"server": "Máy chủ", "network_or_host": "Máy chủ", "switch": "Switch",
            "firewall": "Firewall", "hsm": "HSM", "storage": "Thiết bị lưu trữ",
            "ram": "RAM", "cpu": "CPU", "nic": "Card mạng", "raid_card": "Card RAID",
            "optical_module": "Module quang", "power_supply": "Bộ nguồn",
            "adapter": "Adapter"}.get(kind, f"Khác ({kind or 'trống'})")


def nhan_app(row: dict) -> str:
    code = row["asset_id"].lower()
    if row["asset_type"] == "disk":
        for pre, label in (("ssd-8tb", "Ổ SSD 7.68TB"), ("ssd-2tb", "Ổ SSD 1.92TB"),
                           ("ssd-960", "Ổ SSD 960GB"), ("ssd-480", "Ổ SSD 480GB"),
                           ("ssd-240", "Ổ SSD 240GB"), ("hdd-4tb", "Ổ HDD 4TB"),
                           ("raid-", "Volume RAID (không phải ổ vật lý)")):
            if code.startswith(pre):
                return label
        return "Ổ cứng khác"
    if row["asset_type"] == "cable":
        return "Cáp 20G" if code.startswith("cab-20g") else "Cáp 10G"
    return {"server": "Máy chủ", "network_or_host": "Máy chủ", "switch": "Switch",
            "firewall": "Firewall", "hsm": "HSM", "storage": "Thiết bị lưu trữ"}.get(
        row["asset_type"], f"Khác ({row['asset_type']})")


rows_book = list(csv.DictReader(BOOK.open(encoding="utf-8-sig")))
book = Counter(nhan_so(r) for r in rows_book)
# Ứng dụng chỉ ghi thứ ĐANG LẮP (mục Kho đang rỗng) -> tách riêng phần sổ ghi đang trong Kho
trong_kho = Counter(nhan_so(r) for r in rows_book
                    if (r["datacenter"] or "").strip().lower() == "kho"
                    or (r["asset_id"] or "").upper().startswith("SVR-KHO"))
app = Counter(nhan_app(dict(zip(("asset_id", "asset_name", "asset_type", "rack", "rack_unit", "site"), r[:6])))
              for r in csv.reader(APP.open(encoding="utf-8")) if r and r[0] != "asset_id")

NHOM = [("Ổ cứng", [k for k in set(book) | set(app) if k.startswith("Ổ ") or "RAID (" in k]),
        ("Cáp", [k for k in set(book) | set(app) if k.startswith("Cáp")]),
        ("Thiết bị", ["Máy chủ", "Switch", "Firewall", "HSM", "Thiết bị lưu trữ"]),
        ("Linh kiện khác", ["RAM", "CPU", "Card mạng", "Card RAID", "Module quang",
                            "Bộ nguồn", "Adapter"])]
done = set()
print(f"{'':<34}{'SỔ':>6}{'(ở Kho)':>9}{'ỨNG DỤNG':>10}{'CHÊNH':>8}")
for ten_nhom, keys in NHOM:
    print(f"\n── {ten_nhom}")
    for key in sorted(keys, key=lambda k: -(book.get(k, 0) + app.get(k, 0))):
        b, a = book.get(key, 0), app.get(key, 0)
        if not (b or a):
            continue
        done.add(key)
        d = a - b
        print(f"   {key:<31}{b:>6}{trong_kho.get(key, 0):>9}{a:>10}{d:>+8}")
con_lai = sorted(set(book) | set(app), key=lambda k: -(book.get(k, 0) + app.get(k, 0)))
con_lai = [k for k in con_lai if k not in done]
if con_lai:
    print("\n── Chưa xếp nhóm")
    for key in con_lai:
        print(f"   {key:<31}{book.get(key, 0):>6}{trong_kho.get(key, 0):>9}{app.get(key, 0):>10}{app.get(key, 0) - book.get(key, 0):>+8}")
out = [("nhom", "loai", "so_trong_so", "trong_do_o_kho", "so_tren_ung_dung", "chenh_lech")]
for ten_nhom, keys in NHOM:
    for key in sorted(keys, key=lambda k: -(book.get(k, 0) + app.get(k, 0))):
        if book.get(key, 0) or app.get(key, 0):
            out.append((ten_nhom, key, book.get(key, 0), trong_kho.get(key, 0),
                        app.get(key, 0), app.get(key, 0) - book.get(key, 0)))
import csv as _csv
with open("so_sanh_so_luong.csv", "w", encoding="utf-8-sig", newline="") as fh:
    _csv.writer(fh).writerows(out)

lap_so = sum(book.values()) - sum(trong_kho.values())
print(f"\n   {'— chỉ tính thứ ĐANG LẮP —':<31}{lap_so:>6}{'':>9}{sum(app.values()):>10}"
      f"{sum(app.values()) - lap_so:>+8}")
print(f"\n   {'TỔNG':<31}{sum(book.values()):>6}{sum(trong_kho.values()):>9}{sum(app.values()):>10}"
      f"{sum(app.values()) - sum(book.values()):>+8}")
