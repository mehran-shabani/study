package com.example.study

import android.app.*
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.*

/** Runs independently of Flutter routes and ticks only at study milestones. */
class AwarenessService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val prefs by lazy { getSharedPreferences("awareness", MODE_PRIVATE) }
    private var wakeLock: PowerManager.WakeLock? = null
    private var tone: ToneGenerator? = null
    private var baseElapsed = 0L
    private var baseUptime = 0L
    private var lastQuarter = 0L
    private var generation = 0
    private var previewOnly = false

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        cancelSound()
        val elapsed = prefs.getLong("elapsedMs", 0L) +
            (System.currentTimeMillis() - prefs.getLong("syncedAt", System.currentTimeMillis()))
                .coerceAtLeast(0L)
        val preview = intent?.action == "preview"
        val active = prefs.getBoolean("running", false) && prefs.getBoolean("enabled", true)
        previewOnly = preview && !active
        if (!previewOnly && (!prefs.getBoolean("running", false) ||
                    !prefs.getBoolean("enabled", true))) {
            stopSelf()
            return START_NOT_STICKY
        }
        baseElapsed = elapsed.coerceAtLeast(0L)
        baseUptime = SystemClock.elapsedRealtime()
        // Reopening/re-enabling must not replay earlier milestones.
        lastQuarter = maxOf(prefs.getLong("lastQuarter", 0L), baseElapsed / INTERVAL)
        prefs.edit().putLong("lastQuarter", lastQuarter).apply()
        startForeground(NOTIFICATION_ID, notification())
        if (wakeLock == null) {
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "study:awareness")
                .apply { acquire() }
        }
        if (!previewOnly) scheduleNext()
        if (preview) playBeeps(1, generation)
        return if (previewOnly) START_NOT_STICKY else START_STICKY
    }

    private fun elapsed() = baseElapsed + SystemClock.elapsedRealtime() - baseUptime

    private fun scheduleNext() {
        val next = (elapsed() / INTERVAL + 1) * INTERVAL
        handler.postDelayed({
            val quarter = elapsed() / INTERVAL
            if (quarter > lastQuarter) {
                lastQuarter = quarter
                prefs.edit().putLong("lastQuarter", quarter).apply()
                (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                    .notify(NOTIFICATION_ID, notification())
                playBeeps(quarter, generation)
            }
            scheduleNext()
        }, (next - elapsed()).coerceAtLeast(1L))
    }

    private fun playBeeps(remaining: Long, token: Int) {
        if (token != generation) return
        if (remaining <= 0) {
            tone?.release()
            tone = null
            if (previewOnly) stopSelf()
            return
        }
        try {
            if (tone == null) tone = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
            tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 180)
        } catch (_: RuntimeException) {
            if (previewOnly) stopSelf()
            return
        }
        handler.postDelayed({ playBeeps(remaining - 1, token) }, 500)
    }

    private fun notification(): Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, getString(R.string.awareness_channel), NotificationManager.IMPORTANCE_LOW
            ).apply { setSound(null, null) })
        }
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        val quarter = elapsed() / INTERVAL + 1
        return builder.setSmallIcon(R.drawable.ic_awareness)
            .setContentTitle(getString(R.string.awareness_title))
            .setContentText(getString(R.string.awareness_next, prefs.getString("workspace", ""), quarter))
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STOPWATCH).build()
    }

    private fun cancelSound() {
        generation++
        handler.removeCallbacksAndMessages(null)
        tone?.release()
        tone = null
    }

    override fun onDestroy() {
        cancelSound()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        const val INTERVAL = 15 * 60 * 1000L
        const val CHANNEL = "study_awareness"
        const val NOTIFICATION_ID = 1500
    }
}
