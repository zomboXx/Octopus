package vn.octopus.mobile

import org.junit.Assert.*
import org.junit.Test

class UsageTimelineTest {
    @Test fun foregroundIntervalsDoNotOverlapAndScreenOffEndsTheSession() {
        val timeline = UsageTimeline()
        timeline.event(1, "reading", 0)
        timeline.event(1, "video", 60000)
        timeline.event(2, "reading", 61000)
        timeline.event(16, "", 120000)
        timeline.finish(180000)
        assertEquals(listOf(UsageInterval("reading", 0, 60000), UsageInterval("video", 60000, 120000)), timeline.intervals)
    }

    @Test fun shutdownDoesNotInventAnOpenSessionUntilTheQueryEnd() {
        val timeline = UsageTimeline()
        timeline.event(1, "video", 100)
        timeline.event(26, "", 200)
        timeline.finish(1000000)
        assertTrue(timeline.intervals.isEmpty())
    }

    @Test fun reminderFiresAt15And30MinutesOnceAndResetsOnSwitch() {
        val tracker = UsageReminderTracker()
        val interval = 15 * 60000L
        tracker.event(1, "video", 0)
        assertEquals(0L, tracker.due(interval - 1, interval))
        assertEquals(interval, tracker.due(interval, interval))
        assertEquals(0L, tracker.due(interval + 1000, interval))
        assertEquals(interval * 2, tracker.due(interval * 2, interval))
        tracker.event(1, "reading", interval * 2 + 1000)
        assertEquals(0L, tracker.due(interval * 3, interval))
        tracker.event(16, "", interval * 3 + 1000)
        assertEquals(0L, tracker.due(interval * 8, interval))
    }

    @Test fun internalActivitySwitchKeepsTheContinuousAppDuration() {
        val tracker = UsageReminderTracker()
        val interval = 15 * 60000L
        tracker.event(1, "video", 0)
        tracker.event(2, "video", interval - 2000)
        assertEquals(0L, tracker.due(interval - 1000, interval))
        tracker.event(1, "video", interval - 500)
        assertEquals(interval, tracker.due(interval, interval))
        tracker.event(2, "video", interval + 1000)
        tracker.event(1, "video", interval + 10000)
        assertEquals(0L, tracker.due(interval * 2, interval))
    }
}
