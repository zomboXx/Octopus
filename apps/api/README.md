# API lập lịch Octopus

API Node.js phát triển cục bộ dùng chung bộ lập lịch với website tại `apps/website/server/planner.mjs`.

```sh
npm ci
npm test
npm start
```

Mặc định API chỉ lắng nghe ở `127.0.0.1:4180`. Dùng `GET /health` để kiểm tra trạng thái và `POST /v1/plans` để tạo bản nháp lịch. Cấu hình `POOL_API_KEY` trong môi trường server khi muốn gọi nhà cung cấp AI. Kiểm thử thường dùng mô hình giả lập và không gọi dịch vụ tính phí. Xem `.env.example` để biết các biến tùy chọn.
