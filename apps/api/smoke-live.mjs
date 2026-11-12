// Opt-in live check. Sends synthetic study context, never real profile data.
import {mkdir, writeFile} from 'node:fs/promises';
import {normalizeRequest, buildSlots, callModel} from './planner.mjs';
const context = normalizeRequest({request: 'Tôi kiểm tra DBMS trong 3 ngày nữa, CNPM trong 4 ngày nữa, KTLT trong 5 ngày nữa. Lên lịch ôn và nội dung từng buổi.',
  timezone: 'Asia/Ho_Chi_Minh', learningContext: 'DBMS: JOIN, chuẩn hóa. CNPM: yêu cầu và kiểm thử. KTLT: mảng, con trỏ. Tôi muốn làm bài tập và chữa lỗi.',
  preferences: {startMinute: 1080, endMinute: 1320, sessionMinutes: 45, dailyMinutes: 120},
  commitments: [{title: 'Lịch học mẫu', weekdays: [1, 3, 5], startMinute: 1080, endMinute: 1140}], existingPlan: []});
try {
  const draft = await callModel(context, buildSlots(context));
  await mkdir('test-results', {recursive: true});
  await writeFile('test-results/live-draft.json', JSON.stringify(draft, null, 2));
  console.log(JSON.stringify({ok: true, model: draft.model, status: draft.status, sessions: draft.sessions.length, exams: draft.exams}));
} catch (e) {console.error(e.message); process.exitCode = 1;}
