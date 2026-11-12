# Octopus — mã nguồn nộp AI in Economics 2026

Nhóm Octopus gồm Nguyễn Đức Phát, Nguyễn Hoàng Phương Linh, Trần Thị Tuyết Nhi và Đường Khánh Ngọc. Sản phẩm tiếp nối Brain10 của cùng bốn thành viên. Bản nộp gồm ứng dụng Android 0.6.3, website, API lập lịch, kiểm thử và tài liệu; video và PDF thuyết minh nộp riêng.

## 1. Chạy web nhanh từ ZIP

Giải nén toàn bộ ZIP. Mở terminal tại thư mục `Octopus` có `compose.yaml`. Cài và khởi động Docker Desktop (Linux containers) hoặc Docker Engine có Compose; cần Internet ở lần build đầu.

```sh
docker compose up --build
```

Mở http://127.0.0.1:4174/ để xem giới thiệu và tải APK; mở http://127.0.0.1:4174/try/ rồi chọn **Dùng hồ sơ mẫu An** để thử giao diện. Dừng bằng `docker compose down`. Cổng 4174 cần trống.

Không có Docker: cài Node.js 22 trở lên, vào `apps/website`, chạy `npm ci` rồi `npm start`. Website chạy cùng địa chỉ. Không cần API key để thử công việc, lịch mẫu và bộ đếm.

## 2. Chạy Android

Docker phục vụ web/API. Android Emulator chạy riêng bằng Android Studio; máy cần hỗ trợ ảo hóa. Tải [APK debug 0.6.3](https://github.com/zomboXx/Octopus/releases/download/v0.6.3-ae.1/octopus-0.6.3-android-debug.apk), kéo vào emulator Android 7.0 trở lên, mở Octopus và chọn **Dùng không đăng nhập**.

APK không nằm trong ZIP source. SHA-256 của APK phát hành:

```text
D9A6FDA566FE6982D7B2DD985AEB66D424C7CF8F4AF53BCED940ECDF1E7F6EE2
```

Tự chạy từ source: môi trường tham chiếu Flutter 3.41.9 / Dart 3.11.5, JDK 17, Android SDK theo cấu hình Gradle. Cài Android SDK và chấp nhận giấy phép bằng `flutter doctor --android-licenses`, kiểm tra `flutter doctor`, mở emulator rồi chạy:

```sh
cd apps/mobile
flutter pub get
flutter run
```

Tạo APK bằng `flutter build apk --debug`; kết quả trong `build/app/outputs/flutter-apk/app-debug.apk`. Lần đầu cần Internet tải SDK/phụ thuộc. Các quyền Trợ năng, VPN và thống kê do người dùng cấp khi thử chức năng tương ứng. Xem [hướng dẫn sử dụng](docs/user-guide.md).

## 3. AI thật (tùy chọn)

Web công khai dùng lịch mẫu; APK phát hành chưa gắn backend AI công khai. Để chấm AI thật, sao chép `.env.example` ở gốc thành `.env`, điền `OCTOPUS_DEMO_API_KEY` của tài khoản riêng, chọn endpoint/model phù hợp rồi chạy lại Compose. API có thể phát sinh phí theo tài khoản nhà cung cấp. Key chỉ ở backend; không đưa vào Flutter hoặc web tĩnh.

Xem [hướng dẫn lấy mã beta và kết nối Android Emulator](docs/demo-setup.md#bật-ai-beta-trong-môi-trường-cục-bộ). Emulator dùng `http://10.0.2.2:4174` để tới máy chạy Compose. Thiết bị Android thật cần backend có địa chỉ truy cập được; `127.0.0.1` và `10.0.2.2` không phải địa chỉ dùng chung trên Internet.

AI hỗ trợ tạo bản nháp kế hoạch từ đầu vào người dùng và lịch bận. Người dùng duyệt trước khi lưu. Chưa có chatbot hỏi đáp đa lượt, huấn luyện mô hình riêng hoặc đồng bộ nhóm giữa thiết bị.

## 4. Kiểm thử và thành phần bên thứ ba

- Web: trong `apps/website`, chạy `npm ci`, `npm run check`, `npm run test:server`. Kiểm thử giao diện: `npm test` (cần Microsoft Edge vì cấu hình Playwright dùng `msedge`).
- API: trong `apps/api`, chạy `npm ci`, `npm test`.
- Android: trong `apps/mobile`, chạy `flutter pub get`, `flutter analyze`, `flutter test`.
- [Quy trình kiểm thử](docs/testing.md), [kiến trúc](docs/architecture.md), [kê khai thư viện/API/công cụ AI](THIRD_PARTY_NOTICES.md), [danh sách phiên bản](docs/dependencies.json), [giấy phép gốc](LICENSES/).

Các kiểm thử tự động dùng dữ liệu giả lập; không chứng minh hiệu quả học tập thực tế. Gói source không kèm khóa API, `.env`, thông tin ký ứng dụng, dữ liệu cá nhân, cache SDK, `node_modules` hoặc lịch sử Git. Cài phụ thuộc theo lockfile đi kèm. `SOURCE_VERSION.json` trong ZIP ghi commit nguồn và `SHA256SUMS.txt` ghi mã kiểm tra từng file.

[Kết quả kiểm tra bản đóng gói và giới hạn xác minh](docs/submission-validation.md).
