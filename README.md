# 🚀 Kafka CDC Hands-on Lab

> **Change Data Capture (CDC)** với Apache Kafka, Debezium và PostgreSQL  
> Môi trường thực hành hoàn chỉnh — khởi động bằng một lệnh duy nhất.

---

## 📋 Mục lục

- [Kiến trúc hệ thống](#-kiến-trúc-hệ-thống)
- [Yêu cầu](#-yêu-cầu)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Khởi động nhanh](#-khởi-động-nhanh)
- [Các URL quan trọng](#-các-url-quan-trọng)
- [Thực hành CDC](#-thực-hành-cdc)
- [Cấu hình nâng cao](#-cấu-hình-nâng-cao)
- [Lệnh thường dùng](#-lệnh-thường-dùng)
- [Xử lý sự cố](#-xử-lý-sự-cố)

---

## 🏗 Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Network                           │
│                                                                 │
│  ┌──────────────┐    CDC events    ┌──────────────────────────┐ │
│  │  PostgreSQL  │ ──────────────▶  │    Kafka Connect         │ │
│  │  (Debezium   │   (WAL/logical   │  (Distributed mode)      │ │
│  │   image)     │    replication)  │  + Debezium Connector    │ │
│  │              │                  │                          │ │
│  │  Schema:shop │                  └──────────┬───────────────┘ │
│  │  • customers │                             │ publish topics  │
│  │  • products  │                             ▼                 │
│  │  • orders    │                  ┌──────────────────────────┐ │
│  └──────────────┘                  │   Apache Kafka (KRaft)   │ │
│                                    │   Không cần ZooKeeper!   │ │
│  ┌──────────────┐                  │                          │ │
│  │   Kafka UI   │ ◀─── REST API ── │   Topics:                │ │
│  │  :8080       │                  │   cdc_lab.shop.customers │ │
│  │  (Web GUI)   │                  │   cdc_lab.shop.products  │ │
│  └──────────────┘                  │   cdc_lab.shop.orders    │ │
│                                    └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Vì sao các công nghệ này?

| Component | Image | Lý do chọn |
|-----------|-------|------------|
| **Kafka** | `confluentinc/cp-kafka:7.7.1` | KRaft mode — không cần ZooKeeper, đơn giản hơn cho lab |
| **Kafka UI** | `provectuslabs/kafka-ui` | Giao diện web trực quan, xem message real-time |
| **PostgreSQL** | `debezium/postgres:16` | Đã bật sẵn `wal_level=logical` — không cần chỉnh config hệ thống |
| **Kafka Connect** | `debezium/connect:2.7` | Cụm distributed, tích hợp sẵn Debezium connector plugins |

---

## ✅ Yêu cầu

| Công cụ | Phiên bản tối thiểu | Kiểm tra |
|---------|---------------------|----------|
| Docker | 24.x+ | `docker --version` |
| Docker Compose | v2.x+ (plugin) | `docker compose version` |
| RAM trống | ≥ 4 GB | — |
| Disk trống | ≥ 2 GB | — |

> **Windows users:** Dùng WSL2 hoặc Git Bash để chạy các script `.sh`.

---

## 📁 Cấu trúc thư mục

```
kafka-cdc-lab/
├── docker-compose.yml          ← File chính, định nghĩa toàn bộ services
├── .env                        ← Biến môi trường (port, password, ...)
├── .gitignore
│
├── init-scripts/
│   └── 01_init.sql             ← SQL khởi tạo schema, bảng, dữ liệu mẫu
│                                  (tự động chạy lần đầu tiên)
│
├── connectors/
│   └── postgres-cdc-connector.json  ← Config Debezium connector (dùng khi đăng ký)
│
└── scripts/
    ├── register-connector.sh   ← Script đăng ký connector vào Kafka Connect
    └── check-status.sh         ← Script kiểm tra trạng thái hệ thống
```

---

## ⚡ Khởi động nhanh

### Bước 1 — Clone repo & khởi động

```bash
git clone <repo-url>
cd kafka-cdc-lab

# Khởi động tất cả services (lần đầu sẽ tải image, mất 2–5 phút)
docker compose up -d
```

### Bước 2 — Chờ hệ thống sẵn sàng

```bash
# Xem log realtime (Ctrl+C để thoát)
docker compose logs -f

# Hoặc kiểm tra trạng thái nhanh
bash scripts/check-status.sh
```

Tất cả services `healthy` là xong ✅

### Bước 3 — Đăng ký Debezium connector

```bash
bash scripts/register-connector.sh
```

Connector sẽ bắt đầu **đọc toàn bộ dữ liệu hiện có** (snapshot), sau đó chuyển sang **theo dõi thay đổi real-time** (streaming).

### Bước 4 — Mở Kafka UI và quan sát

Truy cập **http://localhost:8080** → Topics → tìm `cdc_lab.shop.*`

---

## 🌐 Các URL quan trọng

| Service | URL | Ghi chú |
|---------|-----|---------|
| **Kafka UI** | http://localhost:8080 | Quản lý topic, xem message |
| **Kafka Connect REST API** | http://localhost:8083 | Quản lý connectors |
| **PostgreSQL** | `localhost:5434` | Dùng pgAdmin hoặc DBeaver để kết nối |

**Thông tin kết nối PostgreSQL:**
```
Host:     localhost
Port:     5434
Database: labdb
User:     labuser
Password: labpassword
```

---

## 🧪 Thực hành CDC

### Lab 1 — Xem snapshot ban đầu

Sau khi đăng ký connector, Debezium sẽ đọc toàn bộ dữ liệu có sẵn.

1. Mở **Kafka UI** → **Topics**
2. Tìm topic `cdc_lab.shop.customers`
3. Nhấn **Messages** → xem các message dạng JSON

Mỗi message là một bản ghi từ bảng `customers`, với `op: "r"` (read/snapshot).

---

### Lab 2 — Capture INSERT

Kết nối PostgreSQL và chèn dữ liệu mới:

```sql
-- Kết nối vào database
-- psql -h localhost -p 5434 -U labuser -d labdb

INSERT INTO shop.customers (full_name, email, phone)
VALUES ('Phạm Thị D', 'phamthid@example.com', '0934567890');
```

Quay lại **Kafka UI** → topic `cdc_lab.shop.customers` → xem message mới với `"op": "c"` (create).

---

### Lab 3 — Capture UPDATE

```sql
UPDATE shop.products
SET price = 29990000, stock = 12
WHERE name = 'Laptop Dell XPS 13';
```

Message trong Kafka sẽ có `"op": "u"` và chứa cả **giá trị cũ** (`before`) lẫn **giá trị mới** (`after`) nhờ `REPLICA IDENTITY FULL`.

---

### Lab 4 — Capture DELETE

```sql
DELETE FROM shop.customers WHERE email = 'phamthid@example.com';
```

Message có `"op": "d"`, trường `after` là `null`.

---

### Lab 5 — Xem cấu trúc message CDC

Mỗi message Debezium có cấu trúc:

```json
{
  "before": { ... },   // Dữ liệu TRƯỚC thay đổi (null với INSERT)
  "after":  { ... },   // Dữ liệu SAU thay đổi (null với DELETE)
  "source": {
    "connector": "postgresql",
    "db": "labdb",
    "schema": "shop",
    "table": "customers",
    "lsn": 12345678    // Log Sequence Number trong WAL
  },
  "op": "c",           // c=create, u=update, d=delete, r=read(snapshot)
  "ts_ms": 1700000000000
}
```

---

## ⚙️ Cấu hình nâng cao

### Thay đổi port

Chỉnh sửa file `.env`:

```bash
KAFKA_BROKER_PORT=9092    # đổi thành 9192 nếu bị xung đột
KAFKA_UI_PORT=8080        # đổi thành 8888 nếu cần
POSTGRES_HOST_PORT=5434   # đổi thành 5433, v.v.
```

Sau đó restart:

```bash
docker compose down
docker compose up -d
```

### Thêm bảng vào CDC

Chỉnh sửa `connectors/postgres-cdc-connector.json`, thêm tên bảng vào `table.include.list`:

```json
"table.include.list": "shop.customers,shop.products,shop.orders,shop.ten_bang_moi"
```

Rồi cập nhật connector:

```bash
bash scripts/register-connector.sh
```

### Xem log từng service

```bash
docker compose logs kafka          # Kafka broker
docker compose logs kafka-connect  # Kafka Connect + Debezium
docker compose logs postgres       # PostgreSQL
docker compose logs kafka-ui       # Kafka UI
```

---

## 📜 Lệnh thường dùng

```bash
# --- Khởi động / Dừng ---
docker compose up -d               # Khởi động tất cả (background)
docker compose down                # Dừng, giữ nguyên data
docker compose down -v             # Dừng và XOÁ toàn bộ data (reset sạch)
docker compose restart kafka       # Restart riêng một service

# --- Kiểm tra trạng thái ---
docker compose ps                  # Trạng thái container
bash scripts/check-status.sh       # Kiểm tra tổng thể

# --- Kafka (chạy trực tiếp trong container) ---
# Liệt kê topics
docker exec kafka kafka-topics --bootstrap-server kafka:29092 --list

# Tạo topic thủ công
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --create --topic my-topic --partitions 3 --replication-factor 1

# Consume message từ topic
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic cdc_lab.shop.customers \
  --from-beginning

# --- PostgreSQL ---
docker exec -it postgres psql -U labuser -d labdb

# --- Kafka Connect REST API ---
curl http://localhost:8083/connectors                             # Liệt kê connectors
curl http://localhost:8083/connectors/postgres-cdc-connector/status  # Trạng thái connector
curl -X DELETE http://localhost:8083/connectors/postgres-cdc-connector  # Xoá connector
```

---

## 🔧 Xử lý sự cố

### Container không khởi động được

```bash
# Xem log chi tiết
docker compose logs --tail=50 <service-name>

# Kiểm tra port xung đột
lsof -i :8080   # hoặc netstat -tulpn | grep 8080
```

**Giải pháp:** Đổi port trong `.env` rồi restart.

---

### Connector ở trạng thái FAILED

```bash
# Xem lỗi
curl http://localhost:8083/connectors/postgres-cdc-connector/status

# Restart connector
curl -X POST http://localhost:8083/connectors/postgres-cdc-connector/restart

# Restart task cụ thể (task 0)
curl -X POST http://localhost:8083/connectors/postgres-cdc-connector/tasks/0/restart
```

---

### Không thấy message trong Kafka UI

1. Kiểm tra connector đang **RUNNING** (không phải FAILED/PAUSED)
2. Trong Kafka UI → chọn đúng **Offset reset** là `Earliest` khi xem messages
3. Đảm bảo PostgreSQL đã chạy `01_init.sql` (kiểm tra bảng có tồn tại không)

---

### Lỗi "replication slot already exists"

```sql
-- Chạy trong PostgreSQL để xoá slot cũ
SELECT pg_drop_replication_slot('debezium_lab_slot');
```

Sau đó đăng ký lại connector.

---

### Reset toàn bộ (bắt đầu lại từ đầu)

```bash
docker compose down -v   # Xoá containers + volumes (MẤT HẾT DATA)
docker compose up -d     # Khởi động lại
bash scripts/register-connector.sh
```

---

## 📚 Tài liệu tham khảo

- [Debezium PostgreSQL Connector Docs](https://debezium.io/documentation/reference/stable/connectors/postgresql.html)
- [Kafka Connect REST API](https://docs.confluent.io/platform/current/connect/references/restapi.html)
- [Kafka UI GitHub](https://github.com/provectus/kafka-ui)
- [KRaft Mode — Kafka without ZooKeeper](https://kafka.apache.org/documentation/#kraft)

---

## 📄 License

MIT — Tự do sử dụng cho mục đích học tập và giảng dạy.
