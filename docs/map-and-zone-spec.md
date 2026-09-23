# Bản đồ cảnh báo lũ & Phân vùng người dùng

> **Cập nhật 2026-09:** Đã triển khai tab bản đồ demo trong ứng dụng Flutter theo yêu cầu môn học IoT. Demo hiện có ba lựa chọn lưu vực (Thao–Chảy, Hương–Bồ, Vu Gia–Thu Bồn), các pin tham khảo, số đo giả lập, ngưỡng 30/50/70 cm và thông báo trong ứng dụng. Giá trị và tọa độ không đến từ cảm biến thật; không dùng để lắp đặt, điều hướng hoặc phát cảnh báo ngoài thực địa. Phần dưới đây giữ lại đề xuất mở rộng sản phẩm sau PoC; các yêu cầu mở rộng đó chưa được triển khai.

Các vị trí trong tài liệu này chỉ là ví dụ minh họa, chưa được khảo sát hoặc xác nhận với đơn vị địa phương và không phải căn cứ kỹ thuật/địa lý để lắp đặt.

---

## 1. Cơ chế Chọn khu vực sinh sống (Zone / Area Onboarding)

### 1.1. Phạm vi phục vụ giới hạn
Ứng dụng FWA phục vụ người dân tại các **vùng trọng điểm ngập lụt / lưu vực sông thí điểm**, không triển khai tràn lan thiếu chính xác.
* **Khu vực thí điểm mẫu**: Lưu vực sông Vu Gia – Thu Bồn & vùng ngập trũng hạ du (TP. Đà Nẵng & Bắc Quảng Nam), chia thành các tiểu vùng:
  - **Vùng 1 (Hòa Vang – Thượng lưu/Vùng trũng lũ quét)**: Xã Hòa Nhơn, Hòa Khương, Hòa Phong.
  - **Vùng 2 (Cẩm Lệ – Trung lưu ngập sâu ven sông Cẩm Lệ)**: Phường Hòa Thọ Đông, Hòa Xuân.
  - **Vùng 3 (Hội An – Hạ lưu cửa sông triều cường & ngập phố cổ)**: Phường Minh An, Cẩm Kim.

### 1.2. Luồng chọn khu vực của người dùng
1. **Khởi chạy lần đầu (First Launch)**:
   - Hiển thị màn hình chọn **Khu vực sinh sống / Khu vực quan tâm**.
   - Người dùng bắt buộc phải chọn 1 tiểu vùng trong danh sách hỗ trợ để tiếp tục vào trang chính.
2. **Lưu trữ cục bộ**: Lưu mã vùng đã chọn (`selected_zone_id`) vào `SharedPreferences`.
3. **Thay đổi khu vực**: Người dùng có thể đổi lại khu vực sinh sống bất kỳ lúc nào tại thanh tiêu đề hoặc mục **Cài đặt**.
4. **Bộ lọc cảnh báo khẩn cấp (Emergency Alert Filter)**:
   - Chỉ kích hoạt **Rung dồn dập** và **Pop-up toàn màn hình khẩn cấp** đối với các trạm quan trắc nằm trong hoặc trực tiếp ảnh hưởng đến tiểu vùng người dùng đã chọn.
   - Tránh tình trạng "báo động quá tải" (alert fatigue) khi khu vực khác có lũ nhưng nơi người dùng ở vẫn an toàn.

---

## 2. Đặc tả Bản đồ giám sát ngập lũ (GIS / Interactive Map)

### 2.1. Nền tảng bản đồ
* Tích hợp bản đồ nền Vector/Raster thông qua thư viện mã nguồn mở `flutter_map` (dựa trên OpenStreetMap), không phụ thuộc vào API key trả phí của bên thứ ba.
* Hỗ trợ phóng to, thu nhỏ, xoay và hiển thị ranh giới hành chính/lưu vực của các tiểu vùng.

### 2.2. Trực quan hóa Marker trạm quan trắc
Mỗi trạm trên bản đồ được biểu diễn bằng một Marker tương tác:
* **Màu sắc Marker phản ánh mức rủi ro thời gian thực**:
  - 🟢 **Xanh lá (`#07845C`)**: BÌNH THƯỜNG (NORMAL)
  - 🟡 **Vàng đậm (`#C07400`)**: THEO DÕI (WATCH)
  - 🟠 **Cam (`#D4541C`)**: CẢNH BÁO (WARNING)
  - 🔴 **Đỏ (`#B22632`)**: KHẨN CẤP (EMERGENCY) — Có hiệu ứng vòng sóng xung (pulse animation) lan tỏa trên bản đồ.
  - ⚪ **Xám (`#667785`)**: MẤT KẾT NỐI / LỖI CẢM BIẾN (FAULT / UNKNOWN).
* **Phân định rõ nguồn dữ liệu**:
  - Trạm thật có icon vi mạch (`Icons.memory`).
  - Trạm mô phỏng có icon phòng lab (`Icons.science_outlined`) kèm nhãn cam nổi bật **MÔ PHỎNG**.

