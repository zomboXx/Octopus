# Website Octopus

Trang giới thiệu nằm tại `/` và bản trải nghiệm trình duyệt tại `/try/`. Xem [hướng dẫn bản trải nghiệm](DEMO.md).

```sh
npm ci
npm start
npm run check
npm run test:server
npm test
```

Server phát triển mặc định chạy tại `http://127.0.0.1:4174`. Playwright dùng Microsoft Edge. Nếu APK nội bộ có trong `../mobile/artifacts/`, server phát triển hiển thị link tải cục bộ.

Khi triển khai lên Vercel, chọn `apps/website` làm Root Directory. Cấu hình `POOL_API_KEY` và `OCTOPUS_WEB_ORIGIN` ở server để bật lập lịch AI trên tên miền công khai. `OCTOPUS_WEB_ORIGIN` là origin HTTPS đầy đủ, ví dụ `https://octopus.example.org`. API lập lịch yêu cầu mã beta, được tạo ở máy phát triển bằng `node scripts/prepare-ai-beta.mjs` khi khóa đã có trong môi trường.
