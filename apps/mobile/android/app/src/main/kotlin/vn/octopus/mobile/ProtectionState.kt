package vn.octopus.mobile

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.telecom.TelecomManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

data class ProtectedPeriod(val id: String, val title: String, val end: Long, val strict: Boolean)

object ProtectionState {
    fun state(context: Context): JSONObject = try { JSONObject(context.getSharedPreferences("octopus_prototype", 0).getString("state", "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
    fun prefs(context: Context) = context.getSharedPreferences("octopus_guard", 0)
    fun options(state: JSONObject) = state.optJSONObject("protection") ?: JSONObject()
    fun time(value: String): Long = try {
        val normalized = value.replace(Regex("\\.\\d+"), "")
        val format = if (normalized.endsWith("Z") || Regex("[+-]\\d\\d:\\d\\d$").containsMatchIn(normalized)) "yyyy-MM-dd'T'HH:mm:ssXXX" else "yyyy-MM-dd'T'HH:mm:ss"
        SimpleDateFormat(format, Locale.US).apply { isLenient = false }.parse(normalized)?.time ?: 0L
    } catch (_: Exception) { 0L }

    fun period(context: Context, state: JSONObject = state(context), now: Long = System.currentTimeMillis()): ProtectedPeriod? {
        if (!options(state).optBoolean("enabled") || prefs(context).getBoolean("paused", false)) return null
        val start = time(state.optString("focusStart")); val end = time(state.optString("focusEnd"))
        if (start <= now && end > now && end - start in 1..(480 * 60000L) && prefs(context).getLong("cancelledFocusEnd", 0) != end) {
            return ProtectedPeriod("focus:$end", "Phiên tập trung sâu", end, true)
        }
        val plan = state.optJSONArray("plan") ?: JSONArray()
        for (i in 0 until (if (options(state).optBoolean("watchSchedule", true)) plan.length() else 0)) {
            val p = plan.optJSONObject(i) ?: continue
            val s = time(p.optString("start")); val e = time(p.optString("end"))
            if (!p.optBoolean("done") && p.optString("kind") != "break" && s <= now && e > now && e - s in 1..(480 * 60000L)) {
                return ProtectedPeriod("plan:${p.optString("id")}:$s", p.optString("title", "Lịch đã hẹn"), e, false)
            }
        }
        if (options(state).optBoolean("watchFixed", true)) {
            val cal = Calendar.getInstance().apply { timeInMillis = now }
            val weekday = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val fixed = state.optJSONArray("commitments") ?: JSONArray()
            for (i in 0 until fixed.length()) {
                val c = fixed.optJSONObject(i) ?: continue
                val days = c.optJSONArray("weekdays") ?: continue
                if ((0 until days.length()).any { days.optInt(it) == weekday } && minute >= c.optInt("startMinute") && minute < c.optInt("endMinute")) {
                    val finish = (cal.clone() as Calendar).apply {set(Calendar.HOUR_OF_DAY, c.optInt("endMinute") / 60); set(Calendar.MINUTE, c.optInt("endMinute") % 60); set(Calendar.SECOND, 0)}.timeInMillis
                    return ProtectedPeriod("fixed:${c.optString("id")}:${cal.get(Calendar.DAY_OF_YEAR)}", c.optString("title"), finish, false)
                }
            }
        }
        return null
    }

    fun phonePackages(context: Context): Set<String> {
        val known = mutableSetOf("com.android.phone", "com.android.server.telecom", "com.android.dialer", "com.google.android.dialer", "com.android.incallui", "com.android.emergency", "com.google.android.apps.safetyhub")
        (context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)?.defaultDialerPackage?.let { known.add(it) }
        return known
    }
    fun allowed(context: Context, pkg: String): Boolean {
        if (pkg == context.packageName || pkg == "com.android.systemui" || pkg == "com.android.settings" || phonePackages(context).contains(pkg)) return true
        @Suppress("DEPRECATION")
        val homes = context.packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
        return homes.any { it.activityInfo.packageName == pkg } || pkg.contains("permissioncontroller") || pkg == "com.android.vpndialogs"
    }
    fun restricted(state: JSONObject, pkg: String): Boolean {
        val entries = state.optJSONArray("restricted") ?: JSONArray()
        return (0 until entries.length()).any { entries.optString(it) == pkg }
    }
    @Synchronized fun record(context: Context, type: String, pkg: String = "", period: ProtectedPeriod? = null, note: String = "") {
        val prefs = prefs(context)
        val old = try { JSONArray(prefs.getString("events", "[]")) } catch (_: Exception) { JSONArray() }
        val next = JSONArray()
        val cutoff = System.currentTimeMillis() - 30L * 86400000
        for (i in maxOf(0, old.length() - 499) until old.length()) {
            val item = old.optJSONObject(i) ?: continue
            if (item.optLong("at") >= cutoff) next.put(item)
        }
        next.put(JSONObject().put("at", System.currentTimeMillis()).put("type", type).put("package", pkg)
            .put("periodId", period?.id ?: "").put("title", period?.title ?: "").put("note", note.take(200)))
        prefs.edit().putString("events", next.toString()).apply()
    }
    fun status(context: Context): Map<String, Any> {
        val state = state(context)
        return mapOf("accessibility" to (FocusAccessibilityService.instance != null), "vpnPrepared" to (VpnService.prepare(context) == null),
            "networkBlocked" to FocusVpnService.routed(context), "vpnService" to FocusVpnService.running, "droppedPackets" to FocusVpnService.droppedPackets,
            "enabled" to options(state).optBoolean("enabled"), "paused" to prefs(context).getBoolean("paused", false),
            "overlayVisible" to (FocusAccessibilityService.instance?.overlayVisible ?: false),
            "alertActive" to (FocusAccessibilityService.instance?.alertActive ?: false),
            "activeTitle" to (period(context, state)?.title ?: ""),
            "cancelledFocusEnd" to prefs(context).getLong("cancelledFocusEnd", 0),
            "error" to (prefs(context).getString("error", "") ?: ""))
    }
}
