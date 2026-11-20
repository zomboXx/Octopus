package vn.octopus.mobile

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings

/** Local reminders, independent of VPN/accessibility and Flutter's foreground timer. */
object WellbeingReminders {
    private const val CHANNEL = "octopus_wellbeing_v1"
    private const val ID = 442
    private fun prefs(context: Context) = context.getSharedPreferences("octopus_wellbeing", 0)
    private fun manager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun alarm(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private fun pending(context: Context) = PendingIntent.getBroadcast(context, ID,
        Intent(context, WellbeingReceiver::class.java).setAction("vn.octopus.WELLBEING"),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun channel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Nghỉ nhẹ và uống nước", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Nhắc chăm sóc bản thân sau mỗi 40 phút trong phiên tập trung dài."
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }
            manager(context).createNotificationChannel(channel)
        }
    }

    fun status(context: Context): Map<String, Any> {
        channel(context)
        val nm = manager(context)
        val c = if (Build.VERSION.SDK_INT >= 26) nm.getNotificationChannel(CHANNEL) else null
        return mapOf("allowed" to (nm.areNotificationsEnabled() && (c == null || c.importance > 0)),
            "sound" to (Build.VERSION.SDK_INT < 26 || c?.sound != null),
            "headsUp" to (Build.VERSION.SDK_INT < 26 || (c?.importance ?: 0) >= NotificationManager.IMPORTANCE_HIGH))
    }

    fun openSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName).putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL)
        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${context.packageName}"))
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    @Synchronized fun sync(context: Context, force: Boolean = false) {
        val state = ProtectionState.state(context)
        val start = ProtectionState.time(state.optString("focusStart"))
        val end = ProtectionState.time(state.optString("focusEnd"))
        val now = System.currentTimeMillis()
        val pref = prefs(context)
        val session = "$start:$end"
        if (pref.getString("session", "") != session) {
            pref.edit().putString("session", session).putLong("delivered", 0).putLong("scheduledAt", 0).commit()
            manager(context).cancel(ID)
        }
        val enabled = state.optBoolean("wellbeingReminders", true) &&
            (!state.optBoolean("focusProtected", true) || ProtectionState.prefs(context).getLong("cancelledFocusEnd", 0) != end)
        val at = if (enabled) ReminderTiming.next(start, end, now, pref.getLong("delivered", 0)) else 0
        if (at == 0L) {
            alarm(context).cancel(pending(context))
            pref.edit().putLong("scheduledAt", 0).apply()
            manager(context).cancel(ID)
            return
        }
        // Do not postpone an already queued alarm when an unrelated task is saved.
        if (!force && pref.getLong("scheduledAt", 0) > 0) return
        alarm(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context))
        pref.edit().putLong("scheduledAt", at).apply()
    }

    @Synchronized fun receive(context: Context) {
        val state = ProtectionState.state(context)
        val start = ProtectionState.time(state.optString("focusStart"))
        val end = ProtectionState.time(state.optString("focusEnd"))
        val pref = prefs(context)
        val session = "$start:$end"
        val due = if (state.optBoolean("wellbeingReminders", true) && pref.getString("session", "") == session &&
            (!state.optBoolean("focusProtected", true) || ProtectionState.prefs(context).getLong("cancelledFocusEnd", 0) != end))
            ReminderTiming.due(start, end, System.currentTimeMillis(), pref.getLong("delivered", 0)) else 0
        pref.edit().putLong("scheduledAt", 0).commit()
        if (due > 0) {
            // Persist before posting: no duplicate sound on repeated broadcasts/reloads.
            pref.edit().putLong("delivered", due).commit()
            if (status(context)["allowed"] == true) {
                val open = PendingIntent.getActivity(context, ID,
                    Intent(context, MainActivity::class.java).putExtra("octopus_action", "wellbeing")
                        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val text = "Uống một ít nước, đứng dậy và thả lỏng vai trong 1–2 phút. Phiên tập trung vẫn tiếp tục."
                @Suppress("DEPRECATION")
                val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
                val notification = builder.setSmallIcon(android.R.drawable.ic_popup_reminder)
                    .setContentTitle("Đã tập trung ${due * 40} phút · Nghỉ nhẹ nhé")
                    .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text))
                    .setCategory(Notification.CATEGORY_REMINDER).setVisibility(Notification.VISIBILITY_PRIVATE)
                    .setPriority(Notification.PRIORITY_HIGH).setDefaults(Notification.DEFAULT_SOUND)
                    .setContentIntent(open).setAutoCancel(true).setTimeoutAfter(5 * 60_000L).build()
                try { manager(context).notify(ID, notification) } catch (_: SecurityException) { /* Permission revoked mid-delivery. */ }
            }
        }
        sync(context)
    }
}

class WellbeingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "vn.octopus.WELLBEING") WellbeingReminders.receive(context)
        else WellbeingReminders.sync(context, force = true)
    }
}
