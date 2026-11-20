# Chạy thử Octopus cho ban giám khảo

## Mở ngay

- [Website giới thiệu](https://zomboxx.github.io/Octopus/) có nút tải APK.
- [Bản trải nghiệm web](https://zomboxx.github.io/Octopus/try/) có hồ sơ mẫu, công việc, bộ đếm tập trung và kế hoạch học mẫu.
- [Bản APK và mã nguồn tương ứng](https://github.com/zomboXx/Octopus/releases/tag/v0.6.8-ae.2) được gắn cùng một tag trên GitHub.

Bản công khai có AI Starter và kế hoạch mẫu. APK hỗ trợ Android 7.0 trở lên.

## Chạy website bằng Docker Compose

Cần Docker đang chạy và có Docker Compose. Với bản ZIP, giải nén rồi mở terminal trong thư mục có `compose.yaml` và chạy `docker compose up --build`. Lần đầu cần Internet để tải image và phụ thuộc. Không cần Git hoặc API key để dùng dữ liệu mẫu.

Nếu lấy mã nguồn qua Git:

```sh
git clone https://github.com/zomboXx/Octopus.git
cd Octopus
docker compose up --build
```

Mở [trang giới thiệu cục bộ](http://127.0.0.1:4174/) hoặc [bản trải nghiệm cục bộ](http://127.0.0.1:4174/try/). Website dùng URL APK từ GitHub Releases. Để phục vụ APK ngay từ máy chạy Docker, đặt file đã tải tại `apps/mobile/artifacts/octopus-android-debug.apk`. Container đọc thư mục này và website sẽ ưu tiên file cục bộ. Dừng bằng `docker compose down`.

## Cài APK trên Android Emulator

1. Mở Android Studio → **Device Manager**, tạo hoặc mở một máy ảo Android.
2. Kéo file APK đã tải vào cửa sổ emulator. Cũng có thể chạy `adb install -r octopus-0.6.8-android-debug.apk` khi chỉ có một thiết bị kết nối.
3. Mở **Octopus**, chọn **Dùng không đăng nhập**, rồi thử tab **Hôm nay**, **Lịch trình** và **Tập trung**.

Để tự build APK từ mã nguồn, xem [hướng dẫn Android](../apps/mobile/README.md).

## Bật AI beta trong môi trường cục bộ

Phần này dành cho người muốn kiểm thử API bằng key của mình. Tạo file `.env` ở gốc repo và đặt `OCTOPUS_DEMO_API_KEY`. Nếu dùng OpenAI chính thức, đặt thêm `POOL_API_BASE_URL=https://api.openai.com/v1` và `POOL_MODEL` thành model tài khoản có quyền dùng với JSON Schema. Chạy lại `docker compose up --build`.

Lấy mã beta từ container đang chạy.

```sh
docker compose exec website node --input-type=module -e "import {betaAccessCode} from './api/plans.mjs'; if (!process.env.POOL_API_KEY) throw new Error('Chưa cấu hình API key'); console.log(betaAccessCode(process.env.POOL_API_KEY));"
```

- **Web cục bộ** mở `/try/`, nhập lịch cố định, chọn **Lên kế hoạch cùng AI** và nhập mã beta.
- **Android Emulator** dùng bản chạy từ source với Flutter. Trong `apps/mobile`, chạy `flutter run --dart-define=OCTOPUS_API_URL=http://10.0.2.2:4174 --dart-define=OCTOPUS_API_REQUIRE_CODE=true`, rồi nhập cùng mã beta trong app. `10.0.2.2` trỏ tới máy đang chạy Docker.
