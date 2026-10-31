#!/usr/bin/env python3
"""Convert the current asset workbook into importable asset and history CSVs."""

from __future__ import annotations

import csv
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

from openpyxl import load_workbook


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "BAO CAO THEO DOI SERVER (HR+SA).xlsx"
ASSET_OUTPUT = ROOT / "asset_import.csv"
HISTORY_OUTPUT = ROOT / "asset_history_import.csv"


def clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "").replace("\u00a0", " ")).strip()


# Tên site chuẩn — lấy từ chính cột Datacenter của sổ (xem build_site_names).
SITE_NAMES: set[str] = set()


def split_lines(value: object) -> list[str]:
    return [clean_text(item) for item in re.split(r"\r?\n", str(value or "")) if clean_text(item)]


def parse_date(value: object) -> str:
    if value is None or value == "":
        return ""
    if isinstance(value, (datetime, date)):
        return value.strftime("%Y-%m-%d")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        # Excel serial date (epoch 1899-12-30); giới hạn 1954-2064 để không nuốt số thường
        if 20000 < float(value) < 60000:
            return (datetime(1899, 12, 30) + timedelta(days=int(value))).strftime("%Y-%m-%d")
        return ""
    text = clean_text(value)
    for fmt in ("%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%Y/%m/%d", "%d/%m/%Y", "%m/%d/%Y"):
        try:
            return datetime.strptime(text, fmt).strftime("%Y-%m-%d")
        except ValueError:
            pass
    match = re.fullmatch(r"(\d{1,2})/(\d{1,2})/(\d{4})", text)
    if match:
        first, second, year = map(int, match.groups())
        if first > 12:
            return f"{year:04d}-{second:02d}-{first:02d}"
        if second > 12:
            return f"{year:04d}-{first:02d}-{second:02d}"
        return f"{year:04d}-{second:02d}-{first:02d}"
    return ""


def canonical_status(value: object) -> tuple[str, str]:
    label = clean_text(value)
    key = label.casefold()
    if key in {"đang sử dụng", "đang sử dụng cần được thay thế"}:
        return ("in_use_needs_replacement" if "thay thế" in key else "in_use", label)
    if key in {"cũ , chưa sử dụng", "mới, chưa sử dụng", "chưa sử dụng"}:
        return "in_stock", label
    if key in {"đã hanh lý", "đã thanh lý"}:
        return "retired", label
    if key == "cần thanh lý":
        return "pending_disposal", label
    if key in {"hỏng", "hư, chỉ làm lab", "hư"}:
        return "broken", label
    if key == "không đảm bảo hiệu năng":
        return "degraded", label
    if key == "không sử dụng":
        return "not_in_use", label
    return "unknown", label


TYPE_MAP = {
    "disk": "disk",
    "hdd": "disk",
    "server": "server",
    "switch": "switch",
    "ram": "ram",
    "card mạng": "nic",
    "module": "optical_module",
    "fỉewall": "firewall",
    "firewall": "firewall",
    "hsm": "hsm",
    "cáp": "cable",
    "cáp raid": "raid_cable",
    "card raid": "raid_card",
    "cpu": "cpu",
    "đầu chuyển das": "adapter",
    "nguồn": "power_supply",
}


def infer_type(raw_type: object, category: object, name: object, asset_id: object) -> str:
    raw = clean_text(raw_type).casefold()
    if raw in TYPE_MAP:
        return TYPE_MAP[raw]
    if re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){3}", raw):
        category_text = clean_text(category).casefold()
        if category_text == "server":
            return "server"
        name_text = clean_text(name).casefold()
        for token, kind in (("switch", "switch"), ("nexus", "switch"), ("server", "server"), ("fortigate", "firewall")):
            if token in name_text:
                return kind
        return "network_or_host"
    text = f"{clean_text(name)} {clean_text(asset_id)}".casefold()
    for token, kind in (("ssd", "disk"), ("hdd", "disk"), ("server", "server"), ("nexus", "switch"), ("cáp", "cable")):
        if token in text:
            return kind
    return "unknown"


RACK_CODE = re.compile(r"^[A-Z]+-(?P<rack>(?=[A-Z0-9]*[A-Z])[A-Z0-9]+)-(?P<tail>\d+)$")
MAX_RACK_U = 48


def simplify(value: str) -> str:
    """Bỏ dấu và khoảng trắng để so 'Kho' với token 'KHO' trong mã tài sản."""
    stripped = unicodedata.normalize("NFD", value)
    return "".join(ch for ch in stripped if unicodedata.category(ch) != "Mn").replace(" ", "").upper()


