package vn.octopus.mobile

import org.junit.Assert.*
import org.junit.Test

class ReminderTimingTest {
    private val start = 1_800_000_000_000L
    private val interval = ReminderTiming.INTERVAL
    @Test fun boundariesAndShortSessions() {
        val end = start + 3 * interval
        assertEquals(0L, ReminderTiming.due(start, end, start + interval - 1, 0))
        assertEquals(1L, ReminderTiming.due(start, end, start + interval, 0))
        assertEquals(2L, ReminderTiming.due(start, end, start + 2 * interval, 1))
        assertEquals(0L, ReminderTiming.due(start, end, end, 2))
        assertEquals(0L, ReminderTiming.next(start, start + interval, start, 0))
    }
    @Test fun stopsAndInvalidSessionsNeverNotify() {
        assertEquals(0L, ReminderTiming.next(0, 0, start, 0))
        assertEquals(0L, ReminderTiming.next(start, start - 1, start, 0))
        assertEquals(0L, ReminderTiming.next(start, start + 481 * 60_000L, start, 0))
        assertEquals(0L, ReminderTiming.due(start, start + 3 * interval, start - 1, 0))
    }
    @Test fun duplicateAndLateDeliveriesCoalesce() {
        val end = start + 4 * interval
        assertEquals(0L, ReminderTiming.due(start, end, start + interval + 1000, 1))
        assertEquals(3L, ReminderTiming.due(start, end, start + 3 * interval + 1000, 1))
        assertEquals(0L, ReminderTiming.next(start, end, start + 3 * interval + 1000, 3))
    }
    @Test fun nextUsesSessionTimestampAndNeverSchedulesAtTheEnd() {
        val end = start + 3 * interval
        assertEquals(start + interval, ReminderTiming.next(start, end, start + 500, 0))
        assertEquals(start + interval + 1000, ReminderTiming.next(start, end, start + interval, 0))
        assertEquals(start + 2 * interval, ReminderTiming.next(start, end, start + interval, 1))
        assertEquals(0L, ReminderTiming.next(start, end, start + 2 * interval, 2))
    }
}
