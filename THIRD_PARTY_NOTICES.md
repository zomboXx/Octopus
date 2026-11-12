# Kê khai thư viện mã nguồn mở và API AI

Danh mục dựa trên các lockfile kèm source, ngày 12/11/2026. Kê khai theo phiên bản đã khóa; không coi các thành phần bên thứ ba là mã do nhóm tự viết. Bản kê máy đọc ở [docs/dependencies.json](docs/dependencies.json). Các bản giấy phép npm/pub được sao chép nguyên văn vào [LICENSES/](LICENSES/).

## Thành phần trực tiếp và công cụ xây dựng

| Thành phần | Phiên bản | Vai trò | Giấy phép hoặc điều kiện |
| --- | --- | --- | --- |
| Flutter / Dart | 3.41.9 / 3.11.5 | Ứng dụng Android và SDK kiểm thử | BSD-3-Clause và các thông báo đi kèm SDK |
| Kotlin / Android Gradle plugin / Gradle | 2.2.20 / 8.11.1 / 8.14 | Mã native Android, widget, Trợ năng và VPN | Apache-2.0; Android SDK có điều khoản riêng |
| cupertino_icons | 1.0.9 | Bộ biểu tượng Flutter | MIT |
| flutter_localizations / intl | theo SDK / 0.20.2 | Bản địa hóa | BSD-3-Clause; xem lockfile và LICENSES |
| Ajv | 8.20.0 | Xác thực JSON Schema cho yêu cầu và kế hoạch AI | MIT |
| Playwright | 1.64.1 | Kiểm thử web tự động, chỉ ở môi trường phát triển | Apache-2.0 |
| flutter_lints / Flutter Test / integration_test | 6.0.0 / theo SDK | Kiểm tra mã và kiểm thử Android | BSD-3-Clause |
| JUnit | 4.13.2 | Kiểm thử logic Kotlin | EPL-1.0 |
| Node.js | 22 trong Docker; source yêu cầu >=22 | HTTP server, API và fetch tích hợp | MIT và thông báo đi kèm |
| Plus Jakarta Sans / Roboto | TTF đóng kèm | Phông chữ web | OFL-1.1 / Apache-2.0; file giấy phép nằm cạnh font |

## API AI và dữ liệu gửi đi

- Nhà cung cấp mặc định trong source là PoolAI, endpoint `https://api.poolai.win/v1`, model mặc định `gpt-5.4-mini`. Đây là dịch vụ API, không phải mô hình mã nguồn mở do nhóm huấn luyện.
- Máy chủ gọi API tương thích OpenAI bằng `fetch` của Node.js và yêu cầu đầu ra JSON Schema. Source không dùng gói OpenAI SDK và không đóng kèm trọng số mô hình.
- Có thể chọn OpenAI chính thức bằng `POOL_API_BASE_URL=https://api.openai.com/v1`, khóa tương ứng và `POOL_MODEL` mà tài khoản có quyền dùng. Chỉ cấu hình endpoint chưa đủ để dịch vụ hoạt động; phải có tài khoản, quyền truy cập và ngân sách của nhà cung cấp.
- Trong Compose, khóa riêng đặt ở `OCTOPUS_DEMO_API_KEY`; container ánh xạ sang `POOL_API_KEY`. Key chỉ ở backend, không được đưa vào APK, web tĩnh hoặc source ZIP. `.env.example` chứa giá trị trống.
- Payload gồm mục tiêu, ngữ cảnh học, lịch cố định, nhịp học và khung giờ ứng viên. Họ tên, ngày sinh, nhật ký, ảnh và thống kê sử dụng nằm ngoài payload lập lịch. Tên lịch và nội dung người dùng nhập có thể chứa dữ liệu cá nhân, nên chỉ dùng dữ liệu minh họa khi chấm thử.
- AI tạo bản nháp nội dung và chọn khung ứng viên. Mã của nhóm tính giờ khả dụng, kiểm tra ràng buộc, hiển thị để người dùng xác nhận rồi lưu. Chưa có chatbot đa lượt hoặc fine-tuning trên dữ liệu người dùng.

## Công cụ AI và tài nguyên hỗ trợ phát triển

Nhóm có sử dụng Codex để hỗ trợ lập trình, rà soát, tài liệu và đóng gói; ImageGen hỗ trợ chuẩn hóa logo từ hình tham chiếu của nhóm. Video được dựng bằng Remotion, giọng đọc VBEE do nhóm cung cấp. Các công cụ này không phải dịch vụ được app gọi khi ban giám khảo chạy thử. Source ứng dụng không chứa nhạc, footage tham khảo, file giọng đọc hoặc dự án video.

## Danh mục phụ thuộc npm và Dart đầy đủ