def split_rack_code(asset_id: str) -> tuple[str, int] | None:
    """MÃ dạng LOẠI-RACK-U: 'SW-AQ53-32' -> rack AQ53 U32; 'SVR-J3-4344' -> rack J3, bắt đầu U43.

    Đuôi 4 số là thiết bị chiếm 2U (43-44), lấy U nhỏ hơn làm vị trí bắt đầu vì U1 ở đáy rack.
    Token giữa bắt buộc có chữ cái để '2TB', '240', '10' không bị nhận nhầm là mã rack.
    """
    match = RACK_CODE.match(asset_id.strip().upper())
    if not match:
        return None
    tail = match.group("tail")
    if len(tail) == 2 and 1 <= int(tail) <= MAX_RACK_U:
        return match.group("rack"), int(tail)
    if len(tail) == 4:
        first, second = int(tail[:2]), int(tail[2:])
        if 1 <= first <= MAX_RACK_U and 1 <= second <= MAX_RACK_U and abs(second - first) <= 3:
            return match.group("rack"), min(first, second)
    return None


def rack_positions(rows: list[tuple[object, ...]], columns: dict[str, int]) -> dict[str, tuple[str, int]]:
    """Chỉ nhận token là mã rack khi MỌI thiết bị mang token đó cùng một datacenter.

    Token xuất hiện ở hai site khác nhau thì đó là chữ viết tắt gì đó chứ không phải rack —
    bỏ qua, không đoán. Hai thiết bị rơi vào cùng một U thì cũng bỏ cả hai và đánh cờ.
    """
    candidates: dict[str, list[tuple[str, int, str]]] = defaultdict(list)
    for row in rows:
        asset_id = clean_text(value(row, columns, "MÃ TÀI SẢN"))
        parsed = split_rack_code(asset_id) if asset_id else None
        if parsed:
            candidates[parsed[0]].append((asset_id, parsed[1], clean_text(value(row, columns, "Datacenter"))))
    site_tokens = {simplify(clean_text(value(row, columns, "Datacenter"))) for row in rows}
    placements: dict[str, tuple[str, int]] = {}
    for rack, items in candidates.items():
        if len({site for _, _, site in items if site}) > 1:
            continue
        if simplify(rack) in site_tokens:
            continue      # 'SVR-KHO-30' là thiết bị ở Kho, 'KHO' không phải mã rack
        used = Counter(unit for _, unit, _ in items)
        for asset_id, unit, _ in items:
            if used[unit] == 1:
                placements[asset_id] = (rack, unit)
    return placements


def value(row: tuple[object, ...], columns: dict[str, int], name: str) -> object:
    index = columns.get(name)
    return row[index] if index is not None and index < len(row) else None


def by_letter(row: tuple[object, ...], letter: str) -> object:
    index = ord(letter) - ord("A")
    return row[index] if index < len(row) else None


