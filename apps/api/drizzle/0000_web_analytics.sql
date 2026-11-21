CREATE TABLE web_sessions (
  id TEXT PRIMARY KEY,
  started_at INTEGER NOT NULL,
  day TEXT NOT NULL
);
--> statement-breakpoint
CREATE INDEX web_sessions_retention ON web_sessions(started_at);
--> statement-breakpoint
CREATE INDEX web_sessions_day ON web_sessions(day);
--> statement-breakpoint
CREATE TABLE web_events (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES web_sessions(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('visit', 'demo_start', 'demo_time', 'android_interest', 'download_click')),
  elapsed_ms INTEGER NOT NULL,
  active_ms INTEGER NOT NULL
);
--> statement-breakpoint
CREATE INDEX web_events_session ON web_events(session_id);
--> statement-breakpoint
CREATE VIEW web_analytics_daily AS
WITH journeys AS (
  SELECT s.day,
    MIN(CASE WHEN e.kind = 'demo_start' THEN e.elapsed_ms END) AS demo,
    MIN(CASE WHEN e.kind = 'android_interest' THEN e.elapsed_ms END) AS interest,
    MIN(CASE WHEN e.kind = 'download_click' THEN e.elapsed_ms END) AS download,
    MIN(SUM(e.active_ms), 3600000) AS active_ms
  FROM web_sessions s JOIN web_events e ON e.session_id = s.id
  WHERE s.started_at >= (unixepoch() - 90 * 86400) * 1000
  GROUP BY s.id
)
SELECT day, COUNT(*) AS visits, COUNT(demo) AS demo_visits,
  SUM(CASE WHEN demo IS NOT NULL THEN active_ms ELSE 0 END) AS demo_active_ms,
  SUM(CASE WHEN demo <= interest THEN 1 ELSE 0 END) AS interest_after_demo,
  SUM(CASE WHEN interest IS NOT NULL AND demo IS NULL THEN 1 ELSE 0 END) AS interest_direct,
  SUM(CASE WHEN interest < demo THEN 1 ELSE 0 END) AS interest_before_demo,
  SUM(CASE WHEN demo <= download THEN 1 ELSE 0 END) AS downloads_after_demo,
  SUM(CASE WHEN download IS NOT NULL AND demo IS NULL THEN 1 ELSE 0 END) AS downloads_direct,
  SUM(CASE WHEN download < demo THEN 1 ELSE 0 END) AS downloads_before_demo
FROM journeys GROUP BY day;
