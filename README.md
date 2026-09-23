# FWA — Trạm cảnh báo lũ IoT

FWA gồm firmware trạm IoT, web điều khiển mô phỏng và ứng dụng Flutter Android. Trạm ESP32 chạy logic cảnh báo cục bộ; backend nhận và lưu dữ liệu, đồng bộ cho web/app qua REST và WebSocket. Bản web hiện là mô hình server-side theo sơ đồ Wokwi, không giả làm thiết bị lắp ngoài thực địa. Toàn bộ ba vùng demo mang danh tính **MÔ PHỎNG** riêng.

## Thành phần

| Thư mục | Vai trò |
|---|---|
| `firmware/` | ESP32, cảm biến A02YYUW, state machine và còi/đèn cục bộ |
| `backend/` | NestJS, MQTT, PostgreSQL, REST và WebSocket |
| `backend/public/` | Web IoT: sơ đồ SVG tương tác, điều khiển kịch bản và nhật ký |
| `mobile/` | Flutter Android: bắt buộc chọn vùng, bản đồ, số đo, lịch sử và sự kiện |
| `simulator/` | Kịch bản demo lặp lại được |
| `infra/` | Docker Compose, Mosquitto ACL và PostgreSQL |
| `docs/` | Hợp đồng dữ liệu, quyết định và runbook |

Xem [runbook](docs/runbook.md) để khởi động demo. Dự án là prototype phòng lab; ngưỡng trong cấu hình là **DEMO ONLY** và không dùng để đưa ra quyết định an toàn ngoài thực địa.

## Giao diện ứng dụng

Mở web tại `/iot`. Sơ đồ SVG lấy trực tiếp danh sách linh kiện và dây nối từ `backend/public/diagram.json`. Có một cảm biến mô phỏng cho mỗi lưu vực: `sim-01` Thao–Chảy, `sim-02` Hương–Bồ, `sim-03` Vu Gia–Thu Bồn. Số đo được ghi mỗi 5 giây vào PostgreSQL; REST/WebSocket cấp dữ liệu cho web và app. Chỉ web IoT có thể thay đổi số đo và ngưỡng. Khi sửa ngưỡng, web yêu cầu xác nhận; nước cần cách nhau tối thiểu 5 cm, tốc độ dâng cách nhau tối thiểu 1 cm/phút. Mặc định các mức nước là 30/50/70 cm, tốc độ là 5/10/15 cm/phút; mức tăng cần 3 mẫu liên tiếp, mức giảm cần qua vùng hồi phục 5 cm trong 4 mẫu.

Trong app người dùng chọn một vùng khi mở lần đầu; bản đồ, nhật ký, số đo và thông báo chỉ hiển thị cảm biến của vùng đó. App chỉ đọc, không thay đổi số đo hay ngưỡng. Bản đồ dùng nền OpenStreetMap; vị trí cảm biến chỉ minh họa. App hiển thị mực nước hiện tại và ước tính tuyến tính theo tốc độ đo gần đây cho các mốc tới hạn, không phải dự báo thời tiết. Mức **Khẩn cấp** có thông báo ưu tiên cao, rung/âm báo và màn hình cảnh báo toàn màn hình nếu quyền Android đã được bật. Số liệu toàn hệ thống là mô phỏng, không phải cảnh báo thực tế.

Để tạo APK release nhỏ theo kiến trúc thiết bị, chạy trong `mobile/`:

```sh
flutter build apk --release --split-per-abi
```

Điện thoại Android ARM64 dùng `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; máy ARM 32-bit dùng `app-armeabi-v7a-release.apk`.

![Tổng quan trạm](mobile-screen.png)

![Sự kiện cảnh báo](mobile-alerts.png)

![Lịch sử mực nước](mobile-history.png)
