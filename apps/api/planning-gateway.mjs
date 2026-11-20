const allowedOrigin = 'https://zomboxx.github.io';
const maxBytes = 100_000;
const requestIdHeader = 'X-Octopus-Request-Id';
const guestPattern = /^Guest [a-f0-9]{64}$/;
const requestIdPattern = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;
const redirects = new Set([301, 302, 303, 307, 308]);

async function readBody(request) {
  const reader = request.body?.getReader();
  if (!reader) return '';
  const decoder = new TextDecoder();
  let bytes = 0;
  let body = '';
  try {
    for (;;) {
      const {value, done} = await reader.read();
      if (done) return body + decoder.decode();
      bytes += value.byteLength;
      if (bytes > maxBytes) throw new RangeError('Request body exceeds the limit');
      body += decoder.decode(value, {stream: true});
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
}

const requestErrors = {
  400: 'Dữ liệu lập lịch chưa hợp lệ. Kiểm tra mục tiêu, lịch bận và giờ học rồi thử lại.',
  401: 'Không xác thực được hồ sơ Starter. Hãy tải lại hoặc mở lại ứng dụng.',
  403: 'Hồ sơ này chưa được phép sử dụng dịch vụ lập lịch.',
  409: 'Yêu cầu này đang được xử lý. Hãy chờ rồi thử lại.',
  422: 'Không có khung giờ phù hợp. Hãy kiểm tra lại lịch bận và nhịp học.',
  429: 'Đã tới giới hạn lập lịch. Kiểm tra số lượt Starter hoặc thử lại sau.',
};

export function createPlanningGateway({fetchUpstream = (url, options) => fetch(url, options)} = {}) {
  async function callUpstream(upstream, options) {
    let url = upstream;
    for (let attempt = 0; attempt < 4; attempt++) {
      const response = await fetchUpstream(url.href, {...options, redirect: 'manual'});
      if (!redirects.has(response.status)) return response;
      const location = response.headers.get('Location');
      await response.body?.cancel();
      if (!location) throw new Error('redirect without location');
      const next = new URL(location, url);
      if (next.origin !== upstream.origin || next.username || next.password) {
        throw new Error('redirect to a different origin');
      }
      if (options.method === 'POST' && response.status === 303) {
        throw new Error('redirect would change POST to GET');
      }
      url = next;
    }
    throw new Error('redirect limit reached');
  }

  return async function handle(request, env) {
    const path = new URL(request.url).pathname;
    const origin = request.headers.get('Origin');
    const headers = {
      'Cache-Control': 'no-store',
      'Vary': 'Origin',
      ...(origin === allowedOrigin ? {'Access-Control-Allow-Origin': origin} : {}),
    };
    const json = (data, status = 200, details = {}) =>
      Response.json(data, {status, headers: {...headers, ...details}});
    if (path !== '/api/plans' && path !== '/v1/plans') return json({error: 'Không có đường dẫn này.'}, 404);
    if (origin && origin !== allowedOrigin) return json({error: 'Trang này chưa được cấp quyền gọi API.'}, 403);
    if (request.method === 'OPTIONS') {
      return new Response(null, {status: 204, headers: {
        ...headers,
        'Access-Control-Allow-Methods': 'GET, POST',
        'Access-Control-Allow-Headers': `Authorization, Content-Type, ${requestIdHeader}`,
        'Access-Control-Max-Age': '600',
      }});
    }
    if (request.method !== 'GET' && request.method !== 'POST') {
      return json({error: 'Phương thức này không được hỗ trợ.'}, 405);
    }

    const token = request.headers.get('Authorization');
    const requestId = request.headers.get(requestIdHeader);
    if ((token || request.method === 'POST') && !guestPattern.test(token ?? '')) {
      return json({error: requestErrors[401]}, 401);
    }
    if (request.method === 'POST' && !requestIdPattern.test(requestId ?? '')) {
      return json({error: 'Thiếu mã yêu cầu hợp lệ. Hãy tải lại hoặc mở lại ứng dụng.'}, 400);
    }

    let upstream;
    try {
      upstream = new URL(env.OCTOPUS_UPSTREAM_URL);
      if (upstream.protocol !== 'https:' || upstream.username || upstream.password ||
          !/^[a-z0-9-]+$/i.test(env.OCTOPUS_UPSTREAM_REQUEST_HEADER ?? '')) {
        throw new Error('Invalid upstream settings');
      }
    } catch {
      return json({error: 'Dịch vụ lập lịch chưa được cấu hình.'}, 503);
    }

    const upstreamHeaders = new Headers({Accept: 'application/json'});
    if (token) upstreamHeaders.set('Authorization', token);
    const clientIp = request.headers.get('CF-Connecting-IP');
    if (clientIp && request.method === 'POST') upstreamHeaders.set('X-Forwarded-For', clientIp);
    let body;
    if (request.method === 'POST') {
      if (Number(request.headers.get('Content-Length')) > maxBytes) {
        return json({error: 'Yêu cầu quá lớn.'}, 413);
      }
      try {
        body = await readBody(request);
        JSON.parse(body);
      } catch (error) {
        if (error instanceof RangeError) return json({error: 'Yêu cầu quá lớn.'}, 413);
        return json({error: requestErrors[400]}, 400);
      }
      upstreamHeaders.set('Content-Type', 'application/json');
      upstreamHeaders.set(env.OCTOPUS_UPSTREAM_REQUEST_HEADER, requestId);
    }
    try {
      const response = await callUpstream(upstream, {
        method: request.method,
        headers: upstreamHeaders,
        body,
        signal: AbortSignal.timeout(100_000),
      });
      if (!response.ok) {
        if (response.status >= 500) console.error('Planning upstream returned', response.status);
        const error = requestErrors[response.status] ?? 'Dịch vụ lập lịch đang gián đoạn. Hãy thử lại sau.';
        return json({error}, response.status < 500 ? response.status : 502,
                    {'X-Octopus-Upstream': String(response.status)});
      }
      const data = await response.json();
      if (request.method === 'GET' && !token) {
        const {configured, accessRequired, starterLimit, planningVersion} = data;
        return json({configured, accessRequired, starterLimit, planningVersion});
      }
      return json(data);
    } catch (error) {
      const reason = /different origin/i.test(error.message) ? 'redirect-origin'
        : /redirect limit/i.test(error.message) ? 'redirect-limit'
        : /illegal invocation/i.test(error.message) ? 'invocation'
        : /redirect/i.test(error.message) ? 'redirect'
        : /network|fetch|connection/i.test(error.message) ? 'network'
        : error.name;
      console.error('Planning upstream failed', reason);
      return json({error: 'Dịch vụ lập lịch đang gián đoạn. Hãy thử lại sau.'}, 502,
                  {'X-Octopus-Upstream': reason});
    }
  };
}

export default {fetch: createPlanningGateway()};
