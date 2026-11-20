# Cấu hình AI

Bản web công khai và APK bán kết có thể tạo lịch AI ở chế độ Starter. Mỗi bản cài hoặc trình duyệt có 5 lượt lập lịch mỗi tháng. Sau khi xem bản nháp, người dùng chọn các buổi muốn lưu. Trong bản web, mục **Thử lịch mẫu** dùng được khi dịch vụ AI tạm gián đoạn.

[Cấu hình triển khai](deployment.md#api-lập-lịch-công-khai)

## AI beta trên máy phát triển

AI beta tạo bản nháp lịch ôn tập. Cả Android lẫn web cần lịch cố định và nhịp học trước khi tạo đề xuất. Máy chủ giữ khóa nhà cung cấp trong biến môi trường `POOL_API_KEY`. APK chỉ nhận URL backend qua `OCTOPUS_API_URL`.

## Android Emulator

Trong terminal thứ nhất, chạy từ gốc repo sau khi đã cấu hình khóa cho tiến trình server.

```sh
cd apps/api
npm ci
npm start
```

Kiểm tra `GET http://127.0.0.1:4180/health`. Trong terminal khác, chạy Android trên emulator.

```sh
cd apps/mobile
flutter run --dart-define=OCTOPUS_API_URL=http://10.0.2.2:4180
```

Nếu dùng `scripts/android-dev.ps1 -Action Run -WithAI`, script Windows tự cấu hình ADB reverse và truyền URL loopback cho app. Khi dùng trên điện thoại qua Internet, truyền URL HTTPS của backend beta và nhập mã thử trong app.

## Bản web

Trong `apps/website`, chạy `npm ci`, rồi `node scripts/prepare-ai-beta.mjs` và `npm start` với khóa trong môi trường server. Script lưu mã beta cục bộ dưới `apps/mobile/.android-dev/`. Mở `http://127.0.0.1:4174/try/`, đặt lịch cố định rồi nhập mã beta trong phần AI. Có thể dùng kế hoạch mẫu để kiểm tra giao diện khi backend chưa cấu hình.

## Dữ liệu và kiểm thử

Yêu cầu lập lịch gồm mục tiêu, ngữ cảnh, lịch bận và quỹ học. Hồ sơ định danh, ảnh, ghi nhận hoạt động và thống kê thời gian dùng app nằm ngoài payload lập lịch. Tránh nhập thông tin nhạy cảm vào ô mô tả mục tiêu và tên lịch.

Các bài test mặc định dùng dữ liệu thử hoặc mô hình giả lập. Chạy smoke test gọi mô hình thật chỉ khi muốn kiểm tra kết nối với nhà cung cấp và đã chuẩn bị ngân sách. [Quy trình kiểm thử](testing.md)
