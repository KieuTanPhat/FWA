# FWA — Trạm cảnh báo lũ IoT

Repository bàn giao **hai sản phẩm**: (1) hệ thống IoT cảnh báo lũ tại trạm là sản phẩm cốt lõi; (2) ứng dụng Flutter Android để quan sát và demo. ESP32 đo mực nước, tự quyết định cảnh báo và điều khiển đèn/còi. MQTT và backend chỉ chuyển/lưu trạng thái cho điện thoại, không quyết định thay trạm. Dữ liệu từ simulator luôn mang danh tính trạm riêng và được hiển thị là **MÔ PHỎNG**.

## Thành phần

| Thư mục | Vai trò |
|---|---|
| `firmware/` | ESP32, cảm biến A02YYUW, state machine và còi/đèn cục bộ |
| `backend/` | NestJS, MQTT, PostgreSQL, REST và WebSocket |
| `mobile/` | Flutter Android: trạm, số đo, lịch sử và sự kiện |
| `simulator/` | Kịch bản demo lặp lại được |
| `infra/` | Docker Compose, Mosquitto ACL và PostgreSQL |
| `docs/` | Hợp đồng dữ liệu, quyết định và runbook |

Xem [runbook](docs/runbook.md) để khởi động demo. Dự án là prototype phòng lab; ngưỡng trong cấu hình là **DEMO ONLY** và không dùng để đưa ra quyết định an toàn ngoài thực địa.
