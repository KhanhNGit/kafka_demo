# ⌨️ Kafka CLI Cheat Sheet

> Tất cả lệnh Kafka CLI chạy **bên trong container `kafka`** (bootstrap: `kafka:29092`).  
> Lệnh `curl` gọi từ **máy host** (`localhost:8083`).

---

## 🔌 Thông số kết nối nhanh

| Tham số | Giá trị |
|---------|---------|
| Bootstrap Server (internal) | `kafka:29092` |
| Bootstrap Server (host) | `localhost:9092` |
| Kafka Connect REST | `http://localhost:8083` |
| Kafka UI | `http://localhost:8080` |
| PostgreSQL (host) | `localhost:5434` · db=`labdb` · user=`labuser` |

---

## 📋 Topics

### Liệt kê tất cả topics
```bash
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --list
```

### Tạo topic mới
```bash
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --create --topic my-topic \
  --partitions 3 \
  --replication-factor 1
```

### Xem chi tiết một topic
```bash
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --describe \
  --topic cdc_lab.shop.customers
```
> Hiển thị số partition, replication factor, leader broker.

### Xoá topic
```bash
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --delete --topic my-topic
```

---

## 📤 Producer — Gửi message

### Gửi thủ công (interactive)
```bash
docker exec -it kafka kafka-console-producer \
  --bootstrap-server kafka:29092 \
  --topic my-topic
```
> Gõ nội dung → Enter để gửi. **Ctrl+C** để thoát.

### Gửi message có key
```bash
docker exec -it kafka kafka-console-producer \
  --bootstrap-server kafka:29092 \
  --topic my-topic \
  --property parse.key=true \
  --property key.separator=:
```
> Nhập theo dạng `key:value` mỗi dòng.

### Pipe file vào topic
```bash
cat data.json | docker exec -i kafka kafka-console-producer \
  --bootstrap-server kafka:29092 \
  --topic my-topic
```

---

## 📥 Consumer — Đọc message

### Đọc từ đầu (toàn bộ history)
```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic cdc_lab.shop.customers \
  --from-beginning
```
> **Ctrl+C** để dừng.

### Đọc kèm key và timestamp
```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic cdc_lab.shop.orders \
  --from-beginning \
  --property print.key=true \
  --property print.timestamp=true
```
> Output format: `Timestamp \t Key \t Value`

### Giới hạn số message đọc
```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic my-topic \
  --from-beginning \
  --max-messages 10
```

### Đọc với consumer group (offset được lưu)
```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic my-topic \
  --group lab-consumer-group
```
> Chạy lại sẽ tiếp tục từ offset cuối cùng đã đọc.

---

## 👥 Consumer Groups

### Liệt kê tất cả groups
```bash
docker exec kafka kafka-consumer-groups \
  --bootstrap-server kafka:29092 \
  --list
```

### Xem lag của một group
```bash
docker exec kafka kafka-consumer-groups \
  --bootstrap-server kafka:29092 \
  --describe \
  --group lab-consumer-group
```
> Cột **LAG** = số message chưa xử lý. `LAG=0` nghĩa là consumer đang bắt kịp.

### Reset offset về đầu
```bash
docker exec kafka kafka-consumer-groups \
  --bootstrap-server kafka:29092 \
  --group lab-consumer-group \
  --topic my-topic \
  --reset-offsets \
  --to-earliest \
  --execute
```
> ⚠️ Group phải **không có consumer nào đang chạy** thì mới reset được.

---

## 📊 Cluster & Metadata

### Xem offset hiện tại của topic
```bash
docker exec kafka kafka-get-offsets \
  --bootstrap-server kafka:29092 \
  --topic cdc_lab.shop.products
```
> Output: `topic:partition:offset`

### Xem config của topic
```bash
docker exec kafka kafka-configs \
  --bootstrap-server kafka:29092 \
  --entity-type topics \
  --entity-name my-topic \
  --describe
```

### Xem thông tin broker API versions
```bash
docker exec kafka kafka-broker-api-versions \
  --bootstrap-server kafka:29092
```

### Xem trạng thái KRaft quorum
```bash
docker exec kafka kafka-metadata-quorum \
  --bootstrap-server kafka:29092 \
  describe --status
```

---

## 🔌 Kafka Connect REST API

### Liệt kê connectors đang chạy
```bash
curl -s http://localhost:8083/connectors
```

### Xem trạng thái connector
```bash
curl -s http://localhost:8083/connectors/postgres-cdc-connector/status
```

