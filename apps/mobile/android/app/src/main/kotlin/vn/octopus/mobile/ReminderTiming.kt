package vn.octopus.mobile

/** Timestamp arithmetic only. Missed intervals coalesce into a single reminder. */
object ReminderTiming {
    const val INTERVAL = 40 * 60_000L
    fun active(start: Long, end: Long, now: Long) =
        start > 0 && end - start in 1..(480 * 60_000L) && now >= start && now < end

    fun due(start: Long, end: Long, now: Long, delivered: Long): Long {
        if (!active(start, end, now)) return 0
        val boundary = (now - start) / INTERVAL
        return if (boundary > delivered) boundary else 0
    }

    fun next(start: Long, end: Long, now: Long, delivered: Long): Long {
        if (!active(start, end, now)) return 0
        if (due(start, end, now, delivered) > 0) return now + 1000
        val at = start + (maxOf(delivered, (now - start) / INTERVAL) + 1) * INTERVAL
        return if (at < end) at else 0
    }
}
