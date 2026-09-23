# Simulator phòng lab

Simulator chỉ dùng danh tính MQTT `sim-01`, bị ACL giới hạn vào `flood/sim-01/*`. Backend gán `data_origin=SIMULATED` theo trạm đã đăng ký, không tin nhãn trong payload. Chạy sau khi broker/backend đã sẵn sàng:

```powershell
cd simulator
npm install
npm run demo -- --scenario full --interval-ms 5000
```

Kịch bản: `normal`, `rise`, `fault`, `full`. Có thể dùng `--interval-ms 1000` để trình diễn nhanh. `rise_rate_cm_min` để null vì các bước kịch bản rời rạc không đủ cơ sở tính tốc độ dâng. Không dùng simulator để chứng minh độ chính xác cảm biến, độ trễ còi/đèn hay hoạt động offline của phần cứng.
