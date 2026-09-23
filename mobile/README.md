# Ứng dụng Flutter Android

Ứng dụng chỉ đọc dữ liệu của hệ thống IoT. Còi/đèn và cấp cảnh báo được quyết định trên ESP32. App tải REST và nhận sự kiện WebSocket từ backend; không có credential MQTT hay lệnh điều khiển trạm.

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

## Quy tắc hiển thị

- `SIMULATED` luôn có nhãn **MÔ PHỎNG** ở trang trạm/sự kiện.
- Khi dữ liệu quá 15 giây hoặc không tới API, mức hiện tại là **Không xác định**; cấp cũ và số đo cũ chỉ ghi là “lần ghi nhận cuối”.
- Chất lượng nước, trạng thái liên kết và độ mới là các nhãn tách biệt.
- Mất WebSocket thì REST vẫn tải lại theo chu kỳ; thông tin kết nối có ở tab **Kết nối**.
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

## Yêu cầu Bản đồ cảnh báo lũ & Phân vùng người dùng (GIS Map & Zones)

Xem chi tiết đầy đủ tại tài liệu kiến trúc [docs/map-and-zone-spec.md](../docs/map-and-zone-spec.md).

### 1. Phân vùng người dùng (Zone Onboarding)
- Ứng dụng giới hạn phục vụ theo từng tiểu vùng địa lý trọng điểm có nguy cơ ngập lụt thực tế (ví dụ: các xã/phường thuộc lưu vực sông Vu Gia – Thu Bồn).
- Người dùng khi khởi động ứng dụng lần đầu bắt buộc phải chọn **Khu vực sinh sống / Khu vực quan sát** (lưu vào `SharedPreferences`).
- Bộ lọc thông báo chỉ kích hoạt **Rung dồn dập & Pop-up toàn màn hình khẩn cấp** đối với các trạm thuộc hoặc ảnh hưởng trực tiếp đến khu vực người dùng đã chọn.

### 2. Bản đồ số GIS & Bố trí cảm biến thực tế
- Tích hợp bản đồ OpenStreetMap qua thư viện `flutter_map` (không tốn phí API key).
- Hiển thị các Marker trạm quan trắc với màu sắc tương ứng mức rủi ro thời gian thực (Xanh, Vàng, Cam, Đỏ, Xám).
- **Quy tắc bố trí cảm biến thực tế (Không đặt phi lý)**:
  - Cảm biến siêu âm A02YYUW bắt buộc gắn vuông góc hướng xuống mặt nước trên các kết cấu kiên cố: **Dầm cầu vượt sông**, **Cửa cống hộp ngăn triều / xả lũ**, hoặc **Kè đập tràn bê tông**.
  - Tuyệt đối không đặt cảm biến trên ngọn cây, trong nhà dân hay giữa mặt đường nhựa.
  - Các trạm mô phỏng (`sim-01`, `sim-02`...) được gắn tọa độ GPS tại các điểm xung yếu thủy văn thật ở thượng lưu và cửa sông để mô phỏng dòng chảy lũ dâng thực tế.


