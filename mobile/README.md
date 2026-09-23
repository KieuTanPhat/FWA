# Ứng dụng Flutter Android

Ứng dụng Android tải telemetry, lịch sử và alert qua REST/WebSocket. Người dùng phải chọn một trong ba vùng trước khi vào app; số liệu và thông báo trong app chỉ theo station của vùng đó. Các nút trên tab Bản đồ chỉ điều khiển station mô phỏng trên backend, không gửi lệnh tới ESP32 vật lý. Còi/đèn phần cứng vẫn do firmware tại trạm quyết định.

## Chạy và cài APK demo

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` dùng **chỉ cho Android emulator**. Điện thoại thật phải dùng IP LAN của máy chạy backend, ví dụ `--dart-define=API_BASE_URL=http://192.168.1.10:3000`. Backend cần lắng nghe trên IP LAN và firewall cho phép cổng 3000 trong mạng demo riêng. Không dùng `localhost` trên điện thoại để trỏ tới laptop.

Tạo APK Android để cài trên emulator hoặc điện thoại:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://<IP-LAN>:3000
```

File sinh tại `build/app/outputs/flutter-apk/app-debug.apk`. URL trong `API_BASE_URL` là giá trị mặc định; có thể đổi và lưu địa chỉ backend ngay trong app bằng nút cài đặt ở thanh trên. Bản debug cho phép HTTP trong LAN demo. Bản release chỉ nhận HTTPS và cần cấu hình khóa ký riêng trước khi phát hành.

Tạo APK release gọn theo kiến trúc:

```powershell
flutter build apk --release --split-per-abi
```

Máy Android ARM64 dùng `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; máy ARM 32-bit dùng `app-armeabi-v7a-release.apk`.

## Quy tắc hiển thị

- `SIMULATED` luôn có nhãn **MÔ PHỎNG** ở trang trạm/sự kiện.
- Khi dữ liệu quá 15 giây hoặc không tới API, mức hiện tại là **Không xác định**; cấp cũ và số đo cũ chỉ ghi là “lần ghi nhận cuối”.
- Chất lượng nước, trạng thái liên kết và độ mới là các nhãn tách biệt.
- Mất WebSocket thì REST vẫn tải lại theo chu kỳ; thông tin kết nối có ở tab **Kết nối**.
- Cảnh báo mới của vùng đang chọn hiện trong app khi app đang mở; lịch sử alert nằm ở tab **Sự kiện**.
- Thông báo hệ điều hành ở nền/màn hình khóa chưa được cấu hình. Không hứa gửi cảnh báo khi app tắt hoặc trạm mất uplink; còi/đèn tại trạm vẫn là vòng cảnh báo cốt lõi.
- Không hứa gửi cảnh báo tới điện thoại khi trạm mất uplink. Còi/đèn tại trạm vẫn là vòng cảnh báo cốt lõi.

## Yêu cầu cảnh báo khẩn cấp (Full-screen & Haptic Alert)

Khi mực nước đạt ngưỡng **Khẩn cấp (EMERGENCY)**, ứng dụng cần thực hiện quy trình cảnh báo đặc biệt để đảm bảo người dùng nhận biết ngay lập tức:

### 1. Hiển thị cảnh báo toàn màn hình (Full-Screen Overlay Dialog)
- **Kích hoạt (Trigger)**: Khi nhận dữ liệu WebSocket hoặc cập nhật REST có trạng thái chuyển cấp sang `EMERGENCY`.
- **Giao diện**:
  - Phủ toàn màn hình với tông màu báo động khẩn cấp (Đỏ `#B22632`).
  - Biểu tượng cảnh báo nguy hiểm kích thước lớn, tiêu đề chữ đậm: **CẢNH BÁO LŨ KHẨN CẤP**.
  - Hiển thị rõ: **Tên trạm**, **Mực nước hiện tại (cm)**, **Thời điểm đo** và nhãn nguồn dữ liệu (**THIẾT BỊ THẬT** hoặc **MÔ PHỎNG**).
  - Khuyến nghị an toàn: Yêu cầu người dân sơ tán khẩn cấp lên vùng cao an toàn.
  - Nút bấm xác nhận: **"ĐÃ TIẾP NHẬN / TẮT BÁO ĐỘNG"** để người dùng tắt rung và đóng màn hình khẩn cấp.

### 2. Cơ chế Rung phản hồi (Haptic Vibration)
- **Quyền Android**: Bổ sung quyền `<uses-permission android:name="android.permission.VIBRATE" />` trong `AndroidManifest.xml`.
- **Mẫu rung (Vibration Pattern)**: Rung ngắt quãng dồn dập cảnh báo khẩn cấp (Ví dụ: Rung 500ms - Nghỉ 200ms - Rung 500ms - Nghỉ 500ms) lặp lại liên tục cho đến khi người dùng bấm xác nhận tiếp nhận cảnh báo hoặc sau thời gian timeout (tối đa 60 giây).
- **Âm thanh (Tùy chọn nâng cao)**: Phát chuông cảnh báo âm lượng tối đa theo kênh thông báo ưu tiên cao (`Alarm/Notification Stream`).

### 3. Cảnh báo khi màn hình tắt / Ứng dụng chạy nền (Background Notification)
- Sử dụng Android Notification Channel mức ưu tiên cao nhất (`Importance.max` / `Priority.high`).
- Cấu hình `fullScreenIntent` để tự động bật sáng màn hình và hiển thị pop-up cảnh báo ngay trên màn hình khóa điện thoại.

## Bản đồ demo và điều khiển cảm biến mô phỏng

### Vùng đang hỗ trợ

- `sim-01`: Thao–Chảy · Yên Bái/Lào Cai.
- `sim-02`: Hương–Bồ · Huế.
- `sim-03`: Vu Gia–Thu Bồn · Đà Nẵng/Quảng Nam cũ.

Mỗi vùng hiện có đúng một sensor mô phỏng. Người dùng chọn vùng lần đầu; lựa chọn lưu trong `SharedPreferences`. Tab Bản đồ hiển thị một marker OpenStreetMap và số liệu mới nhất từ backend. Slider mực nước, nút ghi nhịp mưa, nước dâng/hạ và đặt lại gọi chung API với web IoT; mọi thay đổi được lưu thành telemetry.

Các tọa độ chỉ là pin tham khảo. Số đo, nhiệt độ, mưa và cảnh báo do server simulator tạo theo sơ đồ trong `backend/public/diagram.json`; đây không phải cảm biến lắp tại các địa điểm đó hoặc dữ liệu quan trắc thực tế.