### 2.3. Tương tác trên bản đồ
* Khi người dùng nhấn vào một Marker:
  - Hiển thị thanh trượt phía dưới (**Modal Bottom Sheet**) tóm tắt: Tên trạm, Vị trí thực tế, Mực nước hiện tại (cm), Trạng thái rủi ro, Thời gian cập nhật gần nhất.
  - Nút bấm **"Xem chi tiết trạm"**: Điều hướng ngay đến tab **Lịch sử** và **Sự kiện** của trạm đó.

---

## 3. Quy tắc bố trí cảm biến ngoài thực địa (Hiện thực & Khoa học)

### 3.1. Ràng buộc vật lý của cảm biến siêu âm A02YYUW
* **Dải đo hữu dụng**: 30 cm – 450 cm (0.3m – 4.5m). Dưới 30 cm rơi vào vùng mù (blind zone); trên 4.5m sóng âm suy hao không phản hồi được.
* **Nguyên lý đo khoảng cách**: Cảm biến đo khoảng cách $d$ từ mắt phát đến mặt nước. Mực nước sông $H = H_0 - d$ (với $H_0$ là độ cao tĩnh không từ cảm biến đến đáy lòng sông/kênh).
* **Bắt buộc có giá đỡ kiên cố**: Cảm biến phải được gắn cố định hướng thẳng đứng vuông góc 90° xuống mặt nước, tránh rác trôi cuốn trôi và không bị rung lắc do gió.

### 3.2. Bố trí hợp lý tại các vị trí xung yếu thực tế (Realistic Placement)

Tuyệt đối **KHÔNG** đặt cảm biến ở những nơi phi lý (như mặt đường nhựa, ngọn cây, trong nhà). Cảm biến chỉ được bố trí tại 3 dạng vị trí thủy văn chuẩn:

| Mã trạm | Tên vị trí thực địa | Tọa độ GPS mẫu | Vùng quản lý | Kết cấu lắp đặt thực tế | Mục đích cảnh báo |
|---|---|---|---|---|---|
| `station-01` | **Cầu Cẩm Lệ (Dầm biên nhịp giữa)** | `15.9984, 108.2045` | Cẩm Lệ | Gắn dưới dầm thép/bê tông cầu, cách mặt nước bình thường $H_0 = 380\text{ cm}$. Hướng vuông góc lòng sông. | Đo mực nước sông Cẩm Lệ dâng, cảnh báo ngập khu dân cư ven sông Hòa Thọ Đông. |
| `sim-01` | **Cầu Đỏ (Thượng lưu trạm bơm)** | `15.9902, 108.1963` | Hòa Vang | Gắn dưới gầm cầu vượt sông Cầu Đỏ, $H_0 = 420\text{ cm}$. | Mô phỏng đón lũ từ thượng nguồn sông Vu Gia đổ về trung tâm thành phố. |
| `sim-02` | **Cửa cống ngăn triều Hòa Xuân** | `16.0125, 108.2180` | Cẩm Lệ | Gắn trên thanh giằng bê tông cửa xả cống hộp thoát nước, $H_0 = 250\text{ cm}$. | Đo nước dâng ngược từ sông vào hệ thống thoát nước đô thị khi triều cường. |
| `sim-03` | **Kè đập tràn thôn Túy Loan** | `15.9721, 108.1325` | Hòa Vang | Trụ thép quan trắc đúc bê tông neo bờ kè, $H_0 = 300\text{ cm}$. | Cảnh báo lũ quét cục bộ tràn qua đập tràn cắt đứt giao thông nông thôn. |

```text
Sơ đồ lắp đặt cảm biến siêu âm A02YYUW tại dầm cầu:

       ┌───────────────────────────────┐  <- Dầm cầu bê tông / Giá đỡ cố định
       │   [ESP32 Box] + [Driver/Pin]  │
       └──────────────┬────────────────┘
                      │ Dây tín hiệu UART
               ┌──────┴──────┐
               │   A02YYUW   │  <- Cao độ lắp đặt H0 (ví dụ: 380 cm)
               └──────┬──────┘
                   │  ▲
        Sóng âm    ▼  │ Khoảng cách d (30 - 450 cm)
      ═════════════════════════════════ <- MẶT NƯỚC SÔNG LŨ (Mực nước H = H0 - d)

      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ───────────────────────────────── <- Đáy sông / Lòng dẫn
```

---

## 4. Kế hoạch điều chỉnh Schema & Backend API

Để phục vụ bản đồ và phân vùng, các bản cập nhật tiếp theo cần mở rộng:
1. **Bảng `stations` trong PostgreSQL**:
   ```sql
   ALTER TABLE stations ADD COLUMN zone_id text NOT NULL DEFAULT 'zone-camle';
   ALTER TABLE stations ADD COLUMN latitude double precision;
   ALTER TABLE stations ADD COLUMN longitude double precision;
   ALTER TABLE stations ADD COLUMN installation_type text; -- 'BRIDGE_GIRDER', 'CULVERT', 'RIVER_EMBANKMENT'
   ALTER TABLE stations ADD COLUMN sensor_height_h0_cm double precision;
   ```
2. **API `GET /stations`**:
   - Bổ sung `zone_id`, `latitude`, `longitude`, `installation_type`.
   - Cho phép query lọc theo vùng: `GET /stations?zone_id=zone-camle`.
