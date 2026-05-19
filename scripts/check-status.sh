#!/usr/bin/env bash
# =============================================================================
# scripts/check-status.sh
# Kiểm tra nhanh trạng thái toàn bộ hệ thống lab
# =============================================================================

set -uo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
KAFKA_UI_URL="${KAFKA_UI_URL:-http://localhost:8080}"

echo "============================================================"
echo "  KAFKA CDC LAB — Health Check"
echo "============================================================"
echo ""

check_service() {
  local name="$1"
  local url="$2"
  if curl -sf --max-time 3 "$url" > /dev/null 2>&1; then
    echo "  ✅ $name          → OK ($url)"
  else
    echo "  ❌ $name          → KHÔNG kết nối được ($url)"
  fi
}

echo "[ Services ]"
check_service "Kafka UI       " "$KAFKA_UI_URL"
check_service "Kafka Connect  " "$CONNECT_URL/connectors"

echo ""
echo "[ Containers ]"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
  docker ps --filter "network=cdc-lab-network" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "[ Connectors đang chạy ]"
CONNECTORS=$(curl -sf "$CONNECT_URL/connectors" 2>/dev/null || echo "[]")
if [ "$CONNECTORS" = "[]" ] || [ -z "$CONNECTORS" ]; then
  echo "  (Chưa có connector nào được đăng ký)"
  echo "  → Chạy: bash scripts/register-connector.sh"
else
  echo "$CONNECTORS" | python3 -c "
import json, sys
try:
    connectors = json.load(sys.stdin)
    for c in connectors:
        print(f'  • {c}')
except: pass
" 2>/dev/null || echo "  $CONNECTORS"
fi

echo ""
echo "[ Kafka Topics ]"
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --list 2>/dev/null | grep -v '^$' | sed 's/^/  • /' || \
  echo "  (Không thể liệt kê topics — kafka chưa sẵn sàng?)"

echo ""
echo "============================================================"
echo "  URLs triển khai:"
echo "    Kafka UI:      http://localhost:${KAFKA_UI_PORT:-8080}"
echo "    Kafka Connect: http://localhost:${CONNECT_PORT:-8083}/connectors"
echo "    PostgreSQL:    localhost:${POSTGRES_HOST_PORT:-5434}  db=${POSTGRES_DB:-labdb}"
echo "============================================================"
