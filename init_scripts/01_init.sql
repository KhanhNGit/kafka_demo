-- =============================================================================
-- init-scripts/01_init.sql
-- Script khởi tạo database cho bài lab CDC
-- Chạy tự động lần đầu khi container PostgreSQL được tạo
-- =============================================================================

-- Tạo role replication (dùng cho Debezium connector)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
    CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'replicatorpassword';
  END IF;
END
$$;

-- Cấp quyền cho replicator
GRANT CONNECT ON DATABASE labdb TO replicator;

-- =============================================================================
-- Tạo schema và bảng mẫu cho bài thực hành
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS shop;

-- Bảng khách hàng
CREATE TABLE IF NOT EXISTS shop.customers (
    id          SERIAL PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    phone       VARCHAR(20),
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bảng sản phẩm
CREATE TABLE IF NOT EXISTS shop.products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    price       NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    stock       INTEGER NOT NULL DEFAULT 0,
    category    VARCHAR(50),
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bảng đơn hàng
CREATE TABLE IF NOT EXISTS shop.orders (
    id          SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES shop.customers(id),
    status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    total       NUMERIC(14, 2),
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- Bật REPLICA IDENTITY FULL để CDC capture cả giá trị cũ khi UPDATE/DELETE
-- =============================================================================
ALTER TABLE shop.customers REPLICA IDENTITY FULL;
ALTER TABLE shop.products  REPLICA IDENTITY FULL;
ALTER TABLE shop.orders    REPLICA IDENTITY FULL;

-- Cấp quyền SELECT cho replicator (cần cho initial snapshot của Debezium)
GRANT USAGE ON SCHEMA shop TO replicator;
GRANT SELECT ON ALL TABLES IN SCHEMA shop TO replicator;

-- =============================================================================
-- Dữ liệu mẫu
-- =============================================================================
INSERT INTO shop.customers (full_name, email, phone) VALUES
  ('Nguyễn Văn A', 'nguyenvana@example.com', '0901234567'),
  ('Trần Thị B',   'tranthib@example.com',   '0912345678'),
  ('Lê Văn C',     'levanc@example.com',      '0923456789')
ON CONFLICT (email) DO NOTHING;

INSERT INTO shop.products (name, price, stock, category) VALUES
  ('Laptop Dell XPS 13',  28990000, 15, 'Electronics'),
  ('Chuột không dây',       350000, 80, 'Accessories'),
  ('Bàn phím cơ RGB',       950000, 40, 'Accessories'),
  ('Màn hình 27 inch 4K',  8500000, 10, 'Electronics')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- Trigger tự cập nhật updated_at (tuỳ chọn, tiện cho demo)
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON shop.customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON shop.products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON shop.orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Xác nhận
\echo '✅ Database initialized successfully!'
\echo '   Schema: shop'
\echo '   Tables: customers, products, orders'
