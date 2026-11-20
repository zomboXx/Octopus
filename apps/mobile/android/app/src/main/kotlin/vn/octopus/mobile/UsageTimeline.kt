package vn.octopus.mobile

data class UsageInterval(val packageName: String, val start: Long, val end: Long)

/** Reconstructs one foreground app at a time, including screen-off boundaries. */
class UsageTimeline {
    private var active: String? = null
    private var since = 0L
    val intervals = mutableListOf<UsageInterval>()

    private fun close(at: Long) {
        active?.let { if (at > since && it != "com.android.systemui") intervals.add(UsageInterval(it, since, at)) }
        active = null
    }

    fun event(type: Int, packageName: String, at: Long) {
        when (type) {
            1 -> { close(at); active = packageName; since = at }
            2 -> if (active == packageName) close(at)
            16, 17 -> close(at)
            26, 27 -> active = null
        }
    }

    fun finish(at: Long) { close(at) }
}

/** Continuous-app reminders reset on app switches and screen-off. */
class UsageReminderTracker {
    var packageName: String? = null; private set
    private var since = 0L
    val startedAt get() = since
    private var delivered = 0L
    private var pausedAt: Long? = null

    fun event(type: Int, pkg: String, at: Long) {
        when (type) {
            1 -> {
                val resumedQuickly = packageName == pkg && (pausedAt == null || at - pausedAt!! <= 2000)
                if (!resumedQuickly) { packageName = pkg; since = at; delivered = 0 }
                pausedAt = null
            }
            2 -> if (packageName == pkg) pausedAt = at
            16, 17, 26, 27 -> reset()
        }
    }

    fun reset() { packageName = null; since = 0; delivered = 0; pausedAt = null }

    fun due(now: Long, interval: Long): Long {
        if (packageName == null || pausedAt != null || interval <= 0 || now < since) return 0
        val elapsedBoundary = (now - since) / interval * interval
        if (elapsedBoundary <= delivered) return 0
        delivered = elapsedBoundary
        return elapsedBoundary
    }
}
