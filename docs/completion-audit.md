# Đánh giá mức hoàn thiện dự án

Ngày rà soát: 23/09/2026
Nhánh: `feat/ung-dung-flutter-theo-doi`
Phạm vi: PoC một trạm ESP32, cảnh báo tại chỗ, backend/MQTT, simulator và Flutter Android theo kế hoạch dự án.

## Kết luận

**Chưa hoàn thành 100% và chưa đủ điều kiện nghiệm thu PoC.** Các thành phần mã chính đã build và có unit/widget test. Chưa có bằng chứng chạy chuỗi broker–database–API–app; chưa nạp hoặc đo trên ESP32/A02YYUW thật; các cổng hiệu chuẩn, chạy offline, soak và rehearsal còn mở.

Không gắn nhãn `SIMULATOR VERIFIED`, `BENCH VERIFIED` hoặc `FIELD VERIFIED` cho đến khi có đúng bằng chứng tương ứng. Build firmware không chứng minh hoạt động của còi, đèn hay cảm biến ngoài đời.

## 1. Trạng thái theo cổng G0–G11

| Cổng | Trạng thái | Đã làm | Còn thiếu để đóng |
|---|---|---|---|
| G0 — Khởi động và khóa phạm vi | **Mở** | Kế hoạch, contract, ADR MQTT, sơ đồ đấu nối dự thảo và giới hạn P0 đã có. | Xác nhận model/serial linh kiện thực tế; BOM, chi phí/lead time, owner/backup, lịch và tiêu chí đo được do nhóm duyệt. ADR 002 và pinout chưa có phê duyệt/xác minh bench. |
| G1 — Contract/skeleton | **Mã và test riêng đạt; tích hợp chưa chạy** | Contract v1, MQTT topics, backend, simulator và app có. Backend 8 test; simulator 2 test. | Chạy fixture qua broker và PostgreSQL; xác nhận migration sạch, origin, dedupe, status và ACK trên DB thật. |
| G2 — Cảm biến | **Chưa đạt bench** | Parser UART/checksum, dải đo và policy timeout có native test; firmware ESP32 build được. | Raw log từ đúng A02YYUW; xác minh nguồn/mức logic; jig và ba mức × 30 mẫu theo ngưỡng sai số đã duyệt. |
| G3 — Edge/local alert | **Logic có; đầu ra thật chưa thử** | State machine, median/outlier, xác nhận/hysteresis, UNKNOWN, LED/còi và outbox có. Native test firmware 5/5. | Nạp ESP32; đo thời gian phản ứng và đầu ra; xác minh local alert khi broker/server mất. |
| G4 — Uplink PoC | **Cấu hình/code có; chưa xác minh chạy** | Mosquitto ACL, credential riêng, MQTT reconnect/LWT và simulator có. | Bật broker thật; thử ACL từng client, reconnect, LWT và mất uplink. |
| G5 — Backend/data | **Unit/build đạt; tích hợp DB chưa xác minh** | Contract validation, registry, dedupe, migration, REST/WebSocket và kiểm tra status theo boot/uptime có. | Chạy migration trên PostgreSQL sạch; test transaction, status retained/cross-boot, lỗi DB không ACK và luồng MQTT thật. |
| G6 — Flutter lõi | **Đạt mức app trên emulator** | Tổng quan, chi tiết, lịch sử, sự kiện, nhãn nguồn, trạng thái stale/offline và cài đặt URL API. Analyze sạch, 8 widget/model/controller test đạt; APK debug build được. | Cài lên điện thoại đích, truy cập backend qua LAN và xác nhận giao diện với dữ liệu tích hợp. |
| G7 — Flutter realtime/demo | **Mã có; đầu-cuối chưa chạy** | WebSocket, REST polling/reconnect, phân biệt mô phỏng/thật và dữ liệu cũ. | Simulator/backend/database/app phải chạy cùng lúc; xác nhận reconnect và bù sự kiện trên app. |
| G8 — Tích hợp phần cứng | **Chưa đạt** | Firmware biên dịch với cấu hình `esp32dev`. | Kết nối đúng bo/cảm biến/driver, nạp firmware, so số đo và lưu ảnh/video/log của bench. |
| G9 — Lỗi/phục hồi | **Chưa nghiệm thu** | Có code/test cho lỗi frame, timeout, outbox, stale UI và giữ còi khẩn cấp khi storage fault. | Thử rút cảm biến/Wi-Fi/broker, reboot offline, replay/ACK, duplicate và outbox đầy trên hệ thống đang chạy. |
| G10 — Ổn định/nghiệm thu | **Chưa làm** | Có runbook và danh sách phép thử. | Soak mục tiêu 24 giờ, p50/p95 tối thiểu 30 event, backup/restore DB, rà soát bảo mật và biên bản đóng P0. |
| G11 — Demo/bàn giao | **Một phần** | README, runbook, contract, ảnh app và biên bản audit có. | Rehearsal 5–7 phút; APK/hash gắn đúng commit; tag phát hành sau review/merge; backlog và known limitations có owner. |

## 2. Rà soát kỹ thuật theo thành phần

### Firmware và phần cứng