### Đăng ký connector từ file JSON
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d @connectors/postgres-cdc-connector.json \
  http://localhost:8083/connectors
```

### Cập nhật config connector
```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -d '{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","tasks.max":"1",...}' \
  http://localhost:8083/connectors/postgres-cdc-connector/config
```

### Restart connector bị lỗi
```bash
curl -X POST http://localhost:8083/connectors/postgres-cdc-connector/restart
```

### Restart task cụ thể (task 0)
```bash
curl -X POST http://localhost:8083/connectors/postgres-cdc-connector/tasks/0/restart
```

### Tạm dừng / Tiếp tục connector
```bash
# Tạm dừng
curl -X PUT http://localhost:8083/connectors/postgres-cdc-connector/pause

# Tiếp tục
curl -X PUT http://localhost:8083/connectors/postgres-cdc-connector/resume
```

### Xoá connector
```bash
curl -X DELETE http://localhost:8083/connectors/postgres-cdc-connector
```

### Liệt kê plugins đã cài
```bash
curl -s http://localhost:8083/connector-plugins | python3 -m json.tool
```

---

## 🐘 PostgreSQL — Thao tác CDC

### Kết nối vào database
```bash
docker exec -it postgres psql -U labuser -d labdb
```

### Kiểm tra WAL level (phải là `logical`)
```sql
SHOW wal_level;
-- Kết quả mong đợi: logical
```

### Xem replication slots (Debezium tạo tự động)
```sql
SELECT slot_name, plugin, active, restart_lsn
FROM pg_replication_slots;
```

### Xem publications
```sql
SELECT pubname, puballtables FROM pg_publication;
```

### INSERT → tạo CDC event `op: "c"`
```sql
INSERT INTO shop.customers (full_name, email, phone)
VALUES ('Nguyen Van X', 'x@example.com', '0900000001');
```

### UPDATE → tạo CDC event `op: "u"`
```sql
UPDATE shop.products
SET price = 25000000, stock = 8
WHERE id = 1;
```
> Message Kafka sẽ có cả `before` (giá trị cũ) và `after` (giá trị mới) nhờ `REPLICA IDENTITY FULL`.

### DELETE → tạo CDC event `op: "d"`
```sql
DELETE FROM shop.customers
WHERE email = 'x@example.com';
```
> Trường `after` trong message sẽ là `null`.

### Xoá replication slot (khi cần reset connector)
```sql
SELECT pg_drop_replication_slot('debezium_lab_slot');
```

---

## 🐳 Docker Compose

```bash
# Khởi động tất cả services
docker compose up -d

# Xem trạng thái containers
docker compose ps

# Xem log realtime (tất cả)
docker compose logs -f

# Xem log một service cụ thể
docker compose logs -f kafka-connect

# Restart một service
docker compose restart kafka-connect

# Dừng — giữ nguyên data
docker compose down

# Reset hoàn toàn (XOÁ toàn bộ data!)
docker compose down -v

# Kiểm tra sức khoẻ hệ thống
bash scripts/check-status.sh

# Đăng ký connector
bash scripts/register-connector.sh
```

---

## 📖 Cấu trúc message CDC (Debezium)

Mỗi event CDC trong Kafka có dạng JSON:

```json
{
  "before": {
    "id": 1,
    "full_name": "Nguyen Van A",
    "email": "a@example.com"
  },
  "after": {
    "id": 1,
    "full_name": "Nguyen Van A (updated)",
    "email": "a@example.com"
  },
  "source": {
    "connector": "postgresql",
    "db": "labdb",
    "schema": "shop",
    "table": "customers",
    "lsn": 23456789
  },
  "op": "u",
  "ts_ms": 1700000000000
}
```

| Giá trị `op` | Ý nghĩa | `before` | `after` |
|---|---|---|---|
| `r` | Read (snapshot ban đầu) | `null` | có data |
| `c` | Create (INSERT) | `null` | có data |
| `u` | Update (UPDATE) | có data | có data |
| `d` | Delete (DELETE) | có data | `null` |

---

## 🔗 Topics CDC được tạo tự động

| Topic | Tương ứng bảng |
|-------|----------------|
| `cdc_lab.shop.customers` | `shop.customers` |
| `cdc_lab.shop.products` | `shop.products` |
| `cdc_lab.shop.orders` | `shop.orders` |

> Format: `{topic.prefix}.{schema}.{table}` — cấu hình trong `connectors/postgres-cdc-connector.json`
