# Biên bản kiểm tra PoC

Ngày: 23/09/2026
Nhánh: `feat/ung-dung-flutter-theo-doi`
Commit nguồn của APK debug: `6fe96ea` (`Giới hạn bề mặt truy cập API cho ứng dụng Android`).

## Môi trường

- Node.js 24.14.1, npm 11.11.0
- Flutter 3.41.2 stable, Dart 3.11.0
- PlatformIO Core 6.2.0; Espressif32 6.12.0; Arduino-ESP32 2.0.17
- Android emulator: Android 16, API 36

## Kiểm tra phần mềm

| Thành phần | Lệnh | Kết quả lần rà soát |
|---|---|---|
| Backend | `cd backend; npm test` | Đạt: 9 test, bao gồm contract, trạng thái risk và comparator thứ tự status |
| Backend | `cd backend; npm run build` | Đạt: TypeScript compile |
| Simulator | `cd simulator; npm test` | Đạt: 2 test scenario |
| Simulator | `cd simulator; npm run check` | Đạt: TypeScript compile |
| Firmware core | `cd firmware; python -m platformio test -e native` | Đạt: 5 test cases |
| Firmware ESP32 | `cd firmware; python -m platformio run -e esp32dev` | Đạt: build; RAM 14.4%, app flash slot 64.4% |
| Flutter | `cd mobile; flutter analyze` | Đạt: không có lỗi phân tích |
| Flutter | `cd mobile; flutter test` | Đạt: 8 test |
| Android | `cd mobile; flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000` | Đạt; APK debug build từ `6fe96ea`, SHA-256 `55E39D344A0D4F500BEC09870D37B6104F70E0D3E522E205F5D18B12CFD1C767` |

Sau khi xóa trailing whitespace khỏi các tài liệu trong nhánh, `git diff --check origin/main` đạt ở working tree hiện tại.

## Chưa kiểm tra

- **Simulator → Mosquitto → backend → PostgreSQL → REST/WebSocket → app:** chưa chạy. Docker Linux Engine hiện dừng. Chưa xác minh migration trên DB sạch, DB nâng cấp, status retained/LWT qua broker, ACK sau commit, lỗi ghi DB hay luồng app trực tiếp.
- **Thứ tự status:** comparator unit test có; chưa có transaction test PostgreSQL/MQTT. Status chỉ được nhận khi boot khớp boot mới nhất đã xác lập bởi telemetry.
- **Thiết bị bench:** không có cổng ESP32 kết nối. Chưa đo cảm biến, logic UART, nguồn, driver, còi/đèn, mất Wi-Fi, reboot offline, outbox replay hoặc đầy bộ đệm.
- **Hiệu chuẩn:** chưa có giới hạn sai số được duyệt hay ba mức × 30 mẫu/MAE/max error/độ lệch chuẩn.
- **Điện thoại thật/LAN:** chưa chạy qua Wi-Fi trên điện thoại thật.
- **Ổn định/bàn giao:** chưa có soak 24 giờ, p50/p95 từ tối thiểu 30 event, backup/restore, rehearsal 5–7 phút, release APK/hash gắn commit và tag.

## Mức bằng chứng

- **Unit/build verified:** đạt cho các lệnh trong bảng trên.
- **SIMULATOR VERIFIED:** chưa đạt cho toàn chuỗi broker/database/app.
- **BENCH VERIFIED:** chưa đạt; mới build firmware và native test.
- **FIELD VERIFIED:** chưa đạt và không phải mặc định của PoC.

Không dùng compile, unit test hay simulator đơn lẻ để tuyên bố hệ thống/cảm biến/còi/đèn đã được kiểm chứng ngoài đời.
