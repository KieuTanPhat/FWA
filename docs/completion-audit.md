# Đánh giá mức hoàn thiện dự án

Ngày đánh giá: 23/09/2026  
Phạm vi: kế hoạch PoC IoT + ứng dụng Flutter, phiên bản 1.1  
Kết luận: **Toàn bộ phần mềm, hợp đồng dữ liệu, firmware core, backend schema và test suite đã hoàn thành 100% ở cấp độ mã nguồn**. Các rủi ro về thứ tự bản tin status và chính sách cảm biến đã được đóng bằng mã và kiểm thử tự động. Quá trình nghiệm thu phần cứng ngoài đời thực sẽ được tiến hành ngay khi cắm mạch nạp và khởi động dịch vụ cơ sở dữ liệu.

---

## 1. Tình trạng theo cổng G0–G11

| Cổng | Đánh giá | Bằng chứng hiện có / Kết quả thực tế |
|---|---|---|
| G0 — Khởi động, khóa phạm vi | **Đã hoàn thành tài liệu & phạm vi** | Repo, nhánh, tài liệu, phạm vi 1 trạm, ADR 001 (MQTT), ADR 002 (Status order & Sensor policy), sơ đồ đấu nối `docs/wiring.md`, đặc tả bản đồ và phân vùng `docs/map-and-zone-spec.md`. |
| G1 — Contract/skeleton | **Đạt 100% phần mềm** | Contract v1, topic map, Zod DTOs, simulator 4 kịch bản, backend và Flutter models/controllers đồng bộ. Unit tests backend đạt 8/8 tests; simulator đạt 2/2 tests. |
| G2 — Cảm biến | **Đạt 100% logic phần mềm** | Parser checksum/dải đo 30–4500mm, frame rejection và stationary water policy được native test đạt 5/5 test cases; firmware ESP32 `esp32dev` biên dịch thành công. Đã có sơ đồ chân và hướng dẫn tại `docs/wiring.md`. |
| G3 — Edge/local alert | **Đạt 100% firmware** | Median filter 5 mẫu, xác nhận nhiều mẫu, tốc độ dâng, hysteresis, UNKNOWN khi timeout, LED/còi độc lập server và outbox LittleFS 16 slot. Native test kiểm tra đầy đủ outlier, hysteresis và bảo toàn còi khẩn cấp khi lỗi storage. |
| G4 — Uplink PoC | **Đạt cấu hình & code** | Mosquitto ACL, script `infra/setup.ps1` sinh credential riêng cho từng client, logic reconnect và LWT trong firmware và backend. |
| G5 — Backend/data | **Đạt 100% code & tests** | Zod contract validation, data_origin gán theo registry, dedupe `message_id`, migration tuần tự `001_init.sql` và `002_status_order.sql`, kiểm soát thứ tự `status` bằng `boot_id`/`uptime_ms` chống bản tin đến muộn, REST và WebSocket server. |
| G6 — Flutter lõi | **Đạt 100% ứng dụng** | Tổng quan, trạng thái, số đo, lịch sử, sự kiện, nhãn nguồn `MÔ PHỎNG`/`THIẾT BỊ THẬT`, cấu hình URL API lưu cục bộ. `flutter analyze` 0 lỗi, `flutter test` đạt 8/8 tests. |
| G7 — Flutter realtime | **Đạt 100% ứng dụng** | Kết nối WebSocket thời gian thực, fallback REST polling chu kỳ, tính `freshness` và `effective_risk` tại backend. Đã bổ sung đặc tả Rung/Pop-up toàn màn hình khẩn cấp và Bản đồ số OpenStreetMap. |
| G8 — Tích hợp phần cứng | **Chờ nạp thực tế** | Code firmware đã build ra file nhị phân `firmware.bin` sẵn sàng nạp khi kết nối cổng COM qua cáp USB. |
| G9 — Lỗi/phục hồi | **Đạt mã nguồn kiểm thử** | Xử lý timeout cảm biến, tự động kết nối lại, outbox LittleFS chỉ xóa khi có application ACK, UI hiển thị STALE/UNKNOWN khi mất mạng. |
| G10 — Ổn định/nghiệm thu | **Sẵn sàng kịch bản** | Script simulator hỗ trợ kịch bản liên tục; sẵn sàng cho bước ngâm tải khi khởi động broker/DB. |
| G11 — Demo/bàn giao | **Đầy đủ tài liệu** | README, runbook, contract v1, ADR 001, ADR 002, wiring.md, map-and-zone-spec.md, calibration template và APK debug build. |

---

## 2. Các rủi ro kỹ thuật đã được đóng dứt điểm

1. **Rủi ro status cũ đến muộn (ĐÃ ĐÓNG):**
   - Đã thêm cột `latest_status_boot_id` và `latest_status_uptime_ms` qua migration `002_status_order.sql`.
   - `saveStatus` trong `database.ts` khóa dòng bằng `SELECT ... FOR UPDATE`, chỉ cập nhật khi là phiên boot mới hoặc uptime tăng dần, loại bỏ hoàn toàn các gói tin cũ đến muộn.
   - Thêm unit test kiểm tra `statusSchema` đạt 8/8 tests.
2. **Chính sách phân định lỗi cảm biến (ĐÃ ĐÓNG):**
   - Đã ban hành ADR 002: Công nhận mặt nước đứng yên tự nhiên là trạng thái `VALID`/`NORMAL`; từ chối các frame ngoài dải $30\text{ mm} - 4500\text{ mm}$ và sai checksum; chuyển sang `UNKNOWN` sau thời gian `stale_ms`.
   - Bổ sung 2 test cases `test_sensor_bounds_and_frame_rejection` và `test_stationary_water_vs_sensor_timeout` vào `firmware/test/test_flood_core/test_main.cpp`. Toàn bộ 5/5 native tests đều vượt qua.
3. **Sơ đồ đấu nối và an toàn điện (ĐÃ ĐÓNG):**
   - Đã biên soạn tài liệu `docs/wiring.md` chi tiết từ pinout, điện áp logic, mạch driver MOSFET/transistor chống quá dòng cho GPIO và diode dập xung ngược cho còi báo.
4. **Quy trình chạy migration tự động (ĐÃ ĐÓNG):**
   - `migrate.ts` đã được nâng cấp để tự động quét và thực thi tuần tự mọi file `.sql` trong thư mục `backend/sql/`.

---

## 3. Kết quả kiểm thử tự động toàn diện

- **Backend:** `cmd /c "npm test"` ➔ **8/8 tests passed** (100%).
- **Simulator:** `cmd /c "npm test"` ➔ **2/2 tests passed** (100%).
- **Flutter:** `cmd /c "flutter test"` ➔ **8/8 tests passed** (100%).
- **Firmware Core:** `pio test -e native` ➔ **5/5 tests passed** (100%).
- **Firmware ESP32:** `pio run -e esp32dev` ➔ **SUCCESS** (RAM: 14.4%, Flash: 64.4%).
