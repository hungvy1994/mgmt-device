-- Device Management — schema Postgres. Chạy tự động khi container db khởi tạo lần đầu.
-- Database là nguồn dữ liệu duy nhất của ứng dụng; CSV/XLSX chỉ là đường nạp vào và lấy ra.
-- Mô hình theo docs/ARCH.md mục 3: vị trí tách thành Site → Phòng máy → Rack → Thiết bị.

CREATE TABLE IF NOT EXISTS status_catalog (
    code        TEXT PRIMARY KEY,
    label       TEXT NOT NULL,
    tag_style   TEXT NOT NULL DEFAULT 'idle',
    attention   BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS site (
    id      SERIAL PRIMARY KEY,
    name    TEXT UNIQUE NOT NULL,
    kind    TEXT NOT NULL DEFAULT 'datacenter',  -- datacenter | warehouse
    status  TEXT NOT NULL DEFAULT 'Đang sử dụng'
);

CREATE TABLE IF NOT EXISTS room (
    id      SERIAL PRIMARY KEY,
    site_id INTEGER NOT NULL REFERENCES site(id) ON DELETE CASCADE,
    code    TEXT NOT NULL,
    name    TEXT,
    UNIQUE (site_id, code)
);

CREATE TABLE IF NOT EXISTS rack (
    id        SERIAL PRIMARY KEY,
    room_id   INTEGER NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    code      TEXT NOT NULL,
    height_u  INTEGER NOT NULL DEFAULT 42,
    status    TEXT NOT NULL DEFAULT 'Đang sử dụng',
    UNIQUE (room_id, code)
);

CREATE TABLE IF NOT EXISTS supplier (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

-- Danh mục cụm vận hành: form tài sản chọn từ đây thay vì gõ tay, tránh lệch chính tả.
CREATE TABLE IF NOT EXISTS cluster (
    name TEXT PRIMARY KEY,
    note TEXT
);

CREATE TABLE IF NOT EXISTS asset (
    asset_id            TEXT PRIMARY KEY,
    asset_name          TEXT NOT NULL,
    asset_type          TEXT,
    asset_category      TEXT,
    ip_address          INET,
    ip_or_type_raw      TEXT,
    cluster             TEXT,
    datacenter          TEXT,
    current_location    TEXT,
    site_id             INTEGER REFERENCES site(id) ON DELETE SET NULL,
    room_id             INTEGER REFERENCES room(id) ON DELETE SET NULL,
    rack_id             INTEGER REFERENCES rack(id) ON DELETE SET NULL,
    -- Vị trí U của thiết bị trong rack. U1 là đáy rack (chuẩn EIA-310); NULL = chưa ghi nhận.
    rack_unit           INTEGER,
    rack_size_u         INTEGER,
    -- Hai trường tách bạch: mã đã khớp vs nhãn cụm tự do (388 dòng chưa khớp)
    -- ON UPDATE CASCADE: sửa mã tài sản thì quan hệ cha-con đi theo, không chặn câu lệnh.
    parent_asset_id     TEXT REFERENCES asset(asset_id) ON DELETE SET NULL ON UPDATE CASCADE,
    attachment_label    TEXT,
    capacity            TEXT,
    replacement_target  TEXT,
    usage_status        TEXT REFERENCES status_catalog(code),
    usage_status_label  TEXT,
    usage_start_date    DATE,          -- NULL hợp lệ: 531 dòng nguồn không ghi
    handover_date       DATE,
    handover_status     TEXT,
    purchase_invoice    TEXT,
    purchase_price_vnd  NUMERIC(18, 0),
    supplier_code       TEXT,
    supplier_name       TEXT,
    warranty_months     INTEGER,
    warranty_end_date   DATE,
    description         TEXT,
    -- Dấu vết nguồn: dòng nào của sổ Excel sinh ra bản ghi này. Chỉ để truy ngược,
    -- không phải nơi hệ thống đọc dữ liệu.
    source_sheet        TEXT,
    source_row          INTEGER,
    review_flags        TEXT[] NOT NULL DEFAULT '{}',
    -- origin: bản ghi vào hệ thống bằng đường nào — 'import' (nạp từ file) | 'manual' (nhập tay).
    origin              TEXT NOT NULL DEFAULT 'import',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS asset_event (
    id                          BIGSERIAL PRIMARY KEY,
    asset_id                    TEXT NOT NULL REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE,
    event_sequence              INTEGER NOT NULL,
    event_type                  TEXT,
    event_date                  DATE,
    location                    TEXT,
    usage_object                TEXT,
    notes                       TEXT,
    declared_transition_count   INTEGER,
    source_column               TEXT,
    source_row                  INTEGER,
    review_flags                TEXT[] NOT NULL DEFAULT '{}',
    origin                      TEXT NOT NULL DEFAULT 'import',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (asset_id, event_sequence)
);

CREATE TABLE IF NOT EXISTS placement (
    id        BIGSERIAL PRIMARY KEY,
    asset_id  TEXT NOT NULL REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE,
    rack_id   INTEGER NOT NULL REFERENCES rack(id) ON DELETE CASCADE,
    start_u   INTEGER NOT NULL,
    size_u    INTEGER NOT NULL DEFAULT 1,
    from_date DATE,
    to_date   DATE,
    CHECK (start_u > 0 AND size_u > 0)
);

-- Nhật ký nhập file. CSV/XLSX chỉ là công cụ bồi dữ liệu vào database — mỗi lần nạp
-- ghi lại một dòng để biết dữ liệu được bổ sung lúc nào, bằng file nào, do ai.
CREATE TABLE IF NOT EXISTS import_log (
    id         BIGSERIAL PRIMARY KEY,
    kind       TEXT NOT NULL,               -- assets | history
    file_name  TEXT NOT NULL,
    file_type  TEXT NOT NULL,               -- csv | xlsx
    rows_read  INTEGER NOT NULL DEFAULT 0,
    added      INTEGER NOT NULL DEFAULT 0,
    updated    INTEGER NOT NULL DEFAULT 0,
    skipped    INTEGER NOT NULL DEFAULT 0,
    username   TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tài khoản quản trị. Mật khẩu lưu dạng băm scrypt, KHÔNG bao giờ để dạng thô.
-- Tài khoản đầu tiên do service `seed` tạo từ ADMIN_USERNAME / ADMIN_PASSWORD.
CREATE TABLE IF NOT EXISTS app_user (
    id            SERIAL PRIMARY KEY,
    username      TEXT UNIQUE NOT NULL,
    email         TEXT,
    full_name     TEXT,
    role          TEXT NOT NULL DEFAULT 'admin',
    password_hash TEXT NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS user_session (
    token      TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_session_expires ON user_session (expires_at);

CREATE INDEX IF NOT EXISTS idx_import_log_time ON import_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_asset_origin     ON asset (origin);
CREATE INDEX IF NOT EXISTS idx_asset_status     ON asset (usage_status);
CREATE INDEX IF NOT EXISTS idx_asset_datacenter ON asset (datacenter);
CREATE INDEX IF NOT EXISTS idx_asset_cluster    ON asset (cluster);
CREATE INDEX IF NOT EXISTS idx_asset_flags      ON asset USING GIN (review_flags);
CREATE INDEX IF NOT EXISTS idx_event_asset      ON asset_event (asset_id, event_sequence);

INSERT INTO status_catalog (code, label, tag_style, attention, sort_order) VALUES
    ('in_use',                   'Đang vận hành',       'live',    FALSE, 1),
    ('in_use_needs_replacement', 'Đang dùng · cần thay','warn',    TRUE,  2),
    ('in_stock',                 'Trong kho',           'stock',   FALSE, 3),
    ('not_in_use',               'Không sử dụng',       'idle',    FALSE, 4),
    ('degraded',                 'Suy giảm hiệu năng',  'repair',  TRUE,  5),
    ('broken',                   'Hỏng',                'repair',  TRUE,  6),
    ('pending_disposal',         'Chờ thanh lý',        'warn',    TRUE,  7),
    ('retired',                  'Đã thanh lý',         'retired', FALSE, 8)
ON CONFLICT (code) DO NOTHING;