def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    workbook = load_workbook(SOURCE, read_only=True, data_only=True)
    sheet = workbook["TỔNG HỢP "]
    header_values = next(sheet.iter_rows(min_row=2, max_row=2, values_only=True))
    headers = [clean_text(str(item).replace("\n", " ")) if item is not None else "" for item in header_values]
    # T và X trùng header "Đối tượng sử dụng": giữ lần xuất hiện ĐẦU (T),
    # các cột giai đoạn chuyển đổi truy cập bằng chữ cái cột.
    columns: dict[str, int] = {}
    for index, header in enumerate(headers):
        if header and header not in columns:
            columns[header] = index
    rows = list(sheet.iter_rows(min_row=3, values_only=True))
    # Bộ tên site chuẩn = đúng những giá trị cột Datacenter đang dùng. Không gõ tay danh sách:
    # sổ thêm site mới thì bộ này tự lớn theo.
    SITE_NAMES.update(clean_text(value(r, columns, "Datacenter")) for r in rows
                      if clean_text(value(r, columns, "Datacenter")))
    id_counts = Counter(clean_text(value(row, columns, "MÃ TÀI SẢN")) for row in rows)
    duplicate_rows: defaultdict[str, list[int]] = defaultdict(list)
    for row_number, row in enumerate(rows, 3):
        asset_id = clean_text(value(row, columns, "MÃ TÀI SẢN"))
        if asset_id:
            duplicate_rows[asset_id].append(row_number)

    asset_fields = [
        "asset_id", "asset_name", "asset_type", "asset_category", "ip_address",
        "ip_or_type_raw", "cluster", "datacenter", "current_location", "rack", "rack_unit",
        "parent_reference",
        "capacity", "replacement_target", "usage_status", "usage_status_label",
        "usage_start_date", "handover_date", "handover_status", "purchase_invoice", "purchase_price_vnd",
        "supplier_code", "supplier_name", "warranty_months", "warranty_end_date",
        "description", "source_sheet", "source_row", "review_flags",
    ]
    history_fields = [
        "asset_id", "event_sequence", "event_type", "event_date", "location",
        "usage_object", "notes", "declared_transition_count", "source_column", "source_row",
        "review_flags",
    ]
    placements = rack_positions(rows, columns)
    print(f"Suy được vị trí rack cho {len(placements)} tài sản từ mã tài sản")
    assets: list[dict[str, object]] = []
    histories: list[dict[str, object]] = []
    seen_ids: set[str] = set()
    known_ids = {clean_text(value(row, columns, "MÃ TÀI SẢN")) for row in rows if clean_text(value(row, columns, "MÃ TÀI SẢN"))}

    for row_number, row in enumerate(rows, 3):
        asset_id = clean_text(value(row, columns, "MÃ TÀI SẢN"))
        if not asset_id or asset_id in seen_ids:
            continue
        seen_ids.add(asset_id)

        name = clean_text(value(row, columns, "Tên Server/ Tên linh kiện"))
        product_name = clean_text(value(row, columns, "Tên hàng hóa mua"))
        category = clean_text(value(row, columns, "Loại hàng hóa")).casefold()
        raw_ip = clean_text(value(row, columns, "IP"))
        datacenter = clean_text(value(row, columns, "Datacenter"))
        parent_reference = clean_text(value(row, columns, "Nơi gắn linh kiện"))
        usage_status, usage_status_label = canonical_status(value(row, columns, "Tình trạng sử dụng"))
        handover_status = clean_text(value(row, columns, "Tình trạng bàn giao"))
        handover_date_text = parse_date(value(row, columns, "Thời gian bàn giao (mm/dd/yyyy)"))
        flags: list[str] = []
        if id_counts[asset_id] > 1:
            flags.append(f"duplicate_source_rows:{','.join(map(str, duplicate_rows[asset_id]))}")
        if raw_ip and raw_ip not in TYPE_MAP and not re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){3}", raw_ip):
            flags.append("unmapped_ip_or_type")
        if parent_reference and parent_reference not in known_ids:
            flags.append("parent_reference_unresolved")
        if usage_status == "unknown":
            flags.append("status_needs_review")
        if handover_status and not handover_date_text:
            flags.append("handover_date_missing")

        ip_address = raw_ip if re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){3}", raw_ip) else ""
        cluster = clean_text(value(row, columns, "Cụm"))
        rack_code, rack_unit = placements.get(asset_id, ("", ""))
        if rack_code:
            # Vị trí này SUY từ mã tài sản chứ sổ không ghi — phải thấy được, không lặng lẽ khẳng định.
            flags.append("rack_from_asset_code")
        # HIỆN TRẠNG NẰM Ở DÒNG CUỐI, KHÔNG PHẢI CỘT DATACENTER.
        # Sổ nhét cả lịch sử luân chuyển vào một ô, mỗi lần một dòng (cột V ngày, W nơi đặt,
        # X đối tượng sử dụng). Cột Datacenter thường đứng yên từ lần ghi đầu nên đã cũ.
        date_lines = split_lines(value(row, columns, "Ngày chuyển đổi"))
        location_lines = split_lines(value(row, columns, "Nơi đặt Server"))
        object_lines = split_lines(by_letter(row, "X"))
        chot_dt = object_lines[-1] if object_lines else ""      # đối tượng sử dụng, dòng cuối
        chot_noi = location_lines[-1] if location_lines else ""  # nơi đặt, dòng cuối
        if chot_dt or chot_noi:
            if "kho" in (chot_dt.casefold(), chot_noi.casefold()):
                if datacenter != "Kho":
                    flags.append("location_from_last_transfer")
                datacenter = "Kho"
                # Hỏng/thanh lý vẫn nằm được trong kho — chỉ sửa khi sổ đang ghi là đang dùng.
                if usage_status == "in_use":
                    usage_status = "in_stock"
                    flags.append("status_from_last_transfer")
            else:
                if usage_status == "in_stock":
                    usage_status = "in_use"
                    flags.append("status_from_last_transfer")
                # Cột W ghi tên tắt ("CMC" không rõ Tân Thuận hay Quận 9, "VNPT") — CHỈ nhận
                # khi trùng đúng một tên site chuẩn, không thì thà để trống còn hơn ghi sai.
                if chot_noi in SITE_NAMES:
                    if chot_noi != datacenter:
                        flags.append("location_from_last_transfer")
                    datacenter = chot_noi
                elif datacenter.casefold() == "kho":
                    datacenter = ""            # đã rời kho nhưng không biết đi đâu
                    flags.append("location_from_last_transfer")
                    flags.append("current_location_unknown")
        asset_type = infer_type(raw_ip, category, name, asset_id)
        # description chỉ giữ phần CHƯA có cột riêng: tên thứ hai nếu khác tên tài sản.
        # Nhồi lại asset_name và cụm vào đây là nhân bản dữ liệu, không phải mô tả.
        asset_name = product_name or name or asset_id
        extra = name if name and name != asset_name else ""
        description_parts = [part for part in (extra,) if part]
        assets.append({
            "asset_id": asset_id,
            "asset_name": asset_name,
            "asset_type": asset_type,
            "asset_category": "server" if asset_type == "server" else "component",
            "ip_address": ip_address,
            "ip_or_type_raw": raw_ip,
            "cluster": cluster,
            "datacenter": datacenter,
            "current_location": datacenter,
            "rack": rack_code,
            "rack_unit": rack_unit,
            "parent_reference": parent_reference,
            "capacity": clean_text(value(row, columns, "Dung lượng linh kiện")),
            "replacement_target": clean_text(value(row, columns, "Nơi thay thế")),
            "usage_status": usage_status,
            "usage_status_label": usage_status_label,
            "usage_start_date": parse_date(value(row, columns, "Ngày bắt đầu sử dụng")),
            "handover_date": handover_date_text,
            "handover_status": handover_status,
            "purchase_invoice": clean_text(value(row, columns, "Số hóa đơn")),
            "purchase_price_vnd": value(row, columns, "Giá mua") or "",
            "supplier_code": clean_text(value(row, columns, "Mã NCC")),
            "supplier_name": clean_text(value(row, columns, "Tên NCC")),
            "warranty_months": value(row, columns, "Thời gian bảo hành (tháng)") or "",
            "warranty_end_date": parse_date(value(row, columns, "Ngày hết bảo hành")),
            "description": " | ".join(description_parts),
            "source_sheet": "TỔNG HỢP",
            "source_row": row_number,
            "review_flags": ";".join(flags),
        })

        declared = clean_text(value(row, columns, "Số lần chuyển đổi"))
        declared_count = int(declared) if declared.isdigit() else ""
        if declared and not declared.isdigit():
            declared_flag = "invalid_transition_count"
        else:
            declared_flag = ""
        if len(date_lines) != len(location_lines) or len(date_lines) != len(object_lines):
            tuple_flag = "history_tuple_incomplete"
        else:
            tuple_flag = ""

        sequence = 0
        handover_date = parse_date(value(row, columns, "Thời gian bàn giao (mm/dd/yyyy)"))
        if handover_date:
            histories.append({
                "asset_id": asset_id, "event_sequence": sequence, "event_type": "handover_received",
                "event_date": handover_date, "location": "Kho" if datacenter == "Kho" else "",
                "usage_object": "", "notes": "", "declared_transition_count": declared_count,
                "source_column": "K", "source_row": row_number,
                "review_flags": "handover_location_unknown" if datacenter != "Kho" else "",
            })
            sequence += 1
        usage_date = parse_date(value(row, columns, "Ngày bắt đầu sử dụng"))
        if usage_date:
            histories.append({
                "asset_id": asset_id, "event_sequence": sequence, "event_type": "usage_stage_1",
                "event_date": usage_date, "location": datacenter,
                "usage_object": clean_text(by_letter(row, "T")), "notes": "",
                "declared_transition_count": declared_count, "source_column": "S/T/U",
                "source_row": row_number, "review_flags": "",
            })
            sequence += 1
        for offset, date_text in enumerate(date_lines):
            location = location_lines[offset] if offset < len(location_lines) else ""
            usage_object = object_lines[offset] if offset < len(object_lines) else ""
            event_flags = [flag for flag in (declared_flag, tuple_flag) if flag]
            event_date = parse_date(date_text)
            if not event_date:
                event_flags.append("unparsed_event_date")
            if not location:
                event_flags.append("missing_event_location")
            if not usage_object:
                event_flags.append("missing_usage_object")
            histories.append({
                "asset_id": asset_id, "event_sequence": sequence, "event_type": f"usage_stage_{offset + 2}",
                "event_date": event_date, "location": location, "usage_object": usage_object,
                "notes": "", "declared_transition_count": declared_count, "source_column": "V/W/X/Y",
                "source_row": row_number, "review_flags": ";".join(event_flags),
            })
            sequence += 1

    write_csv(ASSET_OUTPUT, asset_fields, assets)
    write_csv(HISTORY_OUTPUT, history_fields, histories)
    print(f"Wrote {len(assets)} assets to {ASSET_OUTPUT.name}")
    print(f"Wrote {len(histories)} history events to {HISTORY_OUTPUT.name}")


if __name__ == "__main__":
    main()