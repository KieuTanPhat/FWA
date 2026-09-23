# Runbook demo FWA

Repository có trạm IoT ESP32, web điều khiển simulator và ứng dụng Flutter Android. Backend/PostgreSQL là nguồn dữ liệu dùng chung cho web/app; firmware ESP32 vẫn tự xử lý cảnh báo cục bộ khi chạy phần cứng. Mọi ngưỡng và số đo trong kịch bản mô phỏng là **DEMO ONLY**.

## 1. Chuẩn bị một lần

Cần Node.js 24, Flutter 3.41.x, Android SDK, Python/PlatformIO và Docker Desktop đã chạy Linux engine. Máy backend và ESP32/điện thoại thật phải cùng LAN demo riêng. Không mở cổng MQTT/API ra Internet. Giữ `.env`, `infra/mosquitto/passwd` và `firmware/include/secrets.h` ngoài Git.

Từ thư mục gốc repository:

```powershell
pwsh -File infra/setup.ps1
docker compose up -d postgres mosquitto
cd backend
npm ci
npm run migrate
npm run dev
```

Script setup tạo credential ngẫu nhiên cho backend, simulator và `station-01`, với ACL chỉ cho từng trạm ghi topic của mình. Chạy lại script không đổi credentials đã có. `GET http://127.0.0.1:3000/healthz` phải trả `{"status":"ok"}`. Backend cần lắng nghe LAN cho điện thoại; PostgreSQL chỉ bind loopback trên máy chạy Docker.

Nếu Docker engine chưa chạy, sửa Docker Desktop rồi chạy lại script; script kiểm tra engine **trước khi** tạo file `.env` mới. Không dùng tài khoản/mật khẩu mẫu trong `.env.example`.

## 2. Chạy chuỗi mô phỏng

Mở terminal khác ở gốc repository:

```powershell
cd simulator
npm ci
npm run demo -- --scenario full --interval-ms 5000
```

Trạm `sim-01` có nhãn **MÔ PHỎNG** cố định. Kịch bản gồm NORMAL → WATCH → WARNING → EMERGENCY → lỗi cảm biến → phục hồi; backend nhận telemetry/alert và gửi application ACK. `npm run integration` kiểm tra chống trùng, sai thứ tự, nguồn dữ liệu, WebSocket và ACK khi broker/backend/database đang chạy. Dữ liệu simulator không chứng minh hoạt động của cảm biến hoặc còi/đèn.

## 3. Web mô phỏng ba cảm biến theo sơ đồ

Backend cần `DEMO_ONLY=true`, `MQTT_ENABLED=false` và đã chạy đủ migration. Mở `http://<IP-máy-backend>:3000/iot`. Web render phần ESP32, HC-SR04, DS18B20, nút gầu lật mưa, LED, còi và điện trở từ `backend/public/diagram.json`.

Mỗi vùng có một cảm biến server-side: `sim-01` Thao–Chảy, `sim-02` Hương–Bồ, `sim-03` Vu Gia–Thu Bồn. Backend phát một mẫu mỗi 5 giây, lưu mẫu vào PostgreSQL và đẩy sự kiện qua WebSocket. Web hiển thị số đo và có thể chỉnh mực nước, tốc độ, mưa, nhiệt độ cùng hai nhóm ngưỡng; app người dùng chỉ nhận số liệu, lịch sử và cảnh báo. Mặc định ngưỡng nước là 30/50/70 cm, ngưỡng tốc độ là 5/10/15 cm/phút. Tăng cấp cần 3 mẫu; giảm cấp cần thấp hơn ngưỡng hồi phục 5 cm trong 4 mẫu. Khi chỉnh ngưỡng trên web, cần xác nhận và mỗi mức cách nhau ít nhất 5 cm nước hoặc 1 cm/phút tốc độ. Nhật ký demo tự dọn sau 7 ngày.

## 4. Chạy trạm ESP32 thật

1. Lắp A02YYUW SEN0311, đèn/còi qua driver và nguồn đúng theo [hướng dẫn firmware](../firmware/README.md). Ghi [biên bản hiệu chuẩn](calibration-template.md) trước khi đo/đổi ngưỡng.
2. Sao chép `firmware/include/secrets.example.h` thành `firmware/include/secrets.h`, điền Wi-Fi và broker IP LAN. Credential `station-01` lấy từ `.env` **trên máy của nhóm**, không chép mật khẩu vào tài liệu.
3. Ở `firmware/`: chạy `python -m platformio test -e native`, `python -m platformio run -e esp32dev`.
4. Chip mới: chạy `python -m platformio run -e esp32dev -t uploadfs` **một lần**. Lệnh này xóa outbox cũ; không chạy lại khi còn alert chưa ACK.
5. Chạy `python -m platformio run -e esp32dev -t upload` và theo dõi `python -m platformio device monitor -b 115200`.

