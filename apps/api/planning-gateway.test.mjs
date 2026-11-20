import assert from 'node:assert/strict';
import test from 'node:test';
import {createPlanningGateway} from './planning-gateway.mjs';

const base = 'https://api.example.test';
const origin = 'https://zomboxx.github.io';
const authorization = 'Guest ' + 'a'.repeat(64);
const requestId = '4b2f416e-f5ad-4fc3-82d0-abfa737c37f0';
const env = {
  OCTOPUS_UPSTREAM_URL: 'https://planner.example.test/api/plans',
  OCTOPUS_UPSTREAM_REQUEST_HEADER: 'X-Planning-Request-Id',
};

test('allows the hosted demo to preflight and rejects a different origin', async () => {
  const gateway = createPlanningGateway({fetchUpstream: () => assert.fail('Preflight should stay local')});
  const approved = await gateway(new Request(base + '/api/plans', {method: 'OPTIONS', headers: {Origin: origin}}), env);
  assert.equal(approved.status, 204);
  assert.equal(approved.headers.get('access-control-allow-origin'), origin);
  assert.match(approved.headers.get('access-control-allow-headers'), /X-Octopus-Request-Id/i);

  const denied = await gateway(new Request(base + '/api/plans', {headers: {Origin: 'https://other.example'}}), env);
  assert.equal(denied.status, 403);
  assert.equal(denied.headers.has('access-control-allow-origin'), false);
});

test('translates the request ID and keeps it stable when submitted again', async () => {
  const attempts = [];
  const handle = createPlanningGateway({fetchUpstream: async (url, options) => {
    assert.equal(url, env.OCTOPUS_UPSTREAM_URL);
    assert.equal(options.headers.get('Authorization'), authorization);
    assert.equal(options.headers.get('X-Forwarded-For'), '192.0.2.35');
    assert.equal(options.headers.get('X-Octopus-Request-Id'), null);
    attempts.push([options.headers.get(env.OCTOPUS_UPSTREAM_REQUEST_HEADER), JSON.parse(options.body)]);
    return Response.json({status: 'draft', quota: {remaining: 4}});
  }});
  for (const path of ['/v1/plans', '/api/plans']) {
    const result = await handle(new Request(base + path, {
      method: 'POST',
      headers: {Authorization: authorization, 'X-Octopus-Request-Id': requestId, 'CF-Connecting-IP': '192.0.2.35'},
      body: JSON.stringify({request: 'Ôn viết bài tiếng Anh'}),
    }), env);
    assert.equal(result.status, 200);
    assert.equal((await result.json()).quota.remaining, 4);
  }
  assert.deepEqual(attempts, Array(2).fill([requestId, {request: 'Ôn viết bài tiếng Anh'}]));
});

test('declines invalid and oversized requests before contacting the backend', async () => {
  const handle = createPlanningGateway({fetchUpstream: () => assert.fail('Invalid requests should stay local')});
  const anonymous = await handle(new Request(base + '/api/plans', {method: 'POST', body: '{}'}), env);
  assert.equal(anonymous.status, 401);
  const large = await handle(new Request(base + '/api/plans', {
    method: 'POST',
    headers: {Authorization: authorization, 'X-Octopus-Request-Id': requestId},
    body: JSON.stringify({request: 'a'.repeat(100_000)}),
  }), env);
  assert.equal(large.status, 413);
});

test('reports backend failures without forwarding internal error messages', async () => {
  const handle = createPlanningGateway({fetchUpstream: () => Response.json({error: 'Internal provider detail'}, {status: 503})});
  const result = await handle(new Request(base + '/v1/plans'), env);
  assert.equal(result.status, 502);
  assert.doesNotMatch((await result.json()).error, /provider detail/i);
});

test('preserves a request on same-origin redirects and rejects cross-origin forwarding', async () => {
  const attempts = [];
  const handle = createPlanningGateway({fetchUpstream: (url, options) => {
    attempts.push([url, options.headers.get('Authorization'), options.body]);
    if (attempts.length === 1) return Response.redirect(new URL('/v1/plans', url), 307);
    if (attempts.length === 2) return Response.redirect('https://other.example/plans', 307);
    assert.fail('The gateway must not forward a request to another origin');
  }});
  const result = await handle(new Request(base + '/api/plans', {
    method: 'POST',
    headers: {Authorization: authorization, 'X-Octopus-Request-Id': requestId},
    body: '{}',
  }), env);
  assert.equal(result.status, 502);
  assert.deepEqual(attempts, [
    [env.OCTOPUS_UPSTREAM_URL, authorization, '{}'],
    ['https://planner.example.test/v1/plans', authorization, '{}'],
  ]);
});
