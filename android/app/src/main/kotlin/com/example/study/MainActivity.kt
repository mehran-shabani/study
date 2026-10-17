package com.example.study

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import android.view.WindowManager

class MainActivity: FlutterActivity() {
    private val backupFiles by lazy { BackupFiles(this) }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study/files")
            .setMethodCallHandler { call, result -> backupFiles.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study/settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "language") { result.notImplemented(); return@setMethodCallHandler }
                try {
                    val language = call.arguments as? String ?: "system"
                    require(language in listOf("system", "fa", "en"))
                    check(getSharedPreferences("awareness", MODE_PRIVATE).edit()
                        .putString("language", language).commit())
                    val prefs = getSharedPreferences("awareness", MODE_PRIVATE)
                    if (prefs.getBoolean("running", false) || prefs.getLong("breakEndsAt", 0L) > 0)
                        startAwareness(Intent(this, AwarenessService::class.java))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("settings_failed", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study/awareness")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("awareness", MODE_PRIVATE)
                try {
                    when (call.method) {
                        "isEnabled" -> result.success(prefs.getBoolean("enabled", true))
                        "soundSettings" -> result.success(mapOf(
                            "track" to prefs.getString("track", "off"),
                            "volume" to prefs.getFloat("volume", 0.25f).toDouble(),
                            "keepAwake" to prefs.getBoolean("keepAwake", false)))
                        "screenAwake" -> {
                            if (call.arguments == true)
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            result.success(null)
                        }
                        "setSound" -> {
                            val track = call.argument<String>("track") ?: "off"
                            require(track == "off" || track in FocusAudio.TRACKS)
                            val requestedVolume = call.argument<Number>("volume")?.toFloat() ?: 0.25f
                            require(requestedVolume.isFinite())
                            val volume = requestedVolume.coerceIn(0f, 0.6f)
                            check(prefs.edit().putString("track", track).putFloat("volume", volume)
                                .putBoolean("keepAwake", call.argument<Boolean>("keepAwake") == true).commit())
                            if (prefs.getBoolean("running", false)) {
                                requestNotifications()
                                startAwareness(Intent(this, AwarenessService::class.java))
                            }
                            result.success(null)
                        }
                        "sync" -> {
                            val running = call.argument<Boolean>("running") == true
                            val enabled = call.argument<Boolean>("enabled") == true
                            val session = call.argument<String>("sessionId") ?: ""
                            val elapsed = call.argument<Number>("elapsedMs")?.toLong() ?: 0L
                            val oldFocus = prefs.getLong("focusDeadline", 0L)
                            val focusDeadline = call.argument<Number>("focusDeadline")?.toLong() ?: 0L
                            val breakEnd = call.argument<Number>("breakEndsAt")?.toLong() ?: 0L
                            val editor = prefs.edit()
                                .putBoolean("enabled", enabled).putBoolean("running", running)
                                .putString("sessionId", session).putLong("elapsedMs", elapsed)
                                .putLong("syncedAt", System.currentTimeMillis())
                                .putString("workspace", call.argument<String>("workspace") ?: "")
                                .putLong("focusDeadline", focusDeadline)
                                .putLong("breakEndsAt", breakEnd)
                                .putInt("breakMinutes", call.argument<Number>("breakMinutes")?.toInt() ?: 5)
                            if (oldFocus > 0 && oldFocus <= System.currentTimeMillis())
                                editor.putLong("pendingFocusCue", oldFocus)
                            if (prefs.getString("sessionId", "") != session) {
                                editor.putLong("lastQuarter", elapsed / AwarenessService.INTERVAL)
                                editor.putLong("pendingFocusCue", 0L)
                            }
                            check(editor.commit())
                            if ((running && (enabled || focusDeadline > 0 ||
                                        prefs.getString("track", "off") != "off")) || breakEnd > 0) {
                                requestNotifications()
                                startAwareness(Intent(this, AwarenessService::class.java))
                            } else stopService(Intent(this, AwarenessService::class.java))
                            result.success(null)
                        }
                        "preview" -> {
                            requestNotifications()
                            startAwareness(Intent(this, AwarenessService::class.java).setAction("preview"))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("awareness_failed", error.message, null)
                }
            }
    }

    private fun startAwareness(intent: Intent) {
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupFiles.onResult(requestCode, resultCode, data)
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1500)
        }
    }
}
