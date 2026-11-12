# Octopus cho Android

Ứng dụng Flutter và Kotlin cho Android. Hỗ trợ lịch cố định, công việc hôm nay/ngày mai, check-out, thống kê thời gian dùng ứng dụng, phiên tập trung, hai widget hệ thống và nhóm cam kết cục bộ. Các chức năng giới hạn ứng dụng và Internet cần quyền do người dùng cấp trong Android.

## Chạy và kiểm thử

Trong thư mục này, dùng Flutter SDK tương thích với `pubspec.yaml` và Android SDK:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Trên Windows, `./scripts/build-preview-apk.ps1` tạo APK debug trong `artifacts/` cùng phiên bản và SHA-256. Octopus có mã ứng dụng riêng `vn.octopus.mobile`, vì vậy có thể cài cạnh Brain10. Dữ liệu được lưu trong vùng riêng của từng app.

## Lập lịch AI

Khởi động [API phát triển](../api/) trên máy. Trên Android Emulator, chạy:

```sh
flutter run --dart-define=OCTOPUS_API_URL=http://10.0.2.2:4180
```

Để tạo APK với API đã cấu hình, dùng `./scripts/build-preview-apk.ps1 -WithAI -ApiUrl <url>`. Backend HTTPS yêu cầu mã beta. `POOL_API_KEY` chỉ được cấu hình ở backend. Khi chạy app không có URL API, người dùng vẫn có thể lập lịch thủ công và dùng các công cụ tập trung.

## Thư mục chính

| Thư mục | Nội dung |
| --- | --- |
| [`lib/`](lib/) | Giao diện Flutter, dữ liệu, lịch trình và gọi chức năng Android. |
| [`android/app/src/main/`](android/app/src/main/) | Kotlin, manifest, widget, service và tài nguyên biểu tượng. |
| [`assets/`](assets/) | Logo hiển thị trong giao diện Flutter. |
| [`test/`](test/) và [`integration_test/`](integration_test/) | Kiểm thử Flutter và kiểm thử trên thiết bị. |
| [`scripts/`](scripts/) | Build APK và chạy thử với emulator trên Windows. |

[Hướng dẫn sử dụng](../../docs/user-guide.md) · [Quy trình kiểm thử](../../docs/testing.md) · [Cấu hình AI beta](../../docs/ai-beta.md)
