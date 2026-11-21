# Triển khai website và bản cài

Repo đã có trang giới thiệu tại `/` và bản trải nghiệm tại `/try/`. Chạy `npm ci` rồi `npm start` trong `apps/website` để xem ở `http://127.0.0.1:4174/`.

## GitHub Pages

[Website công khai](https://zomboxx.github.io/Octopus/) được xuất từ `apps/website/dist/` bằng [workflow Pages](../.github/workflows/pages.yml). Trang công khai dùng API Octopus để lập lịch Starter và có lịch mẫu để thử ngay. APK được tải từ GitHub Releases. Xem [hướng dẫn Docker Compose](demo-setup.md) để chạy backend AI cục bộ.

## API lập lịch công khai

Web gửi yêu cầu đến `/api/plans` và Android dùng `/v1/plans` tại [máy chủ Octopus](https://octopus-planning.beadedeasel2.chatgpt.site/api/plans). GitHub Pages lấy URL qua biến `OCTOPUS_PUBLIC_PLANNING_URL` của workflow. Khi build APK, truyền origin của máy chủ qua `OCTOPUS_API_URL`. APK và web chỉ gửi thông tin cần cho việc lập lịch và dùng mã yêu cầu để giữ nguyên lượt khi gửi lại.

Máy chủ Octopus dùng [Planning Gateway](../apps/api/planning-gateway.mjs), chạy trên Sites và chuyển yêu cầu tới dịch vụ AI có sẵn. Thiết lập `OCTOPUS_UPSTREAM_URL` và `OCTOPUS_UPSTREAM_REQUEST_HEADER` trong biến môi trường của Worker. Đặt `OCTOPUS_UPSTREAM_LABEL` khi cần thống nhất tên sản phẩm trong kết quả AI. Kho giữ hạn mức Starter nằm phía máy chủ. Kiểm tra `GET /api/plans` trước buổi demo. Lần gọi đầu sau thời gian nghỉ có thể phản hồi chậm.

## Thống kê website

Trang giới thiệu và `/try/` dùng cùng lựa chọn đồng ý trên trình duyệt. Khi bật, website gửi sự kiện phiên, thời gian hoạt động trong demo và thao tác xem hoặc tải APK tới `POST /api/web-events` trên API Octopus. Hai trang chia sẻ mã phiên khi mở trong cùng một tab. Khi tắt, website dừng gửi sự kiện.

Worker dùng binding `DB` và [migration thống kê](../apps/api/drizzle/0000_web_analytics.sql). Dữ liệu gồm mã ngẫu nhiên, loại sự kiện và thời lượng. Báo cáo giới hạn 90 ngày theo múi giờ Việt Nam. `GET /api/web-analytics` trả số liệu tổng hợp theo ngày cho tài khoản chủ Site sau khi đăng nhập. Đặt ID tài khoản này vào biến runtime `OCTOPUS_ANALYTICS_OWNER_ID`. Có thể truyền `from` và `to` theo dạng YYYY-MM-DD.

## Cấu hình Vercel cho môi trường beta riêng

1. Import repo Octopus, đặt **Root Directory** thành `apps/website` và chọn **Framework Preset** là **Other**. Repo đã khai báo thư mục đầu ra `dist` và rewrite API. [Cấu hình trong repo](../apps/website/vercel.json)
2. Để bật AI beta, đặt `POOL_API_KEY` và `OCTOPUS_WEB_ORIGIN` trong môi trường server. Origin là địa chỉ HTTPS của website, không kèm đường dẫn. Đường dẫn `/v1/plans` dành cho app trỏ tới cùng handler với `/api/plans`.
3. Sau khi có URL thật, kiểm tra tải được `/`, `/try/`, logo và `/release.json`. Thử hồ sơ mẫu và lịch mẫu trên trình duyệt. Nếu đã bật AI beta, kiểm tra trạng thái bằng `GET /api/plans`.

## Metadata APK

[`release.json`](../apps/website/dist/release.json) điều khiển thông tin bản cài và nút tải. Khi có bản phát hành đã kiểm tra, cập nhật phiên bản, dung lượng theo byte, SHA-256 và URL GitHub Releases thuộc repo Octopus. Trạng thái kiểm thử trên máy ảo và điện thoại thật được ghi riêng.

Ở chế độ cục bộ, server tìm APK trong `apps/mobile/artifacts/octopus-android-debug.apk` hoặc dùng đường dẫn `OCTOPUS_LOCAL_APK`. Nếu tìm thấy file, website hiện nút tải cục bộ và dùng metadata build bên cạnh file khi dung lượng khớp.
