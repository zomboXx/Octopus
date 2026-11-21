import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {test} from 'node:test';
import {createPlanningGateway} from './planning-gateway.mjs';

const origin = 'https://zomboxx.github.io';
const endpoint = 'https://example.test/api/web-events';
const report = 'https://example.test/api/web-analytics';
const owner = 'owner-test';

function setup(t) {
  const db = new DatabaseSync(':memory:');
  t.after(() => db.close());
  db.exec(readFileSync(new URL('./drizzle/0000_web_analytics.sql', import.meta.url), 'utf8'));
  const binding = {
    prepare: sql => ({
      bind: (...args) => ({
        run: () => db.prepare(sql).run(...args),
        all: () => ({results: db.prepare(sql).all(...args)}),
      }),
    }),
    batch: statements => statements.map(statement => statement.run()),
  };
  return {db, env: {DB: binding, OCTOPUS_ANALYTICS_OWNER_ID: owner}};
}

const gateway = createPlanningGateway({fetchUpstream: () => assert.fail('Analytics must stay local')});
function post(env, value, requestOrigin = origin) {
  return gateway(new Request(endpoint, {
    method: 'POST', headers: {Origin: requestOrigin}, body: JSON.stringify(value),
  }), env);
}

test('counts distinct journeys and caps duplicate events without storing identifying data', async t => {
  const {env, db} = setup(t);
  const session = randomUUID();
  const send = (kind, elapsedMs, activeMs = 0, id = randomUUID()) =>
    post(env, {id, sessionId: session, kind, elapsedMs, activeMs, name: 'ignored'});
  const start = await send('android_interest', 0);
  const event = randomUUID();
  for (const result of [start, await send('demo_start', 1000), await send('demo_time', 7000, 6000, event),
    await send('demo_time', 7000, 6000, event), await send('download_click', 10_000)]) {
    assert.equal(result.status, 204);
    assert.equal(result.headers.get('access-control-allow-origin'), origin);
  }
  const other = randomUUID();
  assert.equal((await post(env, {id: randomUUID(), sessionId: other, kind: 'download_click', elapsedMs: 1})).status, 204);
  assert.equal(db.prepare('SELECT count(*) n FROM web_events').get().n, 5);
  assert.deepEqual(Object.keys(db.prepare('SELECT * FROM web_events LIMIT 1').get()),
    ['id', 'session_id', 'kind', 'elapsed_ms', 'active_ms']);
  const response = await gateway(new Request(report, {headers: {'oai-authenticated-user-id': owner}}), env);
  assert.equal(response.status, 200);
  const {days} = await response.json();
  assert.equal(days[0].visits, 2);
  assert.equal(days[0].demo_visits, 1);
  assert.equal(days[0].demo_active_ms, 6000);
  assert.equal(days[0].interest_before_demo, 1);
  assert.equal(days[0].downloads_after_demo, 1);
  assert.equal(days[0].downloads_direct, 1);
});

test('rejects foreign origins, invalid bodies and unauthorized reports, and cleans old rows', async t => {
  const {env, db} = setup(t);
  const event = {id: randomUUID(), sessionId: randomUUID(), kind: 'visit', elapsedMs: 0};
  assert.equal((await post(env, event, 'https://other.example')).status, 403);
  assert.equal((await post(env, {...event, activeMs: 1})).status, 400);
  assert.equal((await post(env, {...event, payload: 'a'.repeat(3000)})).status, 413);
  assert.equal((await gateway(new Request(report), env)).status, 403);
  const oldSession = randomUUID();
  db.prepare('INSERT INTO web_sessions VALUES (?, ?, ?)').run(oldSession, 1000, '1970-01-01');
  db.prepare('INSERT INTO web_events VALUES (?, ?, ?, ?, ?)').run(randomUUID(), oldSession, 'visit', 0, 0);
  assert.equal((await post(env, event)).status, 204);
  assert.equal(db.prepare('SELECT count(*) n FROM web_events').get().n, 1);
});
