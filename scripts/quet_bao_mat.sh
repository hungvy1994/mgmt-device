#!/usr/bin/env bash
# Quét bảo mật ba tầng: mã nguồn (Bandit), phụ thuộc Python (pip-audit), ảnh container (Trivy).
#
#   ssh root@<server> 'cd /root/mgmt-device && ./scripts/quet_bao_mat.sh'
#
# NGƯỠNG — vì sao mỗi tầng một kiểu:
#   Bandit    : chặn mức HIGH. 13 cảnh báo MEDIUM B608 (ghép tên cột vào SQL) là báo nhầm —
#               tên cột đều lọc qua whitelist chữ cứng, và tests/api/chay_api.py có hẳn nhóm
#               "Chống tiêm SQL" thử tiêm thật để chứng minh, chứ không chỉ đọc code rồi tin.
#   pip-audit : chặn MỌI lỗ hổng. Phụ thuộc Python nâng version là xong, không có cớ để nợ.
#   Trivy     : chặn HIGH/CRITICAL CÓ BẢN VÁ (--ignore-unfixed). Gói hệ điều hành luôn tồn
#               một mớ CVE Debian chưa phát hành vá; bắt phải về 0 tuyệt đối thì hoặc là
#               không bao giờ xanh, hoặc phải bỏ qua bừa. Ship một CVE ĐÃ CÓ VÁ mới là lỗi
#               của mình — đó mới là thứ đáng chặn. Số chưa có vá vẫn in ra để không ai quên.
set -uo pipefail
cd "$(dirname "$0")/.."

doc_env() { sed -n "s/^$1=//p" .env 2>/dev/null | tail -1; }
ANH="$(doc_env COMPOSE_PROJECT_NAME)_api"
docker image inspect "$ANH" >/dev/null 2>&1 || ANH="mgmt-device_api"
hong=0

echo "═══ 1/3 · Bandit — mã nguồn Python ═══"
docker run --rm -v "$PWD:/ma:ro" -w /ma python:3.12-slim \
  sh -c 'pip install -q bandit >/dev/null 2>&1 && bandit -r api scripts -q -lll' || hong=1
echo "   (mức HIGH: không có thì lệnh trên không in gì)"

echo
echo "═══ 2/3 · pip-audit — phụ thuộc Python ═══"
docker run --rm -v "$PWD/api/requirements.txt:/r.txt:ro" python:3.12-slim \
  sh -c 'pip install -q pip-audit >/dev/null 2>&1 && pip-audit -r /r.txt --progress-spinner off' || hong=1

echo
echo "═══ 3/3 · Trivy — ảnh container $ANH ═══"
TAR=$(mktemp /tmp/anh-XXXX.tar)
trap 'rm -f "$TAR"' EXIT
docker save "$ANH" -o "$TAR"
docker run --rm -v "$(dirname "$TAR"):/t" -v trivy-cache:/root/.cache aquasec/trivy:latest \
  image --input "/t/$(basename "$TAR")" --severity HIGH,CRITICAL --scanners vuln \
  --ignore-unfixed --exit-code 1 --quiet || hong=1

con_lai=$(docker run --rm -v "$(dirname "$TAR"):/t" -v trivy-cache:/root/.cache aquasec/trivy:latest \
  image --input "/t/$(basename "$TAR")" --severity HIGH,CRITICAL --scanners vuln --quiet -f json 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(len(r.get("Vulnerabilities") or []) for r in d.get("Results",[])))' 2>/dev/null || echo "?")
echo "   Còn $con_lai lỗi HIGH/CRITICAL mà Debian CHƯA phát hành bản vá — không chặn được,"
echo "   theo dõi ở đây để khi có vá thì dựng lại ảnh là hết."

echo
[ "$hong" -eq 0 ] && echo "✓ Đạt: không còn lỗ hổng nào trong tầm xử lý." \
                  || echo "✗ Có lỗ hổng phải xử lý — xem phần in ở trên."
exit "$hong"
