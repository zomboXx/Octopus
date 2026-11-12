package vn.octopus.mobile

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Observes package transitions only. Never retrieves text or captures screens. */
class FocusAccessibilityService : AccessibilityService() {
    companion object { var instance: FocusAccessibilityService? = null; private set }
    private val handler = Handler(Looper.getMainLooper())
    private var foreground = ""
    private var widgetMinute = -1L
    private var view: LinearLayout? = null
    private var heading: TextView? = null
    private var description: TextView? = null
    private var tone: ToneGenerator? = null
    private var muted = false
    private var cycleStarted = 0L
    private var cyclePeriod = ""
    private var cyclePackage = ""
    var alertActive = false; private set
    val overlayVisible get() = view != null
    private val tick = object : Runnable {
        override fun run() {
            refresh()
            val minute = System.currentTimeMillis() / 60000
            if (minute != widgetMinute) { widgetMinute = minute; BrainWidgets.update(this@FocusAccessibilityService) }
            handler.postDelayed(this, 1000)
        }
    }
    override fun onServiceConnected() {
        instance = this
        ProtectionState.record(this, "monitor_connected")
        handler.post(tick)
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        // Keyboards and transient system windows are not foreground app changes.
        // In particular, typing a reason inside Octopus must not block the IME.
        if (pkg == "com.android.systemui") return
        val input = getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
        if (input.inputMethodList.any { it.packageName == pkg }) return
        // Our overlay emits accessibility window events too; those are not app switches.
        if (pkg == packageName && event.className?.toString() != MainActivity::class.java.name) return
        foreground = pkg
        refresh()
    }
    fun refresh() {
        val state = ProtectionState.state(this)
        val period = ProtectionState.period(this, state)
        val interactive = (getSystemService(POWER_SERVICE) as PowerManager).isInteractive
        val locked = (getSystemService(KEYGUARD_SERVICE) as android.app.KeyguardManager).isKeyguardLocked
        val violation = interactive && !locked && period != null && foreground.isNotEmpty() &&
            !ProtectionState.allowed(this, foreground) &&
            (period.strict || ProtectionState.restricted(state, foreground))
        if (!violation || period == null) {
            clearOverlay(); cycleStarted = 0; cyclePeriod = ""; return
        }
        val now = android.os.SystemClock.elapsedRealtime()
        if (cycleStarted == 0L || cyclePeriod != period.id || cyclePackage != foreground || now - cycleStarted >= 90000) {
            cycleStarted = now; cyclePeriod = period.id; cyclePackage = foreground; muted = false
            ProtectionState.record(this, "interruption", foreground, period)
        }
        val elapsed = now - cycleStarted
        alertActive = elapsed < 30000
        if (!alertActive && !period.strict) { clearOverlay(); return }
        if (view == null) showOverlay()
        view?.setBackgroundColor(if (alertActive) Color.rgb(174, 26, 38) else Color.rgb(19, 33, 57))
        heading?.text = if (alertActive) "Đã đến giờ tập trung" else "Đang bảo vệ phiên tập trung"
        description?.text = "${period.title}\n${UsageReader.label(this, foreground)} đang bị hạn chế.\n" +
            if (alertActive) "Cảnh báo còn ${((30000 - elapsed + 999) / 1000)} giây.\nSau đó nghỉ âm báo 60 giây." else "Ứng dụng này vẫn bị chặn.\nCảnh báo tiếp theo sau ${((90000 - elapsed + 999) / 1000)} giây."
        if (alertActive && !muted && ProtectionState.options(state).optBoolean("sound", true)) {
            try {
                if (tone == null) tone = ToneGenerator(AudioManager.STREAM_MUSIC, 45)
                tone?.startTone(ToneGenerator.TONE_PROP_BEEP2, 250)
            } catch (_: Exception) { /* Silent protection still works. */ }
        } else tone?.stopTone()
    }
    private fun showOverlay() {
        val padding = (24 * resources.displayMetrics.density).toInt()
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(padding, padding, padding, padding)
            importantForAccessibility = android.view.View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }
        heading = TextView(this).apply { textSize = 28f; setTextColor(Color.WHITE); gravity = Gravity.CENTER }
        description = TextView(this).apply { textSize = 18f; setTextColor(Color.WHITE); gravity = Gravity.CENTER; setPadding(0, padding, 0, padding) }
        panel.addView(heading); panel.addView(description)
        fun button(text: String, action: () -> Unit) { panel.addView(Button(this).apply { this.text = text; setOnClickListener { action() } }) }
        button("Quay về màn hình chính") { performGlobalAction(GLOBAL_ACTION_HOME); foreground = ""; clearOverlay() }
        button("Tắt âm báo lần này") { muted = true; tone?.stopTone(); ProtectionState.record(this, "mute", foreground) }
        button("Gọi điện / khẩn cấp") {
            foreground = ""; clearOverlay()
            try { startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) { performGlobalAction(GLOBAL_ACTION_HOME) }
        }
        button("Mở Octopus") {
            foreground = ""; clearOverlay()
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        }
        val params = WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, PixelFormat.OPAQUE)
        val container = LinearLayout(this).apply {
            addView(android.widget.ScrollView(this@FocusAccessibilityService).apply {
                isFillViewport = true
                addView(panel, android.widget.FrameLayout.LayoutParams(-1, -2))
            }, LinearLayout.LayoutParams(-1, -1))
        }
        try { (getSystemService(WINDOW_SERVICE) as WindowManager).addView(container, params); view = container }
        catch (e: Exception) { ProtectionState.prefs(this).edit().putString("error", "Không hiện được màn hình bảo vệ: ${e.javaClass.simpleName}").apply() }
    }
    private fun clearOverlay() {
        tone?.stopTone(); alertActive = false
        view?.let { try { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it) } catch (_: Exception) {} }
        view = null; heading = null; description = null
    }
    override fun onInterrupt() { clearOverlay() }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null); clearOverlay(); tone?.release(); tone = null
        instance = null; super.onDestroy()
    }
}
