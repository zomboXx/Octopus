import test from 'node:test';
import assert from 'node:assert/strict';
import {buildSlots, normalizeRequest, validateDraft, callModel} from './planner.mjs';
import {createPlanningServer} from './server.mjs';

const now = Date.parse('2026-10-19T09:00:00Z');
const request = () => ({request: 'DBMS sau 3 ngày, CNPM sau 4 ngày, KTLT sau 5 ngày', learningContext: '', timezone: 'Asia/Ho_Chi_Minh',
  preferences: {startMinute: 1080, endMinute: 1320, sessionMinutes: 45, dailyMinutes: 120},
  commitments: [{title: 'Đi làm', weekdays: [1], startMinute: 1080, endMinute: 1140}], existingPlan: []});
const output = slot => ({status: 'draft', summary: 'Ôn DBMS', questions: [], assumptions: ['Đề cương chưa được cung cấp.'],
  exams: [{subject: 'DBMS', date: '2026-10-22'}], sessions: [{slotId: slot.id, subject: 'DBMS', title: 'Tự kiểm tra kiến thức',
    objectives: ['Xác định phần còn yếu'], steps: ['Tự làm bài, rồi chữa lỗi'], expectedOutput: 'Danh sách lỗi và cách sửa', examDate: '2026-10-22'}]});

test('slots respect weekly blocks, existing plans, breaks, budget and passed time', () => {
  const input = request();
  input.existingPlan.push({start: '2026-10-20T11:00:00Z', end: '2026-10-20T11:45:00Z', kind: 'focus'});
  const context = normalizeRequest(input, now), slots = buildSlots(context);
  assert.equal(slots[0].start, '2026-10-19T12:00:00.000Z');
  assert.equal(slots.filter(s => s.date === '2026-10-20').length, 1);
  assert.equal(slots.find(s => s.date === '2026-10-20').start, '2026-10-20T11:55:00.000Z');
  for (const date of new Set(slots.map(s => s.date))) assert.ok(slots.filter(s => s.date === date).length * 45 <= 120);
  assert.ok(slots.every(s => Date.parse(s.start) > now));
});

test('malformed preferences, oversized contexts and invalid weekday are rejected', () => {
  for (const modify of [v => v.preferences.dailyMinutes = 481, v => v.commitments[0].weekdays = [8],
    v => v.learningContext = 'a'.repeat(6001), v => v.timezone = 'Europe/London']) {
    const value = request(); modify(value); assert.throws(() => normalizeRequest(value, now));
  }
});

test('draft schema, unknown/repeated slots, deadline and exam references are enforced', () => {
  const context = normalizeRequest(request(), now), slots = buildSlots(context);
  assert.equal(validateDraft(output(slots[0]), context, slots).sessions[0].start, slots[0].start);
  for (const modify of [v => v.sessions[0].slotId = 'invented', v => v.sessions.push(v.sessions[0]),
    v => v.sessions[0].examDate = '2026-10-19', v => v.exams[0].date = '2026-02-30', v => v.extra = 'unexpected']) {
    const value = output(slots[0]); modify(value); assert.throws(() => validateDraft(value, context, slots));
  }
  const clarification = {...output(slots[0]), status: 'needs_clarification', sessions: [], questions: ['Bạn thi ngày nào?']};
  assert.equal(validateDraft(clarification, context, slots).sessions.length, 0);
});

test('model refusal and incomplete output never become a schedule', async () => {
  const oldKey = process.env.POOL_API_KEY;
  process.env.POOL_API_KEY = 'unit-test-placeholder';
  try {
    for (const choice of [{finish_reason: 'stop', message: {refusal: 'refused'}}, {finish_reason: 'length', message: {content: '{}'}}]) {
      await assert.rejects(callModel(normalizeRequest(request(), now), [], {fetchImpl: async () => ({ok: true, json: async () => ({choices: [choice]})})}));
    }
  } finally {if (oldKey === undefined) delete process.env.POOL_API_KEY; else process.env.POOL_API_KEY = oldKey;}
});

test('access denial is actionable, never retried or read from a provider error body', async () => {
  const oldKey = process.env.POOL_API_KEY;
  process.env.POOL_API_KEY = 'unit-test-placeholder';
  try {
    for (const status of [401, 403]) {
      let calls = 0;
      await assert.rejects(callModel(normalizeRequest(request(), now), [], {
        fetchImpl: async () => {
          calls++;
          return {ok: false, status, json: () => {throw new Error('Provider body must remain unread');}};
        },
      }), error => error.message.includes(`AI-${status}`) && error.message.includes('liên hệ hỗ trợ'));
      assert.equal(calls, 1);
    }
  } finally {if (oldKey === undefined) delete process.env.POOL_API_KEY; else process.env.POOL_API_KEY = oldKey;}
});

test('HTTP flow rejects bad requests and returns validated model draft', async t => {
  let calls = 0;
  const server = createPlanningServer({now: () => now, model: async (context, slots) => { calls++; return validateDraft(output(slots[0]), context, slots); }});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const url = `http://127.0.0.1:${server.address().port}/v1/plans`;
  let response = await fetch(url, {method: 'POST', body: '{}'}); assert.equal(response.status, 400);
  response = await fetch(url, {method: 'POST', body: JSON.stringify({...request(), commitments: []})});
  assert.equal(response.status, 400); assert.equal(calls, 0, 'Missing fixed schedule must not consume a model call');
  response = await fetch(url, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(request())});
  assert.equal(response.status, 200); assert.equal((await response.json()).sessions.length, 1);
  response = await fetch(url, {method: 'POST', headers: {Origin: 'https://example.com'}, body: JSON.stringify(request())}); assert.equal(response.status, 403);
});
