import {createServer} from 'node:http';
import {pathToFileURL} from 'node:url';
import {buildSlots, callModel, normalizeRequest} from './planner.mjs';

export function createPlanningServer({model = callModel, now = () => Date.now()} = {}) {
  let busy = false;
  const requests = [];
  return createServer(async (req, res) => {
    const send = (status, value) => {
      res.writeHead(status, {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store'});
      res.end(JSON.stringify(value));
    };
    if (req.method === 'GET' && req.url === '/health') return send(200, {ok: true, mode: 'local-development'});
    if (req.method !== 'POST' || req.url !== '/v1/plans') return send(404, {error: 'Không có đường dẫn này.'});
    // Local developer service only, bound to loopback. No anonymous public API.
    if (req.headers.origin) return send(403, {error: 'Không nhận yêu cầu từ trình duyệt.'});
    if (busy) return send(429, {error: 'Đang tạo một kế hoạch khác. Hãy chờ rồi thử lại.'});
    const time = now();
    while (requests.length && requests[0] < time - 60000) requests.shift();
    if (requests.length >= 5) return send(429, {error: 'Đã đạt giới hạn thử nghiệm. Hãy chờ một phút.'});
    let context;
    try {
      let body = '';
      for await (const chunk of req) {body += chunk.toString(); if (Buffer.byteLength(body) > 100000) throw new Error('Yêu cầu quá lớn.');}
      context = normalizeRequest(JSON.parse(body), time);
      if (!context.commitments.length) throw new Error('Nhập lịch cố định trước khi tạo kế hoạch AI.');
    } catch (e) {return send(400, {error: e instanceof SyntaxError ? 'Yêu cầu JSON không hợp lệ.' : e.message});}
    const slots = buildSlots(context);
    if (!slots.length) return send(422, {error: 'Không có khung giờ rảnh trong 7 ngày tới. Hãy kiểm tra lịch cố định và nhịp học.'});
    if (busy || requests.length >= 5) return send(429, {error: 'Dịch vụ đang bận. Hãy chờ rồi thử lại.'});
    requests.push(time); busy = true;
    try {send(200, await model(context, slots));}
    catch(e) {send(502, {error: /timeout|abort/i.test(e.name) ? 'AI phản hồi quá lâu. Hãy thử lại.' : e.message});}
    finally {busy = false;}
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  createPlanningServer().listen(Number(process.env.PORT || 4180), '127.0.0.1', () => console.log('Octopus planning API: http://127.0.0.1:4180 (local only)'));
}
