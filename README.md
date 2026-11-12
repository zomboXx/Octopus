<p align="center">
  <img src="apps/website/dist/assets/octopus-logo.png" width="88" height="88" alt="Logo Octopus">
</p>

<h1 align="center">Octopus</h1>

<p align="center">Ứng dụng Android giúp lên lịch học, hạn chế xao nhãng và theo dõi những việc đã làm.</p>

<p align="center"><strong>Android 0.6.3</strong> · Bản thử nghiệm · AI in Economics 2026</p>

<p align="center">
  <a href="docs/user-guide.md">Hướng dẫn sử dụng</a>
  · <a href="#chạy-thử">Chạy thử</a>
  · <a href="docs/architecture.md">Kiến trúc</a>
  · <a href="docs/">Tài liệu dự án</a>
</p>

Octopus do đội Octopus phát triển để dự thi AI in Economics 2026. Dự án tiếp nối Brain10, sản phẩm của cùng nhóm từng dùng dự thi UTE SV-Startup 2026 cấp trường.

## Giao diện Android

<p align="center">
  <img src="apps/website/dist/assets/app-home.png" width="215" alt="Màn Hôm nay của Octopus với hai công việc mẫu">
  <img src="docs/images/android-calendar.png" width="215" alt="Bảng lịch tuần trong Octopus">
  <img src="docs/images/android-focus.png" width="215" alt="Màn hình đặt phiên tập trung trong Octopus">
</p>

Ảnh chụp Octopus 0.6.3 trên Android Emulator với dữ liệu minh họa.

## Tính năng

| Tính năng | Cách sử dụng |
| --- | --- |
| Công việc và check-out | Thêm việc hôm nay hoặc ngày mai, ước lượng thời lượng, đánh dấu hoàn thành và ghi kết quả. Có thể ghi hoạt động ngoài điện thoại kèm ảnh. |
| Lịch trình | Đặt lịch cố định theo ngày trong tuần, xem lịch 1, 2 hoặc 4 tuần và mở chi tiết từng buổi. |
| Lập lịch AI beta | Nhập mục tiêu ôn tập để nhận đề xuất theo lịch cố định và quỹ học. Xem trước rồi xác nhận các buổi muốn lưu. Tính năng cần backend đã cấu hình. |
| Tập trung và nhắc nghỉ | Dùng bộ đếm và tùy chọn hạn chế ứng dụng hoặc Internet sau khi cấp quyền Android. Phiên dài có thể nhắc nghỉ và uống nước. |
| Thống kê và widget | Xem thời gian sử dụng theo ứng dụng. Dùng widget Ghi nhanh và Nhịp hôm nay để mở việc, xem tiến độ hoặc bắt đầu tập trung. |
| Vòng tròn cam kết | Ghi cam kết, check-in và xem chuỗi trên thiết bị. |

## Chạy thử

**Chạy thử cho ban giám khảo.** [Website công khai](https://zomboxx.github.io/Octopus/) · [Tải APK](https://github.com/zomboXx/Octopus/releases/tag/v0.6.3-ae.1) · [Docker Compose và Android Emulator](docs/demo-setup.md)

**Web cục bộ.** Cần Node.js 22 trở lên. Chạy từ thư mục gốc của repo, sau đó mở [trang giới thiệu](http://127.0.0.1:4174/) hoặc [bản trải nghiệm](http://127.0.0.1:4174/try/). Chọn **Dùng hồ sơ mẫu An** để thử các luồng chính.

```sh
cd apps/website
npm ci
npm start
```

**Android.** Cần Flutter SDK hỗ trợ Dart 3.11.5 và Android SDK. Mở emulator hoặc kết nối thiết bị, rồi chạy từ thư mục gốc.

```sh
cd apps/mobile
flutter pub get
flutter run
```

Trên Windows, chạy `./scripts/build-preview-apk.ps1` trong `apps/mobile` để tạo APK debug. File nằm tại `apps/mobile/artifacts/octopus-android-debug.apk` tính từ gốc repo. [Quy trình Android và kiểm thử](docs/testing.md)

**AI beta.** Khởi động API phát triển, sau đó truyền `OCTOPUS_API_URL` cho app Android. Bản demo web có lịch mẫu để thử ngay. [Cấu hình AI beta](docs/ai-beta.md)

## Cấu trúc repo

| Thư mục | Nội dung |
| --- | --- |
| [`apps/mobile/`](apps/mobile/) | Flutter, Kotlin, tài nguyên Android, widget và kiểm thử. |
| [`apps/website/`](apps/website/) | Trang giới thiệu, demo trình duyệt, hàm Vercel và bộ lập lịch dùng chung. |
| [`apps/api/`](apps/api/) | Server Node.js cục bộ phục vụ AI beta trên Android và kiểm thử API. |
| [`docs/`](docs/) | Hướng dẫn sử dụng, kiến trúc, kiểm thử, cấu hình AI và triển khai. |

## Trạng thái

Android 0.6.3 là bản thử nghiệm đã chạy trên Android Emulator. Công việc, hồ sơ khách và vòng tròn cam kết được lưu cục bộ. Bản web GitHub Pages hỗ trợ lịch mẫu. Có thể bật AI beta với backend chạy cục bộ bằng Compose. [Cấu hình triển khai](docs/deployment.md)
