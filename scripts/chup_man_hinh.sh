#!/usr/bin/env bash
# Chụp màn hình giao diện để kiểm bằng MẮT những thứ test chức năng không thấy:
# nút sát nhau, chữ tràn ô, hàng nút nhảy dòng, chữ bị cắt mất dấu ba chấm.
#
#   ./scripts/chup_man_hinh.sh [thư mục ra] [bề rộng]
#   ./scripts/chup_man_hinh.sh /tmp/anh 1280
#
# Không cần đăng nhập và không đụng server: dựng một bản sao index.html có gắn sẵn
# fetch giả, lấy dữ liệu từ tests/fixture-30.json.
set -euo pipefail
cd "$(dirname "$0")/.."

RA="${1:-/tmp/anh-mgmt-device}"
RONG="${2:-1280}"
mkdir -p "$RA"

BIN=$(find "$HOME/.cache/ms-playwright" -type f -name 'chrome-headless-shell' 2>/dev/null | head -1)
[ -n "$BIN" ] || { echo "Không tìm thấy chrome-headless-shell trong ~/.cache/ms-playwright."; exit 1; }
[ -f tests/fixture-30.json ] || { echo "Thiếu tests/fixture-30.json."; exit 1; }

python3 - "$RA" <<'PY'
import json, sys
from pathlib import Path
ra = Path(sys.argv[1])
data = Path("tests/fixture-30.json").read_text()
gia = """  <script>
  (function () {
    const DATA = %s;
    window.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
    const j = x => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(x) });
    window.fetch = u => {
      const url = String(u);
      if (url === 'api/me') return j({ username: 'demo', role: 'admin', fullName: 'Xem thử' });
      if (url === 'api/data') return j(DATA);
      if (url === 'api/imports') return j({ imports: [] });
      if (url === 'api/users') return j({ users: [], roles: [] });
      if (url === 'api/export-templates') return j({ templates: [], fields: [] });
      if (url === 'api/backup') return j({ config: {}, files: [], totalBytes: 0, dir: '/backups' });
      if (url.startsWith('api/audit')) return j({ entries: [] });
      return j({ ok: true });
    };
    const v = new URLSearchParams(location.search).get('v');
    window.addEventListener('load', () => setTimeout(() => {
      const b = v && document.querySelector(`[data-view="${v}"]`); if (b) b.click();
    }, 400));
  })();
  </script>
""" % data
(ra / "app.html").write_text(Path("index.html").read_text().replace("  <script>", gia + "  <script>", 1))
PY

for v in overview assets locations diagram store types statuses data exports admin; do
  "$BIN" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --virtual-time-budget=6000 --window-size="$RONG,900" \
    --screenshot="$RA/$v.png" "file://$RA/app.html?v=$v" >/dev/null 2>&1
  printf '  %-12s %s\n' "$v" "$RA/$v.png"
done
echo "Xong — mở thư mục $RA để xem."
