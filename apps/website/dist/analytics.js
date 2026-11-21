import {publicPlanningUrl} from './try/planning-endpoint.js';

const control = document.querySelector('[data-analytics-page]');
if (control && window.crypto?.randomUUID) setupAnalytics(control);

function setupAnalytics(control) {
  const demo = control.dataset.analyticsPage === 'demo';
  const endpoint = new URL('/api/web-events', publicPlanningUrl || location.origin);
  const preferenceKey = 'octopus.analytics.preference';
  const sessionKey = 'octopus.analytics.session';
  const hour = 3_600_000;
  const allow = control.querySelector('[data-allow]');
  const deny = control.querySelector('[data-deny]');
  const status = control.querySelector('[data-status]');
  let preference;
  let session;
  let lastTick = Date.now();
  let lastInteraction = lastTick;

  try {
    preference = localStorage.getItem(preferenceKey);
    session = JSON.parse(sessionStorage.getItem(sessionKey));
  } catch {
    status.textContent = 'Trình duyệt đang chặn lưu tùy chọn thống kê.';
    allow.disabled = deny.disabled = true;
    return;
  }

  function send(kind, activeMs = 0) {
    if (preference !== 'yes') return;
    const now = Date.now();
    if (!session?.id || now - session.last > 30 * 60_000 || now - session.start >= hour) {
      session = {id: crypto.randomUUID(), start: now, demoReported: false};
    }
    session.last = now;
    const kinds = [];
    if (demo && !session.demoReported) {
      session.demoReported = true;
      kinds.push('demo_start');
    }
    kinds.push(kind);
    try {
      sessionStorage.setItem(sessionKey, JSON.stringify(session));
    } catch {
      return;
    }
    for (const eventKind of kinds) {
      fetch(endpoint, {
        method: 'POST',
        credentials: 'omit',
        keepalive: true,
        headers: {'Content-Type': 'text/plain'},
        body: JSON.stringify({
          id: crypto.randomUUID(), sessionId: session.id, kind: eventKind,
          elapsedMs: Math.max(0, now - session.start),
          activeMs: eventKind === 'demo_time' ? activeMs : 0,
        }),
      }).catch(() => {});
    }
  }

  function updateChoice() {
    allow.hidden = preference === 'yes';
    deny.textContent = preference === 'yes' ? 'Tắt thống kê' : 'Từ chối';
    status.textContent = preference === 'yes' ? 'Đã bật thống kê.' :
      preference === 'no' ? 'Đã tắt thống kê.' : 'Đang tắt cho đến khi bạn đồng ý.';
  }

  function setChoice(value) {
    preference = value;
    lastTick = Date.now();
    if (preference === 'yes') send('visit');
    else {
      session = null;
      try { sessionStorage.removeItem(sessionKey); } catch {}
    }
    updateChoice();
  }

  control.addEventListener('click', event => {
    const choice = event.target === allow ? 'yes' : event.target === deny ? 'no' : null;
    if (!choice) return;
    try {
      localStorage.setItem(preferenceKey, choice);
      control.open = true;
      setChoice(choice);
    } catch {
      status.textContent = 'Chưa lưu được lựa chọn trên trình duyệt này.';
    }
  });
  addEventListener('storage', event => {
    if ((event.key === preferenceKey || event.key === null) && event.newValue !== preference) setChoice(event.newValue);
  });

  updateChoice();
  if (preference === 'yes') send('visit');
  if (demo) {
    for (const type of ['pointerdown', 'keydown', 'scroll', 'touchstart']) {
      addEventListener(type, () => { lastInteraction = Date.now(); }, {passive: true});
    }
    const tick = () => {
      const now = Date.now();
      const activeMs = Math.min(10_000, Math.max(0, now - lastTick));
      lastTick = now;
      if (document.visibilityState === 'visible' && document.hasFocus() &&
          now - lastInteraction < 60_000 && activeMs) send('demo_time', activeMs);
    };
    setInterval(tick, 10_000);
    for (const type of ['focus', 'blur', 'visibilitychange']) {
      addEventListener(type, () => { lastTick = Date.now(); }, true);
    }
    addEventListener('pagehide', tick);
  }

  document.addEventListener('click', event => {
    const link = event.target.closest?.('a');
    if (link?.id === 'android-download' && link.hasAttribute('href') && link.getAttribute('aria-disabled') !== 'true') {
      send('download_click');
    } else if (link?.hash === '#download') {
      send('android_interest');
    }
  });
}
