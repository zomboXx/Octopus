package vn.octopus.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var vpnResult: MethodChannel.Result? = null
    private var photoResult: MethodChannel.Result? = null
    private var speechResult: MethodChannel.Result? = null
    private var wellbeingPermissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WellbeingReminders.sync(this, force = true)
        val prefs = getSharedPreferences("octopus_prototype", Context.MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.octopus/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readState" -> result.success(prefs.getString("state", null))
                    "writeState" -> {
                        val value = call.arguments as? String
                        if (value == null) { result.error("invalid", "Missing data", null) }
                        else worker.execute {
                            val ok = prefs.edit().putString("state", value).commit()
                            runOnUiThread {
                                if (ok) { WellbeingReminders.sync(this); BrainWidgets.update(this); FocusAccessibilityService.instance?.refresh(); FocusVpnService.sync(this); result.success(null) }
                                else result.error("storage", "Could not save", null)
                            }
                        }
                    }
                    "wellbeingStatus" -> result.success(WellbeingReminders.status(this))
                    "openWellbeingSettings" -> { WellbeingReminders.openSettings(this); result.success(null) }
                    "requestWellbeingPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            if (wellbeingPermissionResult != null) result.error("busy", "Permission dialog already open", null)
                            else { wellbeingPermissionResult = result; requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1046) }
                        } else result.success(WellbeingReminders.status(this))
                    }
                    "guardStatus" -> result.success(ProtectionState.status(this))
                    "guardEvents" -> result.success(ProtectionState.prefs(this).getString("events", "[]"))
                    "installedApps" -> result.success(UsageReader.installed(this))
                    "openAccessibility" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null)
                    }
                    "resumeProtection" -> {
                        ProtectionState.prefs(this).edit().putBoolean("paused", false).apply()
                        FocusAccessibilityService.instance?.refresh(); FocusVpnService.sync(this); result.success(null)
                    }
                    "cancelFocus" -> {
                        val end = ProtectionState.time(ProtectionState.state(this).optString("focusEnd"))
                        ProtectionState.prefs(this).edit().putLong("cancelledFocusEnd", end).apply()
                        val args = call.arguments as? Map<*, *>
                        WellbeingReminders.sync(this)
                        ProtectionState.record(this, if (args?.get("completed") == true) "work_completed" else "early_exit",
                            note = args?.get("reason") as? String ?: call.arguments as? String ?: "")
                        FocusAccessibilityService.instance?.refresh(); FocusVpnService.sync(this); result.success(null)
                    }
                    "prepareVpn" -> {
                        if (vpnResult != null) result.error("busy", "VPN dialog already open", null)
                        else {
                            val consent = android.net.VpnService.prepare(this)
                            if (consent == null) result.success(true)
                            else {
                                vpnResult = result
                                @Suppress("DEPRECATION")
                                startActivityForResult(consent, 1043)
                            }
                        }
                    }
                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1044)
                        result.success(null)
                    }
                    "widgetStatus" -> result.success(BrainWidgets.status(this))
                    "pinWidget" -> {
                        try { result.success(BrainWidgets.pin(this, call.arguments as String)) }
                        catch (e: Exception) { result.error("widget", e.message, null) }
                    }
                    "takeWidgetAction" -> {
                        val action = intent?.getStringExtra("octopus_action")
                        intent?.removeExtra("octopus_action")
                        result.success(action)
                    }
                    "openUsageAccess" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:$packageName")))
                            result.success(null)
                        } catch (e: Exception) { result.error("settings", e.message, null) }
                    }
                    "usage" -> worker.execute {
                        try { val data = UsageReader.read(this); runOnUiThread { result.success(data) } }
                        catch (e: Exception) { runOnUiThread { result.error("usage", e.message, null) } }
                    }
                    "pickImage" -> {
                        if (photoResult != null) { result.error("busy", "Image picker already open", null) }
                        else {
                            photoResult = result
                            try {
                                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "image/*"
                                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/webp"))
                                }
                                @Suppress("DEPRECATION")
                                startActivityForResult(intent, 1042)
                            } catch (e: Exception) { photoResult = null; result.error("picker", e.message, null) }
                        }
                    }
                    "recognizeSpeech" -> {
                        if (speechResult != null) result.error("busy", "Speech already open", null)
                        else {
                            speechResult = result
                            try {
                                val speech = Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                    putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                    putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, "vi-VN")
                                    putExtra(android.speech.RecognizerIntent.EXTRA_PROMPT, "Bạn muốn làm gì?")
                                    putExtra(android.speech.RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                                }
                                @Suppress("DEPRECATION")
                                startActivityForResult(speech, 1045)
                                android.util.Log.i("OctopusSpeech", "Recognition UI requested")
                            } catch (_: Exception) { speechResult = null; result.error("speech", "Không có dịch vụ nhận giọng nói", null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1046) { wellbeingPermissionResult?.success(WellbeingReminders.status(this)); wellbeingPermissionResult = null }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
    @Deprecated("Deprecated in Android, retained for FlutterActivity integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1043) {
            vpnResult?.success(resultCode == RESULT_OK); vpnResult = null; return
        }
        if (requestCode == 1045) {
            speechResult?.success(if (resultCode == RESULT_OK) data?.getStringArrayListExtra(android.speech.RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null)
            speechResult = null; return
        }
        if (requestCode != 1042) return
        val pending = photoResult ?: return
        photoResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { pending.success(null); return }
        worker.execute {
            var destination: File? = null
            try {
                val images = File(filesDir, "activity_images").apply { mkdirs() }
                destination = File(images, UUID.randomUUID().toString())
                contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input)
                    destination.outputStream().use { output ->
                        val buffer = ByteArray(8192)
                        var total = 0
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            require(total <= 8 * 1024 * 1024) { "Ảnh cần nhỏ hơn 8 MB." }
                            output.write(buffer, 0, count)
                        }
                    }
                }
                val savedPath = destination.absolutePath
                runOnUiThread { pending.success(savedPath) }
            } catch (e: Exception) {
                destination?.delete()
                runOnUiThread { pending.error("image", e.message, null) }
            }
        }
    }
    override fun onDestroy() {
        wellbeingPermissionResult?.error("closed", "Activity closed", null); wellbeingPermissionResult = null
        speechResult?.error("closed", "Activity closed", null); speechResult = null
        vpnResult?.error("closed", "Activity closed", null); vpnResult = null
        photoResult?.error("closed", "Activity closed", null)
        photoResult = null
        worker.shutdown()
        super.onDestroy()
    }
}
