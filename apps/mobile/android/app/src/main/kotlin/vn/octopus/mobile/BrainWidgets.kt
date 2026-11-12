package vn.octopus.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TasksWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = BrainWidgets.update(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = BrainWidgets.update(context)
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) BrainWidgets.update(context)
    }
}

class FocusWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = BrainWidgets.update(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = BrainWidgets.update(context)
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) BrainWidgets.update(context)
    }
}

object BrainWidgets {
    private fun component(context: Context, kind: String) = ComponentName(context,
        if (kind == "tasks") TasksWidget::class.java else FocusWidget::class.java)

    fun status(context: Context): Map<String, Any> {
        val manager = AppWidgetManager.getInstance(context)
        return mapOf("supported" to (Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported),
            "tasks" to manager.getAppWidgetIds(component(context, "tasks")).isNotEmpty(),
            "focus" to manager.getAppWidgetIds(component(context, "focus")).isNotEmpty())
    }

    fun pin(context: Context, kind: String): Boolean {
        require(kind == "tasks" || kind == "focus")
        val manager = AppWidgetManager.getInstance(context)
        if (Build.VERSION.SDK_INT < 26 || !manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(component(context, kind), null, null)
    }

    private fun launch(context: Context, action: String, code: Int) = PendingIntent.getActivity(context, code,
        Intent(context, MainActivity::class.java).apply {
            putExtra("octopus_action", action)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun publish(manager: AppWidgetManager, id: Int, views: RemoteViews, small: Boolean) {
        // MIN_WIDTH combines portrait and landscape bounds. Use the launcher's
        // actual SizeF variants, otherwise portrait cards can become too short.
        if (Build.VERSION.SDK_INT >= 31) {
            val options = manager.getAppWidgetOptions(id)
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                ?.filter { it.width > 0 && it.height > 0 }?.distinct()?.take(16)
            if (!sizes.isNullOrEmpty()) {
                val variants = sizes.associateWith { size ->
                    RemoteViews(views).apply {
                        val target = if (small) minOf(170f, size.width - 6f) else 170f
                        setViewLayoutHeight(R.id.widget_root, minOf(size.height - 6f, target).coerceIn(148f, 170f), TypedValue.COMPLEX_UNIT_DIP)
                    }
                }
                manager.updateAppWidget(id, RemoteViews(variants))
                return
            }
        }
        manager.updateAppWidget(id, views)
    }

    fun update(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val state = ProtectionState.state(context)
        val onboarded = state.optBoolean("onboardingComplete", false)
        val now = System.currentTimeMillis()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val clock = SimpleDateFormat("HH:mm", Locale.US)
        val today = dateFormat.format(Date(now))
        fun list(key: String): List<JSONObject> {
            val items = state.optJSONArray(key) ?: return emptyList()
            return (0 until items.length()).mapNotNull { items.optJSONObject(it) }
        }
        val tasks = list("tasks").filter { it.optString("date", it.optString("createdAt").take(10)) == today }
        val plan = list("plan").filter { it.optString("kind") != "break" && dateFormat.format(Date(ProtectionState.time(it.optString("start")))) == today }
        val work = (tasks + plan).sortedBy { if (it.has("start")) ProtectionState.time(it.optString("start")) else Long.MAX_VALUE }
        val pending = work.filter { !it.optBoolean("done") }
        val start = ProtectionState.time(state.optString("focusStart"))
        val end = ProtectionState.time(state.optString("focusEnd"))
        val active = start in 1..now && end > now && end - start in 1..(480 * 60000L) &&
            ProtectionState.prefs(context).getLong("cancelledFocusEnd", 0) != end
        val linked = pending.find { it.optString("id") == state.optString("focusTaskId") }
        val scheduled = pending.firstOrNull {
            val s = ProtectionState.time(it.optString("start"))
            s in 1..now && ProtectionState.time(it.optString("end")) > now
        }
        val current = if (active) linked else scheduled ?: pending.firstOrNull()
        val next = pending.firstOrNull { it !== current &&
            (!it.has("start") || ProtectionState.time(it.optString("start")) > now) }
            ?: pending.firstOrNull { it !== current }
        val finished = work.isNotEmpty() && pending.isEmpty()
        val countdownEnd = when { active -> end; scheduled != null -> ProtectionState.time(scheduled.optString("end")); else -> 0L }
        val showCountdown = onboarded && countdownEnd > now
        val openAction = if (active) "focus" else "tasks"
        val checkAction = if (current != null) "complete:${current.optString("id")}" else openAction
        val title = when {
            !onboarded -> "Mở Octopus để thiết lập"
            active -> linked?.optString("title") ?: "Phiên tập trung sâu"
            current != null -> current.optString("title")
            finished -> "Bạn đã hoàn thành hôm nay"
            else -> "Chọn một việc quan trọng"
        }
        val statusLabel = when {
            !onboarded -> "BẮT ĐẦU"
            active -> "ĐANG CHẠY"
            scheduled != null -> "ĐẾN GIỜ"
            current != null && ProtectionState.time(current.optString("start")) > now -> "SẮP TỚI"
            current != null -> "CHỜ BẠN"
            finished -> "ĐÃ XONG"
            else -> "HÔM NAY"
        }
        val nextLabel = if (next != null) {
            val time = ProtectionState.time(next.optString("start"))
            "Tiếp: " + (if (time > 0) "${clock.format(Date(time))} · " else "") + next.optString("title")
        } else if (active || current != null) "Tiếp: Một khoảng nghỉ nhỏ" else if (finished) "Lên việc cho ngày mai" else "Thêm việc cho ngày của bạn"
        for (id in manager.getAppWidgetIds(component(context, "tasks"))) {
            val views = RemoteViews(context.packageName, R.layout.widget_tasks).apply {
                setTextViewText(R.id.widget_title, if (work.isEmpty()) "Chưa có việc hôm nay" else "${work.count { it.optBoolean("done") }} / ${work.size} việc đã hoàn thành")
                setTextViewText(R.id.widget_body, title)
                setTextViewText(R.id.widget_state, statusLabel)
                setViewVisibility(R.id.widget_timer, if (showCountdown) View.VISIBLE else View.GONE)
                setChronometerCountDown(R.id.widget_timer, true)
                setChronometer(R.id.widget_timer, android.os.SystemClock.elapsedRealtime() + maxOf(0, countdownEnd - now), "· %s", showCountdown)
                setTextViewText(R.id.widget_next, nextLabel)
                setImageViewResource(R.id.widget_check, if (finished && !active) R.drawable.widget_done_icon else R.drawable.widget_check_icon)
                setContentDescription(R.id.widget_check, if (current == null) "Xem việc hôm nay" else "Hoàn thành ${current.optString("title")}")
                setOnClickPendingIntent(R.id.widget_check, launch(context, checkAction, 205))
                setOnClickPendingIntent(R.id.widget_add, launch(context, "add_task", 201))
                setOnClickPendingIntent(R.id.widget_body, launch(context, openAction, 206))
                setOnClickPendingIntent(R.id.widget_open, launch(context, openAction, 206))
                setContentDescription(R.id.widget_open, if (active) "Mở phiên tập trung" else "Xem công việc")
                setOnClickPendingIntent(R.id.widget_next_row, launch(context, if (work.isEmpty() || finished) "add_task" else "tasks", 208))
                setOnClickPendingIntent(R.id.widget_root, launch(context, "tasks", 202))
            }
            publish(manager, id, views, false)
        }
        for (id in manager.getAppWidgetIds(component(context, "focus"))) {
            val views = RemoteViews(context.packageName, R.layout.widget_focus).apply {
                setTextViewText(R.id.widget_add, if (active) "Trở lại\nphiên" else "30p\nFocus")
                setContentDescription(R.id.widget_add, if (active) "Mở phiên tập trung" else "Bắt đầu tập trung 30 phút")
                setOnClickPendingIntent(R.id.widget_root, launch(context, "add_task", 201))
                setOnClickPendingIntent(R.id.widget_prompt, launch(context, "add_task", 201))
                setOnClickPendingIntent(R.id.widget_open, launch(context, "tasks", 202))
                setOnClickPendingIntent(R.id.widget_add, launch(context, "start_focus", 204))
                setOnClickPendingIntent(R.id.widget_mic, launch(context, "voice_task", 207))
            }
            publish(manager, id, views, true)
        }
    }
}