| Hệ | Gói | Phiên bản khóa | Phạm vi | Giấy phép |
| --- | --- | --- | --- | --- |
| npm | @playwright/test | 1.64.1 | development | Apache-2.0 |
| npm | ajv | 8.20.0 | runtime | MIT |
| npm | fast-deep-equal | 3.1.3 | runtime | MIT |
| npm | fast-uri | 3.1.9 | runtime | BSD-3-Clause |
| npm | json-schema-traverse | 1.0.0 | runtime | MIT |
| npm | playwright | 1.64.1 | development | Apache-2.0 |
| npm | playwright-core | 1.64.1 | development | Apache-2.0 |
| npm | require-from-string | 2.0.2 | runtime | MIT |
| pub | async | 2.13.1 | transitive | BSD-3-Clause |
| pub | boolean_selector | 2.1.2 | transitive | BSD-3-Clause |
| pub | characters | 1.4.1 | transitive | BSD-3-Clause |
| pub | clock | 1.1.2 | transitive | Apache-2.0 |
| pub | collection | 1.19.1 | transitive | BSD-3-Clause |
| pub | cupertino_icons | 1.0.9 | direct main | MIT |
| pub | fake_async | 1.3.3 | transitive | Apache-2.0 |
| pub | file | 7.0.1 | transitive | BSD-3-Clause |
| pub | flutter | Flutter SDK 3.41.9 | direct main | BSD-3-Clause |
| pub | flutter_driver | Flutter SDK 3.41.9 | transitive | BSD-3-Clause |
| pub | flutter_lints | 6.0.0 | direct dev | BSD-3-Clause |
| pub | flutter_localizations | Flutter SDK 3.41.9 | direct main | BSD-3-Clause |
| pub | flutter_test | Flutter SDK 3.41.9 | direct dev | BSD-3-Clause |
| pub | fuchsia_remote_debug_protocol | Flutter SDK 3.41.9 | transitive | BSD-3-Clause |
| pub | integration_test | Flutter SDK 3.41.9 | direct dev | BSD-3-Clause |
| pub | intl | 0.20.2 | transitive | BSD-3-Clause |
| pub | leak_tracker | 11.0.2 | transitive | BSD-3-Clause |
| pub | leak_tracker_flutter_testing | 3.0.10 | transitive | BSD-3-Clause |
| pub | leak_tracker_testing | 3.0.2 | transitive | BSD-3-Clause |
| pub | lints | 6.1.0 | transitive | BSD-3-Clause |
| pub | matcher | 0.12.19 | transitive | BSD-3-Clause |
| pub | material_color_utilities | 0.13.0 | transitive | Apache-2.0 |
| pub | meta | 1.17.0 | transitive | BSD-3-Clause |
| pub | path | 1.9.1 | transitive | BSD-3-Clause |
| pub | platform | 3.1.6 | transitive | BSD-3-Clause |
| pub | process | 5.0.6 | transitive | BSD-3-Clause |
| pub | sky_engine | Flutter SDK 3.41.9 | transitive | BSD-3-Clause |
| pub | source_span | 1.10.2 | transitive | BSD-3-Clause |
| pub | stack_trace | 1.12.1 | transitive | BSD-3-Clause |
| pub | stream_channel | 2.1.4 | transitive | BSD-3-Clause |
| pub | string_scanner | 1.4.1 | transitive | BSD-3-Clause |
| pub | sync_http | 0.3.1 | transitive | BSD-3-Clause |
| pub | term_glyph | 1.2.2 | transitive | BSD-3-Clause |
| pub | test_api | 0.7.10 | transitive | BSD-3-Clause |
| pub | vector_math | 2.2.0 | transitive | BSD-3-Clause |
| pub | vm_service | 15.4.0 | transitive | BSD-3-Clause |
| pub | web | 1.1.1 | transitive | BSD-3-Clause |
| pub | webdriver | 3.2.0 | transitive | Apache-2.0 |

Các gói tùy chọn dành cho hệ điều hành khác có thể không có trong node_modules trên máy đóng gói; chúng vẫn được liệt kê từ lockfile. Khi cài dependencies, công cụ quản lý gói tải mã và giấy phép tương ứng. Nội dung chính thức của giấy phép có giá trị ưu tiên so với nhãn tóm tắt trong bảng.

## Quyền đối với mã của nhóm

Source được cung cấp để ban tổ chức và ban giám khảo kiểm tra, chạy thử và đánh giá bài dự thi. Repository chưa công bố giấy phép mã nguồn mở chung cho phần mã do nhóm viết; việc công khai source không tự cấp quyền tái sử dụng thương mại. Mỗi thành phần bên thứ ba tiếp tục theo giấy phép riêng.
