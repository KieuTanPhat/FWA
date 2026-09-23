# Sơ đồ đấu nối phần cứng trạm cảnh báo lũ IoT FWA

> **Bản tham khảo, chưa được xác minh bench.** Chốt sơ đồ theo đúng phiên bản ESP32, sensor và tải đã mua. Đo mức logic UART trước khi nối trực tiếp: GPIO ESP32 không chịu được tín hiệu 5V; lắp level shifter nếu TX vượt mức phù hợp với ESP32. Không cấp nguồn/tải công suất theo sơ đồ này khi chưa kiểm tra dòng và thông số linh kiện.

Tài liệu này hướng dẫn đấu nối chi tiết giữa vi điều khiển ESP32 DevKitC/WROOM-32 với cảm biến khoảng cách siêu âm A02YYUW, còi, đèn LED và các cảm biến mở rộng.

---

## 1. Bảng phân bổ chân GPIO (Pinout Mapping)

| Thiết bị / Tín hiệu | Chân thiết bị | Chân ESP32 | Mức điện áp | Ghi chú kỹ thuật |
|---|---|---|---|---|
| **Cảm biến A02YYUW** | VCC | 3V3 hoặc nguồn phù hợp | 3.3V – 5.0V | Dải nguồn theo DFRobot; kiểm tra nguồn thực tế và sụt áp |
| | GND | GND | 0V | Nối mass chung |
| | TX | **GPIO 16 (RX2)** | TTL; phải đo mức cao của đúng sensor | UART 9600 8N1; dùng level shifter nếu vượt mức vào ESP32 |
| | RX | Để hở | Theo tài liệu DFRobot, hở hoặc mức cao chọn processed mode | Không kéo lên 5V khi chưa xác nhận giới hạn chân RX của đúng sensor |
| **Đèn LED cảnh báo** | Cực B/G Driver | **GPIO 27** | 3.3V logic | Điều khiển qua transistor NPN hoặc MOSFET kênh N |
| **Còi báo động (Buzzer)**| Cực B/G Driver | **GPIO 14** | 3.3V logic | Điều khiển qua transistor NPN hoặc MOSFET kênh N |
| **Gầu lật mưa (Tùy chọn)**| Chốt tiếp điểm | **GPIO 25** | 3.3V logic | Ngắt ngoài `FALLING`, trở treo nội pull-up |
| **DS18B20 (Tùy chọn)** | DATA (DQ) | **GPIO 26** | 3.3V logic | Giao thức 1-Wire, cần điện trở kéo 4.7kΩ lên 3.3V |

---

## 2. Sơ đồ nguyên lý mạch động lực (Driver Circuit)

**Không cấp tải còi/đèn công suất trực tiếp từ GPIO ESP32.** GPIO chỉ là tín hiệu điều khiển 3.3V. Chọn transistor/MOSFET theo dòng tải và thông số datasheet; tính điện trở base nếu dùng BJT. ESP32-WROOM-32 có các giới hạn điện áp tuyệt đối ở IO, vì vậy không đưa tín hiệu 5V vào chân GPIO.

```text
Sơ đồ mạch Driver đóng cắt còi báo (Buzzer) & Đèn LED:

                       +5V / +12V (Nguồn công suất ngoài)
                            │
                      ┌─────┴──────────────┐
                      │    [ TẢI: CÒI ]    │
                      │  hoặc [ ĐÈN LED ]  │
                      └─────┬──────────────┘
                            │      ▲
                            │      │ Diode 1N4007 (Bảo vệ chống dòng ngược)
                            │      │
                            ├──────┴───────┐
                            │              │
                     Drain  │ (logic-level MOSFET)
                         ┌──┴──┐
    GPIO (14/27) ──[R theo datasheet]─┤ Gate
                         └──┬──┘
                    Source  │
                            │
                           GND
```

Sơ đồ trên là topology tham khảo; chưa chỉ định MOSFET, điện trở gate/base, dòng tải hoặc cầu chì. Chốt các giá trị sau khi biết mã còi/đèn và nguồn. Không áp dụng một giá trị điện trở chung cho cả gate MOSFET lẫn base BJT.

### Lưu ý an toàn điện:
1. **Diode dập xung ngược**: Chỉ dùng cho tải cảm ứng theo cực tính, dòng và thời gian nhả của tải; chọn diode theo datasheet. Buzzer áp điện không mặc nhiên cần diode.
2. **Điện trở điều khiển**: Tính theo loại transistor/MOSFET và thông số tải; giá trị cần có trong sơ đồ cuối sau khi chọn linh kiện.
3. **Chung mass (Common Ground)**: Dây GND của nguồn nuôi ESP32 và nguồn nuôi còi/đèn phải được nối chung lại với nhau.

---

## 3. Lắp đặt cơ khí và hình học cảm biến A02YYUW

1. **Khoảng cách tĩnh không $H_0$**:
   - Khoảng cách từ mặt cảm biến đến đáy dòng chảy $H_0$ được quy định trong `demo_config.h` (mặc định demo là $200\text{ cm}$).
   - Mực nước dâng $H = H_0 - d$ (với $d$ là khoảng cách cảm biến đo được).
2. **Góc mở sóng âm (Beam Angle 60°)**:
   - Gắn cảm biến vuông góc 90° so với mặt nước.
   - Giữ bán kính hình nón không có vật cản (thành ống, cọc, rác trôi dạt) trong dải đo để tránh phản xạ giả.
3. **Vùng mù (Blind Zone 3cm)**: Mực nước cao nhất không được vượt quá khoảng cách 3cm sát mắt cảm biến.

## Tài liệu tham chiếu

- [DFRobot SEN0311/A02YYUW: thông số, chân và UART](https://wiki.dfrobot.com/sen0311/)
- [DFRobot: chế độ RX và giao thức UART](https://wiki.dfrobot.com/sen0311/docs/21651)
- [Espressif ESP32-WROOM-32 datasheet](https://documentation.espressif.com/esp32-wroom-32_datasheet_en.html)
