#!/usr/bin/env bash
# Triển khai từ git, thay cho lối chép tay bằng scp.
#   ssh root@<server> 'cd /root/mgmt-device && ./scripts/trien_khai.sh'
#
# KHÔNG đụng .env và KHÔNG đụng volume dữ liệu — chỉ kéo mã mới rồi dựng lại container.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "Thiếu .env — chép từ .env.example rồi điền giá trị thật."; exit 1; }

cu=$(git rev-parse --short HEAD)
git pull --ff-only
moi=$(git rev-parse --short HEAD)
[ "$cu" = "$moi" ] && echo "Không có gì mới ($cu)." || echo "Cập nhật $cu -> $moi"

# docker-compose v1 phải rm trước khi up, không thì lỗi KeyError: 'ContainerConfig'.
docker-compose rm -sf api web >/dev/null 2>&1 || true

# Nêu ĐÍCH DANH service, không dùng `up -d` trống:
#   - `up -d` trống kéo theo cả service `seed` (chạy một lần rồi thoát). Container seed cũ còn
#     nằm đó, compose đòi dựng lại nó và vấp đúng KeyError: 'ContainerConfig' -> triển khai gãy
#     giữa chừng dù api/web chẳng sao.
#   - `-V` (renew anonymous volumes) làm compose bỏ qua đoạn code đọc image_config của container
#     cũ — chính chỗ ném KeyError. Không mất dữ liệu: pgdata và backups đều là named volume.
# Muốn nạp dữ liệu gốc thì gọi tay: docker-compose run --rm seed
docker-compose up -d --build -V db api web

# index.html được bind-mount THEO FILE. `git pull` (và rsync, và phần lớn trình soạn thảo)
# thay file bằng cách ghi file mới rồi đổi tên, nên inode đổi và container nginx vẫn giữ
# inode CŨ đã bị xoá — trang vẫn lên 200 nhưng là bản cũ, rất dễ tưởng đã triển khai xong.
# Dựng lại web là xong; nginx khởi động dưới một giây.
docker-compose up -d --no-deps --force-recreate web

# Chờ API khỏe hẳn rồi mới báo xong, đừng báo xong khi nó còn đang khởi động.
for i in $(seq 1 30); do
  ma=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:"${WEB_PORT:-8084}"/ || true)
  [ "$ma" = "200" ] && { echo "Xong — app trả HTTP 200 (bản $moi)"; exit 0; }
  sleep 2
done
echo "API chưa lên sau 60 giây. Xem log: docker-compose logs --tail=50 api"; exit 1
