-- Atlas Ops — schema Postgres. Chạy tự động khi container db khởi tạo lần đầu.
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
    kind    TEXT NOT NULL DEFAULT 'datacenter'   -- datacenter | warehouse
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
    UNIQUE (room_id, code)
);

CREATE TABLE IF NOT EXISTS supplier (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL
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
    -- Hai trường tách bạch: mã đã khớp vs nhãn cụm tự do (388 dòng chưa khớp)
    parent_asset_id     TEXT REFERENCES asset(asset_id) ON DELETE SET NULL,
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
    source_sheet        TEXT,
    source_row          INTEGER,
    review_flags        TEXT[] NOT NULL DEFAULT '{}',
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS asset_event (
    id                          BIGSERIAL PRIMARY KEY,
    asset_id                    TEXT NOT NULL REFERENCES asset(asset_id) ON DELETE CASCADE,
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
    UNIQUE (asset_id, event_sequence)
);

CREATE TABLE IF NOT EXISTS placement (
    id        BIGSERIAL PRIMARY KEY,
    asset_id  TEXT NOT NULL REFERENCES asset(asset_id) ON DELETE CASCADE,
    rack_id   INTEGER NOT NULL REFERENCES rack(id) ON DELETE CASCADE,
    start_u   INTEGER NOT NULL,
    size_u    INTEGER NOT NULL DEFAULT 1,
    from_date DATE,
    to_date   DATE,
    CHECK (start_u > 0 AND size_u > 0)
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
