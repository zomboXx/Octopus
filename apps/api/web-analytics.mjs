const kinds = new Set(['visit', 'demo_start', 'demo_time', 'android_interest', 'download_click']);
const uuid = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;
const dayPattern = /^\d{4}-\d{2}-\d{2}$/;
const hour = 3_600_000;
const day = 24 * hour;
const vietnamDay = time => new Date(time + 7 * hour).toISOString().slice(0, 10);

export async function handleWebAnalytics(request, env, {origin, readBody, json, headers}) {
  const path = new URL(request.url).pathname;
  if (path === '/api/web-analytics') {
    if (request.method !== 'GET') return json({error: 'Phương thức này không được hỗ trợ.'}, 405);
    const visitor = request.headers.get('oai-authenticated-user-id');
    if (!env.OCTOPUS_ANALYTICS_OWNER_ID || visitor !== env.OCTOPUS_ANALYTICS_OWNER_ID) {
      return json({error: 'Đăng nhập bằng tài khoản quản trị để xem báo cáo.'}, 403);
    }
    if (!env.DB) return json({error: 'Báo cáo chưa sẵn sàng.'}, 503);
    const query = new URL(request.url).searchParams;
    const to = query.get('to') || vietnamDay(Date.now());
    const from = query.get('from') || vietnamDay(Date.now() - 29 * day);
    const validDay = value => dayPattern.test(value) && Number.isFinite(Date.parse(value)) &&
      new Date(value).toISOString().slice(0, 10) === value;
    if (!validDay(from) || !validDay(to) || from > to || Date.parse(to) - Date.parse(from) >= 90 * day) {
      return json({error: 'Chọn khoảng báo cáo tối đa 90 ngày.'}, 400);
    }
    try {
      const result = await env.DB.prepare(
        'SELECT * FROM web_analytics_daily WHERE day BETWEEN ? AND ? ORDER BY day',
      ).bind(from, to).all();
      return json({from, to, days: result.results});
    } catch {
      return json({error: 'Chưa đọc được báo cáo.'}, 503);
    }
  }

  if (request.headers.get('Origin') !== origin) return json({error: 'Origin không được hỗ trợ.'}, 403);
  if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers: {
    ...headers,
    'Access-Control-Allow-Methods': 'POST',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '600',
  }});
  if (request.method !== 'POST') return json({error: 'Phương thức này không được hỗ trợ.'}, 405);
  if (!env.DB) return json({error: 'Thống kê chưa sẵn sàng.'}, 503);

  let input;
  try {
    input = JSON.parse(await readBody(request, 2048));
  } catch (error) {
    return json({error: 'Sự kiện không hợp lệ.'}, error instanceof RangeError ? 413 : 400);
  }
  const {id, sessionId, kind, elapsedMs, activeMs = 0} = input ?? {};
  if (typeof id !== 'string' || typeof sessionId !== 'string' || !uuid.test(id) ||
      !uuid.test(sessionId) || !kinds.has(kind) || !Number.isInteger(elapsedMs) ||
      elapsedMs < 0 || elapsedMs > hour || !Number.isInteger(activeMs) ||
      activeMs < 0 || activeMs > 10_000 || (kind !== 'demo_time' && activeMs !== 0)) {
    return json({error: 'Sự kiện không hợp lệ.'}, 400);
  }

  const now = Date.now();
  const started = now - elapsedMs;
  try {
    await env.DB.batch([
      env.DB.prepare('DELETE FROM web_sessions WHERE started_at < ?').bind(now - 90 * day),
      env.DB.prepare('INSERT OR IGNORE INTO web_sessions VALUES (?, ?, ?)').bind(sessionId, started, vietnamDay(started)),
      env.DB.prepare(`INSERT OR IGNORE INTO web_events (id, session_id, kind, elapsed_ms, active_ms)
        SELECT ?, id, ?, ?, ? FROM web_sessions WHERE id = ? AND started_at >= ?
          AND (SELECT COUNT(*) FROM web_events WHERE session_id = ?) < 500`)
        .bind(id, kind, elapsedMs, activeMs, sessionId, now - hour, sessionId),
    ]);
    return new Response(null, {status: 204, headers});
  } catch {
    return json({error: 'Chưa ghi nhận được thống kê.'}, 503);
  }
}
