package vn.octopus.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.system.Os
import android.system.OsConstants
import android.system.ErrnoException

/** Local packet sink. No remote VPN server, packet persistence, or traffic inspection. */
class FocusVpnService : VpnService() {
    companion object {
        @Volatile var blocking = false; private set
        @Volatile var running = false; private set
        @Volatile var droppedPackets = 0L; private set
        private var instance: FocusVpnService? = null
        fun routed(context: Context): Boolean {
            val cm = context.getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            return blocking && cm.getNetworkCapabilities(cm.activeNetwork)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }
        fun sync(context: Context) {
            val state = ProtectionState.state(context)
            val needed = ProtectionState.period(context, state)?.strict == true && ProtectionState.options(state).optBoolean("blockInternet", true)
            if (needed && prepare(context) == null) {
                try {
                    val intent = Intent(context, FocusVpnService::class.java)
                    if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                } catch (e: Exception) { ProtectionState.prefs(context).edit().putString("error", "Chưa khởi động được VPN: ${e.javaClass.simpleName}").apply() }
            } else {
                instance?.shutdown()
                context.stopService(Intent(context, FocusVpnService::class.java))
            }
        }
    }
    private var tunnel: ParcelFileDescriptor? = null
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            val state = ProtectionState.state(this@FocusVpnService)
            if (ProtectionState.period(this@FocusVpnService, state)?.strict != true || !ProtectionState.options(state).optBoolean("blockInternet", true)) { shutdown(); return }
            handler.postDelayed(this, 1000)
        }
    }
    override fun onCreate() { super.onCreate(); instance = this; startNotice() }
    private fun startNotice() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("focus_network", "Bảo vệ kết nối khi tập trung", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "focus_network") else @Suppress("DEPRECATION") Notification.Builder(this))
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock).setContentTitle("Octopus · Tập trung sâu")
            .setContentText("VPN cục bộ chặn Internet. Chạm để xem hoặc kết thúc phiên.").setContentIntent(open).setOngoing(true).build()
        startForeground(310, notification); running = true
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startNotice()
        val state = ProtectionState.state(this)
        if (ProtectionState.period(this, state)?.strict != true || !ProtectionState.options(state).optBoolean("blockInternet", true)) { shutdown(); return START_NOT_STICKY }
        if (tunnel == null) {
            try {
                val builder = Builder().setBlocking(false).setSession("Octopus · Chặn Internet").setMtu(1500)
                    .addAddress("10.77.0.1", 32).addAddress("fd77::1", 128)
                    .addRoute("0.0.0.0", 0).addRoute("::", 0).addDnsServer("10.77.0.2")
                for (pkg in ProtectionState.phonePackages(this)) {
                    try { builder.addDisallowedApplication(pkg) } catch (_: android.content.pm.PackageManager.NameNotFoundException) {}
                }
                tunnel = builder.establish() ?: error("VPN permission missing")
                droppedPackets = 0
                blocking = true
                ProtectionState.prefs(this).edit().remove("error").apply()
                ProtectionState.record(this, "network_blocked")
                val descriptor = tunnel!!
                Thread({
                    try {
                        val packet = ByteArray(32767)
                        while (blocking && tunnel === descriptor) {
                            try {
                                if (Os.read(descriptor.fileDescriptor, packet, 0, packet.size) > 0) droppedPackets++
                            } catch (e: ErrnoException) {
                                if (e.errno == OsConstants.EAGAIN) Thread.sleep(25) else throw e
                            }
                        }
                    } catch (_: Exception) {
                        if (tunnel === descriptor && blocking) handler.post {
                            ProtectionState.prefs(this).edit().putString("error", "VPN đã dừng. Mở lại phiên tập trung để khôi phục.").apply(); shutdown()
                        }
                    }
                }, "octopus-local-vpn").apply { isDaemon = true; start() }
            } catch (e: Exception) {
                ProtectionState.prefs(this).edit().putString("error", "Không chặn được mạng: ${e.javaClass.simpleName}").apply()
                shutdown()
            }
        }
        handler.removeCallbacks(tick); handler.post(tick)
        return START_NOT_STICKY
    }
    override fun onRevoke() {
        ProtectionState.record(this, "vpn_revoked")
        ProtectionState.prefs(this).edit().putString("error", "Quyền VPN đã bị thu hồi; Internet không còn bị chặn.").apply()
        shutdown(); super.onRevoke()
    }
    private fun shutdown() {
        // Android may keep a VPN service bound after stopSelf. Close the TUN now,
        // not only in onDestroy, so session expiry always restores connectivity.
        val wasBlocking = blocking
        handler.removeCallbacksAndMessages(null); blocking = false; running = false
        try { tunnel?.close() } catch (_: Exception) {}; tunnel = null
        if (wasBlocking) ProtectionState.record(this, "network_restored")
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    override fun onDestroy() { shutdown(); instance = null; super.onDestroy() }
}
