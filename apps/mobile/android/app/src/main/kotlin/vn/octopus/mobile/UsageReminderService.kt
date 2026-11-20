package vn.octopus.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.PowerManager
import android.media.AudioAttributes
import android.net.Uri

/** An explicitly enabled, visible foreground service. It reads package transitions only. */
class UsageReminderService : Service() {
    companion object {
        private const val MONITOR = "octopus_usage_monitor"
        private const val REMINDER = "octopus_usage_breaks"
        private const val STRONG_REMINDER = "octopus_usage_breaks_strong_v1"
        private val strongVibration = longArrayOf(0, 350, 150, 350, 150, 650)
        private const val MONITOR_ID = 451
        private const val REMINDER_ID = 452
        @Volatile var running = false; private set

        private fun manager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        private fun strong(context: Context) = ProtectionState.options(ProtectionState.state(context)).optBoolean("usageReminderStrong", false)
        private fun reminderChannel(context: Context) = if (strong(context)) STRONG_REMINDER else REMINDER
        private fun strongSound(context: Context) = Uri.parse("android.resource://${context.packageName}/raw/${context.resources.getResourceEntryName(R.raw.usage_alert)}")
        private fun strongAudio() = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        private fun channels(context: Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                manager(context).createNotificationChannel(NotificationChannel(MONITOR, "Đang nhắc dùng ứng dụng lâu", NotificationManager.IMPORTANCE_LOW))
                manager(context).createNotificationChannel(NotificationChannel(REMINDER, "Nhắc nghỉ khi dùng ứng dụng lâu", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Nhắc sau mỗi khoảng dùng liên tục do bạn chọn."
                    enableVibration(true)
                })
                manager(context).createNotificationChannel(NotificationChannel(STRONG_REMINDER, "Nhắc dùng app lâu · mạnh", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Âm báo khoảng 3 giây theo âm lượng báo thức, rung dài. Chỉ dùng khi bạn chọn nhắc mạnh."
                    setSound(strongSound(context), strongAudio())
                    enableVibration(true)
                    vibrationPattern = strongVibration
                })
            }
        }
        private fun enabled(context: Context) = ProtectionState.options(ProtectionState.state(context)).optBoolean("usageReminders", false)
        private fun allowed(context: Context): Boolean {
            channels(context)
            return manager(context).areNotificationsEnabled() &&
                (Build.VERSION.SDK_INT < 26 || manager(context).getNotificationChannel(reminderChannel(context)).importance > 0)
        }
        fun status(context: Context): Map<String, Any> = mapOf(
            "enabled" to enabled(context), "running" to running,
            "usageGranted" to UsageReader.granted(context), "notifications" to allowed(context),
            "error" to ProtectionState.prefs(context).getString("usageReminderError", "").orEmpty())