Trạm phải chuyển cấp và kích hoạt đầu ra cục bộ trước khi gửi MQTT. Rút Wi-Fi/broker để chứng minh vòng cảnh báo tại trạm vẫn hoạt động. Khi kết nối phục hồi, alert trong LittleFS chỉ được xóa sau ACK của backend. Rút sensor phải hiện lỗi riêng; app không được hiện NORMAL là hiện trạng. Không trình bày các kiểm tra này như đã đạt khi chưa có ESP32/sensor và biên bản thực đo.

## 5. Chạy Flutter Android

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Mặc định app dùng backend Render. `10.0.2.2` chỉ dùng cho Android emulator chạy backend local; điện thoại thật cần build với IP LAN backend trong `--dart-define=API_BASE_URL=http://<IP-LAN-MÁY-BACKEND>:3000`. URL API không thể đổi từ trong app. Để tạo APK cài thử: `flutter build apk --debug`; file tại `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

Khi mở lần đầu, app yêu cầu chọn một trong ba lưu vực; lựa chọn được lưu trên thiết bị. Bản đồ, sự kiện và thông báo lọc theo đúng một station của vùng đó. Bản đồ dùng nền OpenStreetMap với vị trí cảm biến minh họa. Màn tổng quan hiển thị số đo hiện tại và ước tính tuyến tính theo tốc độ đo gần đây ở các mốc 1, 3, 6, 12 giờ và 1 ngày; đây không phải dự báo thời tiết. Khi dữ liệu cũ quá 15 giây hoặc API lỗi, app hiển thị **Không xác định** và tách lần ghi nhận cuối khỏi hiện trạng.

Khi mức chuyển sang **Khẩn cấp**, app dùng thông báo Android ưu tiên cao, âm báo, rung và `fullScreenIntent`. Android 13+ cần cho phép thông báo; Android 14+ có thể yêu cầu người dùng bật quyền toàn màn hình trong Cài đặt ứng dụng. Cảnh báo điện thoại cần app còn được Android chạy nền và có kết nối backend; force-stop, mất mạng hoặc chính sách tiết kiệm pin có thể ngăn nhận sự kiện. Demo chưa tích hợp push notification từ cloud.

Tạo APK nhỏ theo ABI bằng `flutter build apk --release --split-per-abi`. Điện thoại phổ biến dùng ARM64: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; máy ARM 32-bit dùng `app-armeabi-v7a-release.apk`.

## 6. Kịch bản trình bày 5–7 phút

1. Chỉ trạm và nhãn THIẾT BỊ THẬT/MÔ PHỎNG, thời gian nhận, chất lượng nước.
2. Tăng nước trên jig; đối chiếu với thước và ngưỡng trong biên bản hiệu chuẩn.
3. Chờ xác nhận nhiều mẫu; chứng minh còi/đèn tại chỗ và cảnh báo trong app (đã bật quyền thông báo).
4. `docker compose stop mosquitto`; tiếp tục thay đổi mực nước, quan sát còi/đèn. App sau timeout hiện dữ liệu cũ/không xác định.
5. `docker compose start mosquitto`; quan sát outbox gửi lại, alert không nhân đôi.
6. Xem lịch sử, lý do sự kiện, trạng thái kết nối và giới hạn của prototype.

Nếu thiếu phần cứng, chuyển sang `sim-01` và nói rõ đây là mô phỏng. Không dùng kịch bản mô phỏng để tuyên bố kiểm chứng phần cứng hoặc độ chính xác ngoài thực địa.

## 7. Cổng kiểm tra trước demo

| Mục | Bằng chứng cần có |
|---|---|
| Parser/logic ESP32 | Native test pass, ESP32 build pass, đo bench/hình ảnh của trạm thật |
| Luồng dữ liệu | Migration sạch, web simulator → DB → REST/WebSocket → web/app; app người dùng chỉ đọc; MQTT/CLI simulator kiểm tra riêng |
| Cảnh báo offline | Video rút mạng với còi/đèn thật, outbox gửi lại sau phục hồi |
| App | `flutter analyze`, `flutter test`, APK debug cài/chạy trên emulator hoặc điện thoại |
| Bảo mật demo | ACL broker, credential ngoài Git, LAN riêng, app không chứa MQTT password |

Chỉ đánh dấu mục phần cứng “đạt” sau khi có linh kiện, ảnh/video và biên bản đo. Với prototype chưa kiểm chứng thực địa, không công bố là hệ thống cảnh báo an toàn cho cộng đồng.
