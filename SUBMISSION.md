# Octopus — mã nguồn nộp AI in Economics 2026

Nhóm Octopus gồm Nguyễn Đức Phát, Nguyễn Hoàng Phương Linh, Trần Thị Tuyết Nhi và Đường Khánh Ngọc. Bản nộp gồm ứng dụng Android 0.6.8, website, API lập lịch, kiểm thử và tài liệu; video và PDF thuyết minh nộp riêng.

## 1. Chạy web nhanh từ ZIP

Giải nén toàn bộ ZIP. Mở terminal tại thư mục `Octopus` có `compose.yaml`. Cài và khởi động Docker Desktop (Linux containers) hoặc Docker Engine có Compose; cần Internet ở lần build đầu.

```sh
docker compose up --build
```

Mở http://127.0.0.1:4174/ để xem giới thiệu và tải APK; mở http://127.0.0.1:4174/try/ rồi chọn **Dùng hồ sơ mẫu An** để thử giao diện. Dừng bằng `docker compose down`. Cổng 4174 cần trống.

Không có Docker: cài Node.js 22 trở lên, vào `apps/website`, chạy `npm ci` rồi `npm start`. Website chạy cùng địa chỉ. Không cần API key để thử công việc, lịch mẫu và bộ đếm.

## 2. Chạy Android

Docker phục vụ web/API. Android Emulator chạy riêng bằng Android Studio; máy cần hỗ trợ ảo hóa. Tải [APK debug 0.6.8](https://github.com/zomboXx/Octopus/releases/download/v0.6.8-ae.2/octopus-0.6.8-android-debug.apk), kéo vào emulator Android 7.0 trở lên, mở Octopus và chọn **Dùng không đăng nhập**.

APK không nằm trong ZIP source. SHA-256 của APK phát hành:

```text
58E007230113EAA8BE23E127559545E541D32392288ECC390444A67E62BBEF0E
```

Tự chạy từ source: môi trường tham chiếu Flutter 3.41.9 / Dart 3.11.5, JDK 17, Android SDK theo cấu hình Gradle. Cài Android SDK và chấp nhận giấy phép bằng `flutter doctor --android-licenses`, kiểm tra `flutter doctor`, mở emulator rồi chạy:

```sh
cd apps/mobile
flutter pub get
flutter run --dart-define=OCTOPUS_API_URL=https://octopus-planning.beadedeasel2.chatgpt.site
```

Tạo APK bằng `flutter build apk --debug`; kết quả trong `build/app/outputs/flutter-apk/app-debug.apk`. Lần đầu cần Internet tải SDK/phụ thuộc. Các quyền Trợ năng, VPN và thống kê do người dùng cấp khi thử chức năng tương ứng. Xem [hướng dẫn sử dụng](docs/user-guide.md).

## 3. Lập lịch AI

Mở tab **Lịch trình** trên [web](https://zomboxx.github.io/Octopus/try/) hoặc trong APK bán kết, rồi chọn **Lên kế hoạch cùng AI**. Dùng một mục tiêu học tập minh họa. Starter có 5 lượt mỗi tháng cho mỗi trình duyệt hoặc bản cài. Người dùng xem trước và chọn các buổi muốn lưu.

Nếu dịch vụ phản hồi chậm, web có **Thử lịch mẫu** và **Xếp lịch theo giờ rảnh**. Với bản chạy cục bộ, xem [cách dùng API lập lịch](docs/demo-setup.md#bật-ai-beta-trong-môi-trường-cục-bộ).

## 4. Kiểm thử và thành phần bên thứ ba

- Web: trong `apps/website`, chạy `npm ci`, `npm run check`, `npm run test:server`. Kiểm thử giao diện: `npm test` (cần Microsoft Edge vì cấu hình Playwright dùng `msedge`).
- API: trong `apps/api`, chạy `npm ci`, `npm test`.
- Android: trong `apps/mobile`, chạy `flutter pub get`, `flutter analyze`, `flutter test`.
- [Quy trình kiểm thử](docs/testing.md), [kiến trúc](docs/architecture.md), [kê khai thư viện/API/công cụ AI](THIRD_PARTY_NOTICES.md), [danh sách phiên bản](docs/dependencies.json), [giấy phép gốc](LICENSES/).

Các kiểm thử tự động dùng dữ liệu giả lập; không chứng minh hiệu quả học tập thực tế. Gói source không kèm khóa API, `.env`, thông tin ký ứng dụng, dữ liệu cá nhân, cache SDK, `node_modules` hoặc lịch sử Git. Cài phụ thuộc theo lockfile đi kèm. `SOURCE_VERSION.json` trong ZIP ghi commit nguồn và `SHA256SUMS.txt` ghi mã kiểm tra từng file.

[Kết quả kiểm tra bản đóng gói và giới hạn xác minh](docs/submission-validation.md).
