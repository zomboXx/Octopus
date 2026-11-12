# Triển khai website và bản cài

Repo đã có trang giới thiệu tại `/` và bản trải nghiệm tại `/try/`. Chạy `npm ci` rồi `npm start` trong `apps/website` để xem ở `http://127.0.0.1:4174/`.

## Cấu hình Vercel

1. Import repo Octopus, đặt **Root Directory** thành `apps/website` và chọn **Framework Preset** là **Other**. Repo đã khai báo thư mục đầu ra `dist` và rewrite API. [Cấu hình trong repo](../apps/website/vercel.json)
2. Để bật AI beta, đặt `POOL_API_KEY` và `OCTOPUS_WEB_ORIGIN` trong môi trường server. Origin là địa chỉ HTTPS của website, không kèm đường dẫn. Đường dẫn `/v1/plans` dành cho app trỏ tới cùng handler với `/api/plans`.
3. Sau khi có URL thật, kiểm tra tải được `/`, `/try/`, logo và `/release.json`. Thử hồ sơ mẫu và lịch mẫu trên trình duyệt. Nếu đã bật AI beta, kiểm tra trạng thái bằng `GET /api/plans`.

## Metadata APK

[`release.json`](../apps/website/dist/release.json) điều khiển thông tin bản cài và nút tải. Khi có bản phát hành đã kiểm tra, cập nhật phiên bản, dung lượng theo byte, SHA-256 và URL GitHub Releases thuộc repo Octopus. Trạng thái kiểm thử trên máy ảo và điện thoại thật được ghi riêng.

Ở chế độ cục bộ, server tìm APK trong `apps/mobile/artifacts/octopus-android-debug.apk` hoặc dùng đường dẫn `OCTOPUS_LOCAL_APK`. Nếu tìm thấy file, website hiện nút tải cục bộ và dùng metadata build bên cạnh file khi dung lượng khớp.
