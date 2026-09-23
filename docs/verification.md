# Biên bản kiểm tra PoC

Ngày: 23/09/2026  
Nhánh: `feat/ung-dung-flutter-theo-doi`  
Commit nền trước đợt hoàn thiện: `0f7f5cd`

## Môi trường

- Node.js 24.14.1, npm 11.11.0
- Flutter 3.41.2 stable, Dart 3.11.0
- PlatformIO Core 6.2.0; Espressif32 6.12.0; Arduino-ESP32 2.0.17
- Android emulator: Android 16, API 36

## Kiểm tra phần mềm

| Thành phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `cd backend; npm test` | Đạt: 6 test contract |
| Backend | `cd backend; npm run build` | Đạt: TypeScript compile |
| Simulator | `cd simulator; npm test` | Đạt: 2 test kịch bản |
| Simulator | `cd simulator; npm run check` | Đạt: TypeScript compile |
| Firmware core | `cd firmware; python -m platformio test -e native` | Đạt: 2 test parser, risk và đầu ra cảnh báo |
| Firmware ESP32 | `cd firmware; python -m platformio run -e esp32dev` | Đạt: tạo firmware image; RAM 14.4%, flash app slot 64.4% |
| Flutter | `cd mobile; flutter analyze` | Đạt: không có lỗi phân tích |
| Flutter | `cd mobile; flutter test` | Đạt: widget/model/controller tests |
| Android | `cd mobile; flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000` | Đạt: APK debug build |

APK debug đã khởi chạy trên Android emulator. Khi backend không truy cập được, app hiển thị dữ liệu cũ/không xác định và trạng thái liên kết chưa xác minh; không trình bày cấp NORMAL như hiện trạng. Đây là kiểm tra UI offline, không phải kiểm tra kết nối đầu-cuối.

## Kiểm tra chưa thực hiện

- **Luồng simulator → Mosquitto → backend → PostgreSQL → REST/WebSocket → app:** chưa chạy. Docker Engine đang dừng; `com.docker.service` không thể mở từ phiên hiện tại. Vì vậy migration trên DB sạch, chống trùng/late message qua broker thật, application ACK và lỗi ghi DB chưa được xác minh tích hợp.
- **Thiết bị bench:** `platformio device list` không thấy cổng ESP32. Không có bằng chứng đo A02YYUW, đấu nối/điện áp, LED/còi thật, mất Wi-Fi, reboot khi offline hoặc phát lại outbox trên phần cứng.
- **Hiệu chuẩn:** chưa có log ba mức × 30 mẫu, giới hạn sai số đã được nhóm duyệt, MAE/max error/độ lệch chuẩn.
- **Điện thoại thật và LAN:** chưa kiểm tra điện thoại thật truy cập backend qua Wi-Fi; mới build/chạy trên emulator.
- **Soak và rehearsal:** chưa có log 24 giờ hoặc video rehearsal 5–7 phút.

## Mức bằng chứng

- **SIMULATOR VERIFIED:** chưa đạt cho toàn chuỗi; unit/scenario tests đã đạt nhưng luồng có broker/database thật chưa chạy.
- **BENCH VERIFIED:** chưa đạt; firmware chỉ được compile và kiểm tra native.
- **FIELD VERIFIED:** chưa đạt và không phải mục tiêu PoC mặc định.

Không dùng kết quả compile/unit test để tuyên bố cảm biến, còi/đèn hoặc hệ thống cảnh báo đã được kiểm chứng thực tế.
