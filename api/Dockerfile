FROM python:3.12-slim
WORKDIR /srv
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
# postgresql-client để có pg_dump / pg_restore cho tính năng sao lưu.
# Phiên bản client phải >= server, nên lấy từ kho chính thức của PostgreSQL.
# `apt-get upgrade` là bắt buộc, không phải thừa: ảnh nền python:3.12-slim đông cứng ở thời
# điểm phát hành nên luôn trễ vài bản vá bảo mật của Debian. Bỏ dòng này là ship ảnh dính CVE
# ĐÃ CÓ BẢN VÁ — thứ mà scripts/quet_bao_mat.sh chặn.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends postgresql-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py seed.py ./
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
