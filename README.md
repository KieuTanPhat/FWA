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

Mở web tại `/iot`. Sơ đồ SVG lấy trực tiếp danh sách linh kiện và dây nối từ `backend/public/diagram.json`, bản triển khai đi cùng `diagram.json` của project. Có một cảm biến mô phỏng cho mỗi lưu vực: `sim-01` Thao–Chảy, `sim-02` Hương–Bồ, `sim-03` Vu Gia–Thu Bồn. Số đo mặc định lưu mỗi 5 giây vào PostgreSQL; WebSocket đồng bộ web/app, REST trả lịch sử. Web cho phép đổi mực nước, tốc độ mô phỏng, mưa, nhiệt độ, ngưỡng mực nước và ngưỡng tốc độ dâng. Tốc độ cm/phút được quy đổi theo chu kỳ 5 giây. Ngưỡng tốc độ mặc định 5/10/15 cm/phút; cần 3 mẫu để nâng cấp, hysteresis 5 cm và 4 mẫu để hạ cấp theo cấu hình firmware.

Trong app người dùng phải chọn một vùng khi mở lần đầu; bản đồ, nhật ký và thông báo trong app chỉ theo cảm biến của vùng đã chọn. Điều chỉnh mực nước hoặc ghi nhịp mưa từ app đi vào cùng backend nên cũng hiện trên web. Ba mức mặc định là 30/50/70 cm; cần 3 mẫu để nâng cấp, hysteresis 5 cm và 4 mẫu để hạ cấp. Tọa độ bản đồ là vị trí tham khảo. Đây là dữ liệu mô phỏng, không phải cảnh báo thực tế.

Để tạo APK release nhỏ theo kiến trúc thiết bị, chạy trong `mobile/`:

```sh
flutter build apk --release --split-per-abi
```

Điện thoại Android ARM64 dùng `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; máy ARM 32-bit dùng `app-armeabi-v7a-release.apk`.

![Tổng quan trạm](mobile-screen.png)

![Sự kiện cảnh báo](mobile-alerts.png)

![Lịch sử mực nước](mobile-history.png)
