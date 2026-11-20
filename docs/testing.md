# Kiểm thử Octopus

## Kiểm thử tự động

Chạy các lệnh trong từng thư mục từ một bản clone có Flutter, Android SDK và Node.js 22 trở lên.

| Thư mục | Lệnh | Phạm vi |
| --- | --- | --- |
| `apps/mobile` | `flutter pub get`, `flutter analyze`, `flutter test` | Lưu dữ liệu, lịch và kiểm tra giờ, giao diện, bộ đếm, thống kê và nhắc nghỉ. |
| `apps/website` | `npm ci`, `npm run check`, `npm run test:server`, `npm test` | Cú pháp, handler beta, hợp đồng lập lịch và các luồng Playwright trên Microsoft Edge. |
| `apps/api` | `npm ci`, `npm test` | Kiểm tra khung giờ, bản nháp và HTTP với mô hình giả lập. |

Playwright tự mở website cục bộ. Dùng `OCTOPUS_TEST_URL` để chạy suite trên một URL đã bật sẵn. Ảnh từ kiểm thử giao diện Flutter nằm trong `apps/mobile/test/previews/`.

## Android Emulator và thiết bị

Dùng AVD Android 13 API 33 để thử nhanh. Trên Windows, helper `scripts/android-dev.ps1` trong `apps/mobile` làm việc với AVD tên `Octopus_API_33`. Có thể chọn AVD khác bằng Android Studio và chạy `flutter run` trực tiếp.

1. Kiểm tra tên Octopus, biểu tượng launcher, màn hình chào và tab Hôm nay.
2. Tạo một công việc mẫu, check-out, khởi động lại app rồi xác nhận dữ liệu còn trong danh sách.
3. Tạo lịch cố định và thử đổi giữa danh sách, bảng tuần và chế độ xem rộng.
4. Thử bộ đếm trước. Sau đó cấp từng quyền Android khi cần kiểm tra chặn ứng dụng, VPN, thống kê hoặc nhắc nghỉ. Kiểm tra kết thúc sớm và kết nối mạng trở lại.
5. Thêm hai widget bằng launcher. Kiểm tra mở việc từ widget và cập nhật trạng thái sau khi check-out.

Các bài tích hợp Android nằm trong [`integration_test/`](../apps/mobile/integration_test/). Script `android-dev.ps1 -Action Test` chạy bài smoke trên AVD đã chỉ định. Khả năng hoạt động trên điện thoại thật, đặc biệt với chế độ tiết kiệm pin và các launcher khác, cần được xác nhận theo thiết bị.

## Xác nhận bản APK

Chạy `./scripts/build-preview-apk.ps1` trong `apps/mobile`. Đối chiếu tên app, mã gói `vn.octopus.mobile`, phiên bản và SHA-256 trong `artifacts/build.json` trước khi chia sẻ file thử nghiệm. Dùng bản APK vừa kiểm tra để cập nhật metadata tải xuống khi có bản phát hành. [Metadata website](deployment.md)
