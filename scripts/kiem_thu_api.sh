#!/usr/bin/env bash
# Chạy bộ kiểm tầng API trong CHÍNH ảnh production, trên một database dựng riêng rồi xoá.
#
#   ssh root@<server> 'cd /root/mgmt-device && ./scripts/kiem_thu_api.sh'
#
# KHÔNG đụng database thật: bộ kiểm tự tạo database `thu_api`, nạp db/schema.sql, chạy xong
# thì xoá. Không đụng container đang chạy: mỗi lần là một container dùng-một-lần.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "Thiếu .env"; exit 1; }

# ĐỪNG `source .env`: giá trị có dấu cách không đặt trong nháy (ADMIN_NAME=Đặng Hùng Vỹ)
# làm bash hiểu thành lệnh. Chỉ bóc đúng những khoá cần.
doc_env() { sed -n "s/^$1=//p" .env | tail -1; }
POSTGRES_USER=$(doc_env POSTGRES_USER)
POSTGRES_PASSWORD=$(doc_env POSTGRES_PASSWORD)
POSTGRES_DB=$(doc_env POSTGRES_DB)
COMPOSE_PROJECT_NAME=$(doc_env COMPOSE_PROJECT_NAME)

DU_AN="${COMPOSE_PROJECT_NAME:-mgmt-device}"
MANG="${DU_AN}_default"
ANH="${DU_AN}_api"

docker image inspect "$ANH" >/dev/null 2>&1 || { echo "Chưa có ảnh $ANH — chạy docker-compose build api trước."; exit 1; }
docker network inspect "$MANG" >/dev/null 2>&1 || { echo "Chưa có mạng $MANG — stack chưa chạy?"; exit 1; }

docker run --rm --network "$MANG" \
  -e DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}" \
  -e TEST_DB="${TEST_DB:-thu_api}" \
  -e SCHEMA_SQL=/srv/schema.sql \
  -e PYTHONPATH=/srv \
  -v "$PWD/db/schema.sql:/srv/schema.sql:ro" \
  -v "$PWD/tests/api:/kiem:ro" \
  -w /srv \
  "$ANH" python /kiem/chay_api.py
