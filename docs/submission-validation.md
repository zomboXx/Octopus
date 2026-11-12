# Kiểm tra gói source nộp AE — 12/11/2026

Các lệnh dưới đây được chạy từ một thư mục giải nén source riêng, không dùng `node_modules`, `.dart_tool` hoặc cấu hình máy riêng của bản phát triển. Phụ thuộc `fast-uri` của API được cập nhật từ 3.1.8 lên 3.1.9 theo bản vá; đã cài lại từ lockfile và chạy lại suite API sau cập nhật.

| Kiểm tra | Kết quả |
| --- | --- |
| Web `npm ci`, `npm run check` | Thành công |
| Web `npm run test:server` | 9/9 đạt |
| Web Playwright trên Microsoft Edge | 16/16 đạt |
| API `npm ci`, `npm test` | 6/6 đạt |
| `npm audit` khi cài web và API | 0 lỗ hổng được báo ở thời điểm kiểm tra |
| Flutter `pub get`, `analyze` | Thành công, không có vấn đề được báo |
| Flutter `test` | 22/22 đạt |
| Node server chạy từ bản giải nén | Trang `/`, `/try/`, `/release.json`, `/api/plans` trả HTTP 200 |
| Không cấu hình khóa AI | API báo `configured: false`, không gọi dịch vụ trả phí |
| Liên kết APK khi chưa có file cục bộ | Trỏ tới GitHub Releases |
| `docker compose --env-file .env.example config --quiet` | Hợp lệ |
| Quét nội dung đóng gói | Không kèm `.env`, khóa API theo mẫu thông dụng, private key, keystore, dữ liệu build/cache hoặc APK |

**Giới hạn xác minh Docker:** lần kiểm tra này không chạy được container vì Docker Desktop trên máy báo lỗi khởi tạo Inference manager tại socket `dockerInference`. Đã kiểm tra cấu hình Compose và chạy cùng Node server trực tiếp. Đây không phải kết quả kiểm thử container thành công. Hướng dẫn Node.js trong [SUBMISSION.md](../SUBMISSION.md) là phương án chạy thay thế.

Không chạy lời gọi AI trả phí trong đợt đóng gói. Các suite dùng dữ liệu giả lập; kết quả không thay thế thử nghiệm hiệu quả học tập hoặc kiểm tra quyền Android trên điện thoại thật. APK công khai vẫn là bản 0.6.3 tại tag `v0.6.3-ae.1`; đợt đóng gói cập nhật tài liệu và phụ thuộc API, không thay đổi ứng dụng Android.
