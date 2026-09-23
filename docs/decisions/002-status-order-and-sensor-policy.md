# ADR 002: Kiểm soát thứ tự bản tin trạng thái và chính sách phát hiện lỗi cảm biến

**Ngày:** 23/09/2026  
**Trạng thái:** Đã chấp thuận (Accepted)  
**Người đề xuất:** Nhóm phát triển FWA  

---

## 1. Bối cảnh

Trong quá trình rà soát hoàn thiện dự án theo `completion-audit.md`:
1. **Rủi ro bản tin status đến muộn:** Bảng `stations` trước đây chỉ lưu `last_status` và `last_status_at` mà không ghi nhận `boot_id` hay `uptime_ms`. Khi mạng có độ trễ hoặc gói tin MQTT `status` đến sai thứ tự (out-of-order), một bản tin cũ từ phiên trước hoặc từ thời điểm trước có thể ghi đè làm sai lệch trạng thái kết nối mạng (`link_state`) của trạm.
2. **Chính sách lỗi cảm biến:** Cảm biến siêu âm A02YYUW đo khoảng cách mặt nước. Trong môi trường tự nhiên (mặt hồ tĩnh, nước đọng chưa dâng), khoảng cách có thể giữ nguyên không đổi qua nhiều mẫu đo liên tiếp. Cần phân định rõ ràng giữa "mặt nước đứng yên tự nhiên" và "lỗi cảm biến / mất tín hiệu / dữ liệu rác".

---

## 2. Quyết định kỹ thuật

### 2.1. Kiểm soát thứ tự bản tin Status tại Backend
- Bổ sung 2 cột vào bảng `stations` qua migration `002_status_order.sql`:
  - `latest_status_boot_id text`: Phiên khởi động của bản tin trạng thái gần nhất.
  - `latest_status_uptime_ms bigint`: Monotonic uptime của bản tin trạng thái gần nhất trong phiên boot đó.
- Logic cập nhật trong `saveStatus(v: Status)`:
  - Khóa hàng trạm bằng `SELECT ... FOR UPDATE` để tránh race condition.
  - Chấp nhận cập nhật nếu:
    1. Bản tin thuộc phiên khởi động mới (`latest_status_boot_id IS NULL` hoặc khác `v.boot_id`).
    2. Cùng phiên khởi động và `v.uptime_ms >= latest_status_uptime_ms` (thứ tự tăng dần).
  - Từ chối/bỏ qua bản tin nếu cùng `boot_id` nhưng `v.uptime_ms < latest_status_uptime_ms` (gói tin cũ đến muộn).

### 2.2. Chính sách phân định lỗi cảm biến (Sensor Fault Policy)
- **Vùng mù & ngoài dải đo:** Khung dữ liệu có giá trị $< 30\text{ mm}$ (vùng mù 3cm của A02YYUW) hoặc $> 4500\text{ mm}$ (ngoài dải 4.5m) bị coi là không hợp lệ, tăng bộ đếm `invalid_frames` và không tính vào mực nước.
- **Sai lệch Checksum hoặc byte không đồng bộ:** Loại bỏ ngay lập tức tại parser UART (`A02Parser`), chờ byte đồng bộ `0xFF` tiếp theo.
- **Mặt nước đứng yên:** Mẫu đo lặp lại cùng giá trị trong dải hợp lệ vẫn được công nhận là `VALID` và tính cấp rủi ro tương ứng. Hệ thống không tự ý gán `SUSPECT` hay `BAD` chỉ vì phương sai thấp.
- **Mất tín hiệu (Sensor Timeout):** Nếu sau thời gian `stale_ms` (mặc định 3000ms trong cấu hình demo) không có khung hợp lệ nào được nạp, trạng thái chuyển sang `risk_validity = UNKNOWN`, còi báo lũ tự động ngắt để tránh báo động giả, và đèn LED chuyển sang mẫu chớp ngắn báo lỗi phần cứng.

---

## 3. Hệ quả & Kiểm thử

- Migration sạch tự động nạp qua `migrate.ts`.
- Bổ sung kiểm thử tự động trong `contracts.test.ts` (Backend) và `test_main.cpp` (Firmware native).
- Đóng triệt để rủi ro sai lệch trạng thái kết nối do gói tin đến muộn.