- **Đã có:** đọc frame A02YYUW qua UART; checksum/dải đo; chuyển khoảng cách thành mực nước theo `H0`; lọc; tốc độ dâng; state machine có xác nhận/hysteresis; timeout thành UNKNOWN; còi/đèn cục bộ; alert outbox LittleFS và application ACK.
- **Đã xác minh bằng phần mềm:** 5 native test và build `esp32dev` đạt. Firmware dùng 14.4% RAM và 64.4% app flash slot trong build hiện tại.
- **Chưa xác minh:** model/serial/pinout/nguồn của linh kiện thực mua; mức điện áp UART; mạch driver theo dòng tải cụ thể; đo H0; cường độ đèn/còi và phản ứng ≤1 giây; mất Wi-Fi, reboot offline, ACK/replay, đầy outbox và brownout.
- **Giới hạn policy:** mặt nước đứng yên trong dải hợp lệ vẫn được coi là mẫu hợp lệ; timeout cảm biến cho UNKNOWN và tắt còi lũ. Đây là policy dự thảo trong ADR 002, cần nhóm xác nhận trước khi nghiệm thu.
- **Chưa đo nguồn:** `battery_v` vẫn null; tipping bucket và DS18B20 chưa bật trong firmware. Không đưa các số này thành dữ liệu đo thật.

### Backend, MQTT và PostgreSQL

- **Đã có:** NestJS, Zod contract, gán `data_origin` theo registry, chống trùng telemetry/alert, chỉ cập nhật latest theo thứ tự telemetry, REST/WebSocket và SQL migration.
- **Đã sửa trong đợt rà soát:** `boot_id` là định danh opaque, không thể so sánh “mới hơn/cũ hơn”. Backend chỉ nhận status khớp boot đã xác lập bởi telemetry và chỉ tăng uptime trong boot đó; status bị từ chối không phát sự kiện WebSocket. Unit test kiểm tra comparator.
- **Giới hạn còn lại:** test comparator chưa thay thế transaction test với PostgreSQL. Status ONLINE trước telemetry của boot mới có thể bị bỏ qua; heartbeat tiếp theo sau telemetry mới được nhận. Phải kiểm tra hành vi này trong integration.
- **Migration:** `npm run migrate` quét và chạy SQL theo thứ tự tên. Các migration hiện tại idempotent; chưa có bảng theo dõi migration đã áp dụng và chưa xác minh với PostgreSQL sạch/nâng cấp từ DB cũ.
- **Vận hành:** demo chỉ trong LAN tin cậy; chưa có TLS/xác thực người dùng cho Internet. Không port-forward hay public expose.

### Simulator và Flutter

- **Simulator:** có `normal`, `rise`, `fault`, `full`; test scenario đạt 2/2. Chưa chạy qua broker/DB trên máy do Docker Engine dừng. Chưa có chứng cứ e2e chỉ từ unit tests.
- **Flutter:** `flutter analyze` sạch, 8/8 test đạt, APK debug build được. Đã kiểm tra app offline trên emulator; chưa nối chuỗi simulator → backend → app và chưa thử LAN trên điện thoại thật.
- **Bản đồ/phân vùng:** không thuộc P0 một trạm. `docs/map-and-zone-spec.md` là tài liệu đề xuất, không phải tính năng đã làm; khu vực/tọa độ minh họa chưa được xác minh và cần change request nếu muốn triển khai.

## 3. Việc còn phải làm theo thứ tự

### P0 — Trước khi tuyên bố PoC hoàn thành

1. Khởi động Docker Linux Engine; tạo DB kiểm thử tách biệt, chạy `docker compose up`, `npm run migrate`, backend và simulator; chạy `npm run integration` và lưu log.
2. Bổ sung integration test PostgreSQL/MQTT cho thứ tự status cùng boot và khác boot, retained status/LWT, dedupe, thứ tự telemetry, ACK sau DB commit và lỗi DB.
3. Đóng G0: ghi model/serial linh kiện, pinout, mức logic, nguồn, BOM/chi phí/lead time, người phụ trách/backup, tiêu chí sai số và giới hạn thời gian phản ứng; xin xác nhận ADR 002 và sơ đồ đấu dây.
4. Đấu bench theo đúng tài liệu nhà sản xuất và driver đã tính theo tải thực; nạp ESP32; thử NORMAL/WATCH/WARNING/EMERGENCY, outlier, sensor unplug, khôi phục và mất broker/backend.
5. Chốt giới hạn sai số trước khi đo; ghi ba mức × 30 mẫu, jig, MAE, max error và độ lệch chuẩn. Không tự điền kết quả hay suy diễn độ chính xác từ build.
6. Thử outbox khi mất uplink và reboot, khôi phục rồi xác minh ACK; thử đủ 16 slot và lần enqueue kế tiếp.
7. Cài APK debug lên điện thoại thật cùng LAN; kiểm tra URL, REST/WebSocket, stale, lịch sử và nhãn mô phỏng/thật.
8. Chạy tối thiểu 30 event để báo p50/p95; làm backup/restore và soak mục tiêu 24 giờ; lưu reboot/mất mẫu/lỗi.
9. Rehearsal 5–7 phút; tạo APK/hash từ commit đã review, merge đúng quy trình, gắn release tag và bàn giao known limitations/backlog.

### P1/P2 — Không làm lẫn vào nghiệm thu P0

- P1: marker/mini-map cho một trạm chỉ sau khi có vị trí đã xác minh; cảm biến mưa/nhiệt độ chỉ khi có đúng linh kiện và hiệu chuẩn.
- P2: LTE A7670C, LoRa SX1262, solar/LiFePO4, vỏ ngoài trời, OTA và đa trạm sau khi P0 đạt.
- Push notification, điều khiển từ xa và dashboard web không được tính là đã triển khai trong PoC hiện tại.

## 4. Blocker hiện tại

- Docker Linux Engine không chạy trên máy rà soát; vì vậy không thể chạy PostgreSQL, Mosquitto hoặc integration-check.
- `platformio device list` không thấy cổng ESP32; không có thiết bị để nạp firmware/đo bench.
- Do thiếu hai điều kiện này, trạng thái chính xác hiện tại là **unit/build checks passed; e2e, bench và nghiệm thu còn mở**. Không có căn cứ để tuyên bố hoàn thành 100%.
