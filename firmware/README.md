# Firmware trạm ESP32

PoC dùng ESP32 DevKitC/WROOM-32, A02YYUW SEN0311 qua UART 9600 8N1, đèn và còi qua **driver transistor/MOSFET phù hợp**. Không cấp tải công suất trực tiếp từ GPIO. Thông số khung UART, chân RX chọn chế độ processed và dải 3–450 cm theo [DFRobot SEN0311](https://wiki.dfrobot.com/sen0311/docs/21651). Nguồn cảm biến 3.3–5 V; đo mức logic TX và xác minh tương thích 3.3 V của ESP32 trước khi nối.

| Tín hiệu | GPIO ESP32 mẫu |
|---|---:|
| A02YYUW TX → ESP32 RX2 | 16 |
| Gầu lật (tùy chọn) | 25 |
| DS18B20 (tùy chọn) | 26 |
| LED qua điện trở/driver | 27 |
| Còi qua driver | 14 |

Chân A02YYUW RX để hở hoặc kéo cao theo chế độ processed. Trước khi thử ngoài jig, kiểm tra pinout trên đúng lô sensor, cực nguồn, mạch driver và mức điện áp. `include/demo_config.h` ghi **ngưỡng demo**, H0=200 cm; phải đo lại H0 và ghi biên bản hiệu chuẩn ở ba mức nước trở lên. Gầu lật và DS18B20 mặc định tắt vì chưa có thông số model/linh kiện; khi bật phải chỉnh hệ số mm/tick và đấu dây đúng.

## Biên dịch/nạp

1. Sao chép `include/secrets.example.h` thành `include/secrets.h`, điền Wi-Fi, broker IP LAN và credential riêng `station-01` từ `.env` cục bộ.
2. `python -m platformio run -e esp32dev`.
3. Lần đầu trên chip trắng: `python -m platformio run -e esp32dev -t uploadfs` để khởi tạo LittleFS. Lệnh này **xóa outbox cũ**, không chạy khi đang có alert chưa đồng bộ.
4. Nối ESP32 và chạy `python -m platformio run -e esp32dev -t upload`.
5. `python -m platformio device monitor -b 115200` để quan sát log.

`python -m platformio test -e native` kiểm tra parser và logic rủi ro. Local output chạy trong vòng đo riêng; tác vụ Wi-Fi/MQTT không quyết định mức cảnh báo. Đèn một chớp ngắn/giây báo sensor/config/outbox lỗi; WATCH chớp chậm; WARNING chớp nhanh và còi ngắt quãng; EMERGENCY chớp/còi nhanh. Khi boot hoặc sensor timeout, risk UNKNOWN và còi lũ tắt, không hiển thị NORMAL như hiện hành.

Outbox LittleFS lưu tối đa 16 alert; chỉ xóa sau ACK của backend. Nếu đầy, không xóa alert cũ; trạm bật báo lỗi và bộ đếm mất event lưu NVS. Đây là giới hạn PoC, cần đo flash endurance và thử brownout trước khi đưa ra hiện trường.