        fun sync(context: Context) {
            if (!enabled(context) || !UsageReader.granted(context) || !allowed(context)) {
                context.stopService(Intent(context, UsageReminderService::class.java)); return
            }
            try {
                val intent = Intent(context, UsageReminderService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                ProtectionState.prefs(context).edit().remove("usageReminderError").apply()
            } catch (_: RuntimeException) {
                ProtectionState.prefs(context).edit().putString("usageReminderError", "Mở Octopus và bật lại nhắc dùng app lâu để tiếp tục.").apply()
            }
        }
        private fun open(context: Context) = PendingIntent.getActivity(context, MONITOR_ID,
            Intent(context, MainActivity::class.java).putExtra("octopus_action", "usage").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        fun notifyBreak(context: Context, pkg: String? = null, elapsed: Long = 0) {
            check(allowed(context)) { "Cho phép thông báo trước khi gửi lời nhắc" }
            val stronger = strong(context)
            val message = if (stronger && pkg == null) "Đây là mẫu nhắc mạnh. Đến mốc sử dụng, hãy rời ứng dụng, đặt điện thoại xuống và nghỉ 1 phút."
                else if (stronger) "Bạn đã dùng ${UsageReader.label(context, pkg!!)} liên tục ${elapsed / 60000} phút. Dừng lại, đặt điện thoại xuống và nghỉ mắt 1 phút trước khi tiếp tục."
                else if (pkg == null) "Thông báo thử đã hoạt động. Bạn sẽ nhận lời nhắc khi dùng một ứng dụng đủ lâu."
                else "Bạn đã dùng ${UsageReader.label(context, pkg)} liên tục ${elapsed / 60000} phút. Nghỉ mắt hoặc đứng dậy một chút nhé."
            @Suppress("DEPRECATION")
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, reminderChannel(context)) else Notification.Builder(context)
            builder.setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(if (stronger) "Octopus · Dừng lại 1 phút" else "Octopus · Nghỉ một chút nhé").setContentText(message)
                .setStyle(Notification.BigTextStyle().bigText(message)).setContentIntent(open(context))
                .setCategory(Notification.CATEGORY_REMINDER)
                .setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).setPriority(Notification.PRIORITY_HIGH)
            if (stronger) {
                builder.setSound(strongSound(context), strongAudio()).setVibrate(strongVibration)
                    .addAction(android.R.drawable.ic_menu_view, "Mở Octopus", open(context))
            } else builder.setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
            manager(context).notify(REMINDER_ID, builder.build())
        }
    }

    private val thread = HandlerThread("octopus-usage-reminders")
    private lateinit var handler: Handler
    private val tracker = UsageReminderTracker()
    private var lastPoll = System.currentTimeMillis() - 86400000L
    private val recent = linkedSetOf<String>()
    private val tick = object : Runnable {
        override fun run() {
            if (!enabled(this@UsageReminderService) || !UsageReader.granted(this@UsageReminderService) || !allowed(this@UsageReminderService)) { stopSelf(); return }
            try {
                val now = System.currentTimeMillis()
                val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
                val events = manager.queryEvents(lastPoll - 1000, now)
                val event = UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    val key = "${event.timeStamp}:${event.eventType}:${event.packageName}"
                    if (recent.add(key)) tracker.event(event.eventType, event.packageName.orEmpty(), event.timeStamp)
                }
                lastPoll = now
                while (recent.size > 128) recent.remove(recent.first())
                val screenOn = (getSystemService(POWER_SERVICE) as PowerManager).isInteractive
                val locked = (getSystemService(KEYGUARD_SERVICE) as android.app.KeyguardManager).isKeyguardLocked
                if (!screenOn || locked) tracker.reset()
                val minutes = ProtectionState.options(ProtectionState.state(this@UsageReminderService)).optInt("usageReminderMinutes", 15).coerceIn(15, 60)
                val duration = tracker.due(now, minutes * 60000L)
                val pkg = tracker.packageName
                if (duration > 0 && pkg != null && !ProtectionState.allowed(this@UsageReminderService, pkg)) {
                    val delivery = "$pkg:${tracker.startedAt}:$duration"
                    val preferences = ProtectionState.prefs(this@UsageReminderService)
                    if (preferences.getString("lastUsageReminder", "") != delivery) {
                        if (preferences.edit().putString("lastUsageReminder", delivery).commit()) {
                            notifyBreak(this@UsageReminderService, pkg, duration)
                            ProtectionState.record(this@UsageReminderService, "usage_reminder", pkg)
                        }
                    }
                }
            } catch (_: RuntimeException) {
                ProtectionState.prefs(this@UsageReminderService).edit().putString("usageReminderError", "Chưa đọc được thời gian dùng app. Mở Octopus để kiểm tra lại quyền.").apply()
            }
            handler.postDelayed(this, 15000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        channels(this)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, MONITOR) else Notification.Builder(this)
        startForeground(MONITOR_ID, builder.setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentTitle("Octopus · Nhắc dùng app lâu đang bật")
            .setContentText("Chạm để đổi thời gian nhắc hoặc tắt.").setContentIntent(open(this)).setOngoing(true).build())
        running = true
        thread.start()
        handler = Handler(thread.looper)
        handler.post(tick)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        thread.quitSafely()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
