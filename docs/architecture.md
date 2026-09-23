# Kiến trúc

```text
A02YYUW → ESP32 → phân cấp rủi ro → đèn/còi tại chỗ
                    │
                    └→ MQTT QoS 1 → NestJS → PostgreSQL → REST/WebSocket → Flutter
Simulator (sim-01) ────────────────┘
```

Quyết định kích hoạt còi/đèn được thực hiện trên ESP32 trước khi gửi MQTT. Server và app chỉ hiển thị; không có API điều khiển thiết bị. `risk_validity`, `sensor_quality`, `link_state` và `freshness` là bốn khái niệm độc lập. Khi số đo cũ hoặc không hợp lệ, UI phải hiện **Không xác định**, kể cả nếu cấp rủi ro cuối cùng là NORMAL.

Mạng Wi-Fi chỉ là đường chuyển bản tin trong phòng lab. LTE/LoRa là các phần mở rộng sau khi phần cứng và PoC cơ bản được kiểm chứng.

