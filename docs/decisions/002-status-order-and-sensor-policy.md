# ADR 002: Kiểm soát thứ tự bản tin trạng thái và chính sách phát hiện lỗi cảm biến

**Ngày:** 23/09/2026
**Trạng thái:** Đề xuất; cần nhóm xác nhận tại G0/G1
**Người đề xuất:** Codex, dựa trên rà soát mã nguồn

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
  - `boot_id` là định danh ngẫu nhiên, không cho biết phiên nào mới hơn. Vì vậy status chỉ được nhận khi `boot_id` trùng `stations.latest_boot_id`, phiên đã được xác lập bởi telemetry.
  - Trong phiên hiện tại, chỉ nhận `uptime_ms` lớn hơn status đã lưu. Status bị lặp hoặc đến muộn không đổi trạng thái.
  - Status đến trước telemetry của một boot mới bị bỏ qua; firmware gửi ONLINE định kỳ nên trạng thái được nhận ở heartbeat sau khi telemetry xác lập boot. `link_state` tiếp tục có kiểm tra freshness riêng.

### 2.2. Chính sách phân định lỗi cảm biến (Sensor Fault Policy)
- **Vùng mù & ngoài dải đo:** Khung dữ liệu có giá trị $< 30\text{ mm}$ (vùng mù 3cm của A02YYUW) hoặc $> 4500\text{ mm}$ (ngoài dải 4.5m) bị coi là không hợp lệ, tăng bộ đếm `invalid_frames` và không tính vào mực nước.
- **Sai lệch Checksum hoặc byte không đồng bộ:** Loại bỏ ngay lập tức tại parser UART (`A02Parser`), chờ byte đồng bộ `0xFF` tiếp theo.
- **Mặt nước đứng yên:** Mẫu đo lặp lại cùng giá trị trong dải hợp lệ vẫn được công nhận là `VALID` và tính cấp rủi ro tương ứng. Hệ thống không tự ý gán `SUSPECT` hay `BAD` chỉ vì phương sai thấp.
- **Mất tín hiệu (Sensor Timeout):** Nếu sau thời gian `stale_ms` (mặc định 3000ms trong cấu hình demo) không có khung hợp lệ nào được nạp, trạng thái chuyển sang `risk_validity = UNKNOWN`, còi báo lũ tự động ngắt để tránh báo động giả, và đèn LED chuyển sang mẫu chớp ngắn báo lỗi phần cứng.

---

## 3. Hệ quả & Kiểm thử

- Migration runner quét và chạy các file SQL theo thứ tự tên khi gọi `npm run migrate`; chưa có kiểm thử trên PostgreSQL trong môi trường hiện tại.
- Backend unit test kiểm tra thứ tự boot/uptime bằng hàm thuần; chưa thay thế kiểm thử transaction thật với PostgreSQL/MQTT.
- Native test firmware kiểm tra frame, timeout và đầu ra; chưa phải bằng chứng bench.
- Còn phải chạy integration với broker/database để xác nhận retained status, restart, LWT và status cũ đến muộn.
