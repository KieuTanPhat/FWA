# ADR 001 — MQTT 3.1.1 trong PoC

Ngày: 23/09/2026. Trạng thái: áp dụng cho PoC.

Tài liệu đầu vào nêu MQTT 5.0. Thư viện ESP32 dùng trong PoC hỗ trợ ổn định MQTT 3.1.1; các tính năng bắt buộc chỉ cần QoS 1, retained status, LWT và ACL. Backend dùng MQTT 3.1.1 (`protocolVersion: 4`) để tương thích cùng firmware. Application ACK của alert là bản tin riêng; không phụ thuộc PUBACK. Việc chuyển MQTT 5.0 cần kiểm thử client thiết bị và cập nhật toàn bộ producer/consumer, không đổi giao thức ngầm giữa các mốc.

