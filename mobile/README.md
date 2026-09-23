# Ứng dụng Flutter Android

Ứng dụng Android chỉ đọc số đo, lịch sử và cảnh báo qua REST/WebSocket. Người dùng phải chọn một trong ba vùng trước khi vào app; nội dung chỉ theo cảm biến mô phỏng của vùng đó. App không có chức năng điều chỉnh số đo hoặc ngưỡng. Chỉ bàn điều khiển web IoT mới ghi thay đổi về backend.

## Chạy và cài APK demo

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

App dùng Render làm địa chỉ mặc định. Muốn chạy với backend local trên **Android emulator**, dùng `--dart-define=API_BASE_URL=http://10.0.2.2:3000`. Điện thoại thật trong mạng demo riêng có thể build với `--dart-define=API_BASE_URL=http://<IP-LAN-MÁY-BACKEND>:3000`; backend phải lắng nghe trên IP LAN. Không dùng `localhost` trên điện thoại để trỏ tới laptop.

Tạo APK Android để cài trên emulator hoặc điện thoại:

```powershell
flutter build apk --debug
```

File sinh tại `build/app/outputs/flutter-apk/app-debug.apk`. URL API chỉ cấu hình lúc build; người dùng không thể đổi URL trong app. Bản debug cho phép HTTP trong LAN demo.

Tạo APK release gọn theo kiến trúc:

```powershell
flutter build apk --release --split-per-abi
```

Máy Android ARM64 dùng `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; máy ARM 32-bit dùng `app-armeabi-v7a-release.apk`. Release hiện dùng khóa debug của dự án để cài demo; cần khóa ký phát hành riêng trước khi đưa lên Google Play.

## Quy tắc hiển thị

- `SIMULATED` luôn có nhãn **MÔ PHỎNG** ở trang trạm/sự kiện.
- Khi dữ liệu quá 15 giây hoặc không tới API, mức hiện tại là **Không xác định**; cấp cũ và số đo cũ chỉ ghi là “lần ghi nhận cuối”.
- Chất lượng nước, trạng thái kết nối và độ mới là các nhãn riêng.
- Mất WebSocket thì REST vẫn tải lại theo chu kỳ; nhật ký alert nằm ở tab **Sự kiện**.
- App hiển thị mực nước hiện tại và ước tính tuyến tính theo tốc độ đo gần đây tại các mốc 1, 3, 6, 12 giờ và 1 ngày; đây không phải dự báo thời tiết.
- Mức cảnh báo có bốn trạng thái: **Bình thường**, **Theo dõi**, **Cảnh báo**, **Khẩn cấp**.

## Cảnh báo khẩn cấp

Khi vùng đã chọn chuyển sang **Khẩn cấp (EMERGENCY)**, app mở màn hình cảnh báo và phát một thông báo Android ưu tiên cao với rung/âm báo. Màn hình có khu vực, trạm, mực nước gần nhất, thời điểm ghi nhận và nút **Đã nhận cảnh báo**.

### Khi màn hình khóa
- Android Notification Channel dùng mức ưu tiên cao, âm báo động và mẫu rung. `fullScreenIntent` yêu cầu Activity hiển thị trên màn hình khóa và bật sáng màn hình.
- Android 13+ cần người dùng cho phép thông báo. Android 14+ có thể cần bật thêm quyền thông báo toàn màn hình trong Cài đặt ứng dụng; nếu quyền không được cấp, Android có thể chỉ hiện thông báo thường.
- Cảnh báo điện thoại cần app còn được Android chạy nền và có kết nối tới backend. Force-stop, mất mạng hoặc chính sách tiết kiệm pin có thể ngăn app nhận sự kiện; demo chưa tích hợp push notification từ cloud.

## Bản đồ và số đo mô phỏng

### Vùng đang hỗ trợ

- `sim-01`: Thao–Chảy · Yên Bái/Lào Cai.
- `sim-02`: Hương–Bồ · Huế.
- `sim-03`: Vu Gia–Thu Bồn · Đà Nẵng/Quảng Nam cũ.

Mỗi vùng hiện có đúng một cảm biến mô phỏng. Người dùng chọn vùng lần đầu; lựa chọn lưu trong `SharedPreferences`. Tab Bản đồ dùng nền OpenStreetMap, marker minh họa và số đo mới nhất. App chỉ đọc; slider và nút đổi số đo/ghi nhịp mưa chỉ có trên web IoT.

Các tọa độ chỉ là pin tham khảo. Số đo, nhiệt độ, mưa và cảnh báo do server simulator tạo theo sơ đồ trong `backend/public/diagram.json`; đây không phải cảm biến lắp tại các địa điểm đó hoặc dữ liệu quan trắc thực tế.
