# Biên bản hiệu chuẩn trạm nước

Trạm: ________  Ngày giờ: ________  Người đo: ________  Model/serial cảm biến: ________  Firmware/config version: ________

Chiều cao từ mặt cảm biến đến mốc không H0 (cm): ________. Hướng gá: ________. Vật cản trong góc đo: ________. Nguồn/điện áp: ________.

| Mức | Thước chuẩn (cm) | Số đo thô (mm), 30 mẫu | Giá trị trung bình (cm) | MAE (cm) | Lệch lớn nhất (cm) | Độ lệch chuẩn (cm) | Ghi chú gợn/vật cản |
|---|---:|---|---:|---:|---:|---:|---|
| Thấp | | | | | | | |
| Giữa | | | | | | | |
| Cao | | | | | | | |

Giới hạn chấp nhận phải được nhóm chốt **trước khi xem số liệu**. DFRobot không công bố độ chính xác tuyệt đối cho SEN0311; không dùng một con số tự đặt làm thông số hãng. Nếu đo không đạt, đánh dấu chưa đạt và điều chỉnh lắp đặt/cảm biến, sau đó lập biên bản thử lại.

## Kiểm tra phần cứng bắt buộc

- [ ] Đọc đúng pinout/mức logic và nguồn của lô A02YYUW.
- [ ] Mọi mức nước nằm ngoài blind zone 3 cm và trong dải 3–450 cm của bề mặt đo.
- [ ] Còi/đèn dùng driver, đầu ra mặc định an toàn khi boot/brownout.
- [ ] Rút sensor: LED lỗi khác pattern lũ, không có số đo 0 giả.
- [ ] Rút Wi-Fi/broker: trạm vẫn chuyển cấp và kích hoạt đèn/còi.
- [ ] Reboot lúc offline: outbox giữ alert chưa ACK.
- [ ] Đo thời gian từ xác nhận đổi cấp đến đầu ra tại chỗ.
- [ ] Ghi ảnh/video, nhật ký thời gian và người kiểm chứng.
