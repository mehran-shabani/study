package com.example.study

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val backupFiles by lazy { BackupFiles(this) }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study/files")
            .setMethodCallHandler { call, result -> backupFiles.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study/awareness")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("awareness", MODE_PRIVATE)
                try {
                    when (call.method) {
                        "isEnabled" -> result.success(prefs.getBoolean("enabled", true))
                        "sync" -> {
                            val running = call.argument<Boolean>("running") == true
                            val enabled = call.argument<Boolean>("enabled") == true
                            val session = call.argument<String>("sessionId") ?: ""
                            val elapsed = call.argument<Number>("elapsedMs")?.toLong() ?: 0L
                            val editor = prefs.edit()
                                .putBoolean("enabled", enabled).putBoolean("running", running)
                                .putString("sessionId", session).putLong("elapsedMs", elapsed)
                                .putLong("syncedAt", System.currentTimeMillis())
                                .putString("workspace", call.argument<String>("workspace") ?: "")
                            if (prefs.getString("sessionId", "") != session)
                                editor.putLong("lastQuarter", elapsed / AwarenessService.INTERVAL)
                            editor.commit()
                            if (running && enabled) {
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
