# Sơ đồ đấu nối phần cứng trạm cảnh báo lũ IoT FWA

Tài liệu này hướng dẫn đấu nối chi tiết giữa vi điều khiển ESP32 DevKitC/WROOM-32 với cảm biến khoảng cách siêu âm A02YYUW, còi, đèn LED và các cảm biến mở rộng.

---

## 1. Bảng phân bổ chân GPIO (Pinout Mapping)

| Thiết bị / Tín hiệu | Chân thiết bị | Chân ESP32 | Mức điện áp | Ghi chú kỹ thuật |
|---|---|---|---|---|
| **Cảm biến A02YYUW** | VCC | 5V (VIN) | 3.3V – 5.0V | Nguồn cảm biến lấy từ nguồn 5V ổn áp |
| | GND | GND | 0V | Nối mass chung |
| | TX | **GPIO 16 (RX2)** | 3.3V logic | Tín hiệu UART 9600 8N1 (processed mode) |
| | RX | Treo cao / Để hở | 3.3V – 5.0V | Nối lên 5V/3.3V qua trở 10k hoặc để hở |
| **Đèn LED cảnh báo** | Cực B/G Driver | **GPIO 27** | 3.3V logic | Điều khiển qua transistor NPN hoặc MOSFET kênh N |
| **Còi báo động (Buzzer)**| Cực B/G Driver | **GPIO 14** | 3.3V logic | Điều khiển qua transistor NPN hoặc MOSFET kênh N |
| **Gầu lật mưa (Tùy chọn)**| Chốt tiếp điểm | **GPIO 25** | 3.3V logic | Ngắt ngoài `FALLING`, trở treo nội pull-up |
| **DS18B20 (Tùy chọn)** | DATA (DQ) | **GPIO 26** | 3.3V logic | Giao thức 1-Wire, cần điện trở kéo 4.7kΩ lên 3.3V |

---

## 2. Sơ đồ nguyên lý mạch động lực (Driver Circuit)

Tuyệt đối **KHÔNG CẤP TẢI CÒI / ĐÈN CÔNG SUẤT TRỰC TIẾP TỪ CHÂN GPIO CỦA ESP32** (chân GPIO chỉ chịu dòng tối đa 12–20mA, trong khi còi báo động có thể ăn dòng từ 100mA – 300mA và sinh suất điện động tự cảm phá hỏng chip).

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
                     Drain  │ (MOSFET)     │ Collector (Transistor NPN 2N2222 / SS8050)
                         ┌──┴──┐        ┌──┴──┐
    GPIO (14/27) ──[1kΩ]─┤ Gate│   hoặc ┤ Base│
                         └──┬──┘        └──┬──┘
                    Source  │              │ Emitter
                            │              │
                           GND            GND
```

### Lưu ý an toàn điện:
1. **Diode dập xung ngược (Flyback Diode)**: Mắc song song ngược cực một diode `1N4007` qua 2 cực của còi báo (Buzzer) để dập tia lửa điện sinh ra bởi cuộn cảm khi ngắt nguồn.
2. **Điện trở hạn dòng cực Base/Gate**: Sử dụng điện trở $1\text{ k}\Omega$ nối giữa chân GPIO của ESP32 và cực Base của Transistor hoặc Gate của MOSFET.
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
