package vn.octopus.mobile

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object UsageReader {
    fun granted(context: Context): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            else @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun label(context: Context, pkg: String): String = try {
        @Suppress("DEPRECATION")
        context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) { pkg }

    fun installed(context: Context): List<Map<String, String>> {
        @Suppress("DEPRECATION")
        val entries = context.packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
        return entries.map { it.activityInfo.packageName }.distinct().filter { it != context.packageName }
            .map { mapOf("package" to it, "name" to label(context, it)) }.sortedBy { it["name"] }
    }

    // Count the most recently foregrounded application, rather than summing
    // calendar aggregates that may include time outside the requested range.
    // Window events are device data; no UI text, URLs or content are collected.
    fun read(context: Context): Map<String, Any> {
        if (!granted(context)) return mapOf("granted" to false, "apps" to emptyList<Any>(), "days" to emptyList<Any>())
        val to = System.currentTimeMillis()
        val start = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -6)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val from = start.timeInMillis
        val boundaries = (0..7).map { n -> (start.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, n) }.timeInMillis }
        val dayApps = Array(7) { mutableMapOf<String, Long>() }
        fun add(pkg: String, begin: Long, end: Long) {
            if (pkg == "com.android.systemui" || end <= begin) return
            for (i in 0..6) {
                val duration = (minOf(end, boundaries[i + 1], to) - maxOf(begin, boundaries[i], from)).coerceAtLeast(0)
                if (duration > 0) dayApps[i][pkg] = (dayApps[i][pkg] ?: 0L) + duration
            }
        }
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = manager.queryEvents(from - 24 * 60 * 60 * 1000L, to)
        val event = UsageEvents.Event()
        var active: String? = null
        var activeSince = from
        var count = 0
        while (events.hasNextEvent()) {
            events.getNextEvent(event); count++
            val time = event.timeStamp
            when (event.eventType) {
                1 -> { // ACTIVITY_RESUMED / MOVE_TO_FOREGROUND (all supported APIs)
                    active?.let { add(it, activeSince, time) }
                    active = event.packageName
                    activeSince = time
                }
                2 -> if (active == event.packageName) { // ACTIVITY_PAUSED
                    active?.let { add(it, activeSince, time) }; active = null
                }
                16, 17 -> { // SCREEN_NON_INTERACTIVE, KEYGUARD_SHOWN
                    active?.let { add(it, activeSince, time) }; active = null
                }
                26, 27 -> active = null // shutdown/startup: don't invent a missing close time
            }
        }
        active?.let { add(it, activeSince, to) }
        val total = mutableMapOf<String, Long>()
        for (day in dayApps) for ((pkg, ms) in day) total[pkg] = (total[pkg] ?: 0L) + ms
        val names = total.keys.associateWith { label(context, it) }
        fun rows(values: Map<String, Long>) = values.entries.sortedByDescending { it.value }.map {
            mapOf("package" to it.key, "name" to (names[it.key] ?: it.key), "milliseconds" to it.value)
        }
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val days = dayApps.mapIndexed { i, values -> mapOf("date" to dateFormat.format(boundaries[i]),
            "milliseconds" to values.values.sum(), "apps" to rows(values)) }
        return mapOf("granted" to true, "from" to from, "to" to to, "apps" to rows(total), "days" to days,
            "totalMilliseconds" to total.values.sum(), "eventCount" to count, "source" to "android_usage_events")
    }
}
