# Kiến trúc Octopus

Octopus gồm ba ứng dụng trong cùng repo. Android là app chính. Website giới thiệu sản phẩm và cung cấp bản trải nghiệm trên trình duyệt. Web và Android gọi API lập lịch Octopus để tạo bản nháp với hạn mức Starter.

## Mã nguồn và trách nhiệm

| Đường dẫn | Trách nhiệm |
| --- | --- |
| [`apps/mobile/lib/`](../apps/mobile/lib/) | Màn hình Flutter, luồng onboarding, lịch, công việc, kiểm tra khi lưu lịch và trạng thái app. |
| [`brain_store.dart`](../apps/mobile/lib/brain_store.dart) và [`device_bridge.dart`](../apps/mobile/lib/device_bridge.dart) | Quản lý dữ liệu trong Flutter và gọi Kotlin qua MethodChannel `vn.octopus/device`. |
| [`android/app/src/main/kotlin/vn/octopus/mobile/`](../apps/mobile/android/app/src/main/kotlin/vn/octopus/mobile/) | Lưu dữ liệu app, thống kê Android, bảo vệ tập trung, VPN cục bộ, nhắc nghỉ và widget. |
| [`apps/website/dist/`](../apps/website/dist/) | HTML, CSS, JavaScript và tài nguyên của trang giới thiệu và bản trải nghiệm. |
| [`apps/website/api/plans.mjs`](../apps/website/api/plans.mjs) | Nhận yêu cầu beta từ web hoặc Android qua HTTPS, kiểm tra mã truy cập và chuyển cho bộ lập lịch. |
| [`apps/website/server/planner.mjs`](../apps/website/server/planner.mjs) | Chuẩn hóa dữ liệu, tính khung rảnh, gọi mô hình và kiểm tra bản nháp. |
| [`apps/api/server.mjs`](../apps/api/server.mjs) | API phát triển chạy ở loopback và dùng cùng bộ lập lịch. |

| [`apps/api/planning-gateway.mjs`](../apps/api/planning-gateway.mjs) | API công khai cho web và Android. Chuyển yêu cầu và mã thử lại sang dịch vụ lập lịch, giữ cấu hình máy chủ trong Sites. |

## Luồng lập lịch AI

1. Android hoặc web gửi mục tiêu, ngữ cảnh học, lịch bận, nhịp học và các phiên đã lưu đến API.
2. Bộ lập lịch tính khung khả dụng trong bảy ngày theo giờ Việt Nam. Mô hình trả JSON và chọn mã trong danh sách khung được cung cấp.
3. Máy chủ xác thực cấu trúc, mã giờ và mốc kiểm tra rồi trả bản nháp. Giao diện hiển thị giờ, nội dung, giả định và câu hỏi bổ sung.
4. Khi người dùng xác nhận, app kiểm tra lại ràng buộc với lịch hiện tại rồi lưu các phiên đã chọn.

## Nơi lưu dữ liệu

Android giữ hồ sơ khách, lịch, công việc, ghi nhận hoạt động và vòng tròn trên thiết bị. Bản web giữ trạng thái trong `localStorage` của trình duyệt. Hai bản có vùng dữ liệu riêng. Dữ liệu thống kê sử dụng Android và các lựa chọn bảo vệ tập trung được xử lý cục bộ. [Dữ liệu của luồng AI](ai-beta.md)
