#!/usr/bin/env python3
"""Bundle the cleaned CSV exports into data/mgmt-device-data.js for the static UI.

The page consumes the raw CSV columns and maps them in JavaScript, so the same
mapping code serves both the bundled dataset and a file a user imports at
runtime. Re-run this after regenerating the CSV files:

    python3 scripts/build_data.py
"""
import csv
import datetime
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSET_FILE = "asset_import.csv"
HISTORY_FILE = "asset_history_import.csv"


def load(name):
    """Read a CSV into dicts, dropping empty cells to keep the bundle small."""
    with (ROOT / name).open(encoding="utf-8-sig", newline="") as handle:
        return [
            {key: value for key, value in row.items() if key and value not in (None, "")}
            for row in csv.DictReader(handle)
        ]


def count_flagged(rows):
    return sum(1 for row in rows if row.get("review_flags"))


def main():
    assets = load(ASSET_FILE)
    history = load(HISTORY_FILE)
    payload = {
        "meta": {
            "generatedAt": datetime.datetime.now().isoformat(timespec="seconds"),
            "sourceWorkbook": "BAO CAO THEO DOI SERVER (HR+SA).xlsx",
            "sourceSheet": "TỔNG HỢP",
            "assetFile": ASSET_FILE,
            "historyFile": HISTORY_FILE,
            "assetCount": len(assets),
            "eventCount": len(history),
            "assetsFlagged": count_flagged(assets),
            "eventsFlagged": count_flagged(history),
        },
        "assetRows": assets,
        "historyRows": history,
    }
    target = ROOT / "data" / "mgmt-device-data.js"
    target.parent.mkdir(exist_ok=True)
    target.write_text(
        "window.MGMT_DEVICE_DATA = "
        + json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        + ";\n",
        encoding="utf-8",
    )
    size_kb = target.stat().st_size / 1024
    print(
        f"{target.relative_to(ROOT)}: {len(assets)} assets "
        f"({payload['meta']['assetsFlagged']} flagged), "
        f"{len(history)} events ({payload['meta']['eventsFlagged']} flagged), "
        f"{size_kb:.0f} KB"
    )


if __name__ == "__main__":
    main()
