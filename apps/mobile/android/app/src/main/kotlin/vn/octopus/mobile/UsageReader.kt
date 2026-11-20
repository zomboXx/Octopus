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
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream
import java.text.ParsePosition
import java.util.concurrent.ConcurrentHashMap

object UsageReader {
    private val labels = ConcurrentHashMap<String, String>()
    fun icon(context: Context, pkg: String): ByteArray? = try {
        val drawable = context.packageManager.getApplicationIcon(pkg)
        val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, 96, 96)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            bitmap.recycle()
            stream.toByteArray()
        }
    } catch (_: Exception) { null }
    fun granted(context: Context): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            else @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun label(context: Context, pkg: String): String = labels.getOrPut(pkg) {
        try {
            @Suppress("DEPRECATION")
            context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) { pkg }
    }

    fun installed(context: Context): List<Map<String, String>> {
        @Suppress("DEPRECATION")
        val entries = context.packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
        return entries.map { it.activityInfo.packageName }.distinct().filter { !ProtectionState.allowed(context, it) }
            .map { mapOf("package" to it, "name" to label(context, it)) }.sortedBy { it["name"] }
    }

    // Count the most recently foregrounded application, rather than summing
    // calendar aggregates that may include time outside the requested range.
    // Window events are device data; no UI text, URLs or content are collected.
    fun read(context: Context, requestedStart: String? = null, detailDay: String? = null): Map<String, Any> {
        if (!granted(context)) return mapOf("granted" to false, "apps" to emptyList<Any>(), "days" to emptyList<Any>())
        val now = System.currentTimeMillis()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
        val start = Calendar.getInstance().apply {
            firstDayOfWeek = Calendar.MONDAY
            add(Calendar.DAY_OF_YEAR, -(get(Calendar.DAY_OF_WEEK) + 5) % 7)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val requested = detailDay ?: requestedStart
        if (requested != null) {
            val position = ParsePosition(0)
            val parsed = dateFormat.parse(requested, position)
            require(parsed != null && position.index == requested.length && dateFormat.format(parsed) == requested) { "Ngày thống kê không hợp lệ" }
            start.time = parsed
            require(start.timeInMillis <= now) { "Chưa có lịch sử ở ngày tương lai" }
        }
        val from = start.timeInMillis
        val dayCount = if (detailDay != null) 1 else 7
        val boundaries = (0..dayCount).map { n -> (start.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, n) }.timeInMillis }
        val to = minOf(now, boundaries.last())
        val dayApps = Array(dayCount) { mutableMapOf<String, Long>() }
        val daySessions = Array(dayCount) { mutableListOf<Map<String, Any>>() }
        val observed = BooleanArray(dayCount)
        fun add(pkg: String, begin: Long, end: Long) {
            if (pkg == "com.android.systemui" || end <= begin) return
            for (i in 0 until dayCount) {
                val duration = (minOf(end, boundaries[i + 1], to) - maxOf(begin, boundaries[i], from)).coerceAtLeast(0)
                if (duration > 0) {
                    dayApps[i][pkg] = (dayApps[i][pkg] ?: 0L) + duration
                    if (detailDay != null) daySessions[i].add(mapOf("package" to pkg, "name" to label(context, pkg),
                        "start" to maxOf(begin, boundaries[i], from), "end" to minOf(end, boundaries[i + 1], to), "milliseconds" to duration))
                }
            }
        }
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = manager.queryEvents(from - 24 * 60 * 60 * 1000L, to)
        val event = UsageEvents.Event()
        val timeline = UsageTimeline()
        var count = 0
        while (events.hasNextEvent()) {
            events.getNextEvent(event); count++
            val time = event.timeStamp
            for (i in 0 until dayCount) if (time >= boundaries[i] && time < boundaries[i + 1]) observed[i] = true
            timeline.event(event.eventType, event.packageName ?: "", time)
        }
        timeline.finish(to)
        for (interval in timeline.intervals) add(interval.packageName, interval.start, interval.end)
        val aggregate = BooleanArray(dayCount)
        for (i in 0 until dayCount) {
            if (observed[i] || dayApps[i].isNotEmpty() || boundaries[i] >= now) continue
            // Android retains daily aggregates longer than individual events.
            val stats = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, boundaries[i], minOf(boundaries[i + 1], now)) ?: emptyList()
            for (stat in stats) {
                if (stat.totalTimeInForeground <= 0 || stat.packageName == "com.android.systemui" ||
                    stat.lastTimeUsed < boundaries[i] || stat.lastTimeUsed >= boundaries[i + 1]) continue
                dayApps[i][stat.packageName] = (dayApps[i][stat.packageName] ?: 0L) + stat.totalTimeInForeground
                aggregate[i] = true
            }
        }
        val total = mutableMapOf<String, Long>()
        for (day in dayApps) for ((pkg, ms) in day) total[pkg] = (total[pkg] ?: 0L) + ms
        val names = total.keys.associateWith { label(context, it) }
        fun rows(values: Map<String, Long>) = values.entries.sortedByDescending { it.value }.map {
            mapOf("package" to it.key, "name" to (names[it.key] ?: it.key), "milliseconds" to it.value)
        }
        val days = dayApps.mapIndexed { i, values -> mapOf("date" to dateFormat.format(boundaries[i]),
            "milliseconds" to values.values.sum(), "apps" to rows(values), "sessions" to daySessions[i],
            "available" to (observed[i] || values.isNotEmpty()), "aggregate" to aggregate[i], "future" to (boundaries[i] >= now)) }
        return mapOf("granted" to true, "from" to from, "to" to to, "apps" to rows(total), "days" to days,
            "totalMilliseconds" to total.values.sum(), "eventCount" to count, "source" to "android_usage_events")
    }
}
