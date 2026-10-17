package com.example.study

import android.app.*
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.*
import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** Owns screen-off cues, focus boundaries and offline sound. SQLite remains the
 * authoritative stopwatch; native deadlines never automatically restart study. */
class AwarenessService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val prefs by lazy { getSharedPreferences("awareness", MODE_PRIVATE) }
    private val audio by lazy { FocusAudio(this) {
        handler.post {
            if (!needed()) stopSelf()
            else (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIFICATION_ID, notification())
        }
    } }
    private var wakeLock: PowerManager.WakeLock? = null
    private var tone: ToneGenerator? = null
    private var baseElapsed = 0L
    private var baseUptime = 0L
    private var lastQuarter = 0L
    private var generation = 0
    private var previewOnly = false

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        cancelCues()
        if (intent?.action == "mute") {
            prefs.edit().putString("track", "off").apply()
            audio.stop()
        }
        val running = prefs.getBoolean("running", false)
        if (running) (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(BREAK_NOTIFICATION_ID)
        baseElapsed = prefs.getLong("elapsedMs", 0L) + if (running)
            (System.currentTimeMillis() - prefs.getLong("syncedAt", System.currentTimeMillis()))
                .coerceAtLeast(0L) else 0L
        baseUptime = SystemClock.elapsedRealtime()
        val preview = intent?.action == "preview"
        previewOnly = preview && !needed()
        if (!preview && !needed()) { stopSelf(); return START_NOT_STICKY }
        lastQuarter = maxOf(prefs.getLong("lastQuarter", 0L), baseElapsed / INTERVAL)
        prefs.edit().putLong("lastQuarter", lastQuarter).apply()
        startForeground(NOTIFICATION_ID, notification())
        if (wakeLock == null) {
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "study:awareness")
                .apply { acquire() }
        }
        if (preview) playBeeps(1, generation)
        if (!previewOnly) dispatch()
        return if (previewOnly) START_NOT_STICKY else START_STICKY
    }

    private fun needed(): Boolean =
        (prefs.getBoolean("running", false) &&
            (prefs.getBoolean("enabled", true) || prefs.getLong("focusDeadline", 0L) > 0 ||
                prefs.getString("track", "off") != "off")) || prefs.getLong("breakEndsAt", 0L) > 0

    private fun elapsed() = baseElapsed + if (prefs.getBoolean("running", false))
        SystemClock.elapsedRealtime() - baseUptime else 0L

    private fun dispatch() {
        val now = System.currentTimeMillis()
        val deadline = prefs.getLong("focusDeadline", 0L)
        if (prefs.getBoolean("running", false) && deadline > 0 && now >= deadline) {
            baseElapsed = (elapsed() - (now - deadline)).coerceAtLeast(0L)
            prefs.edit().putBoolean("running", false).putLong("elapsedMs", baseElapsed)
                .putLong("focusDeadline", 0L).putLong("pendingFocusCue", deadline)
                .putLong("breakEndsAt", deadline + prefs.getInt("breakMinutes", 5) * 60000L).apply()
        }
        val pending = prefs.getLong("pendingFocusCue", 0L)
        if (pending > prefs.getLong("lastFocusCue", 0L)) {
            prefs.edit().putLong("lastFocusCue", pending).apply()
            playBeeps(2, generation)
        }
        try {
            audio.sync(prefs.getString("track", "off") ?: "off",
                prefs.getFloat("volume", 0.25f), prefs.getBoolean("running", false))
        } catch (_: Exception) {
            prefs.edit().putString("track", "off").apply()
        }
        val breakEnd = prefs.getLong("breakEndsAt", 0L)
        if (breakEnd > 0 && now >= breakEnd) {
            // Persist acknowledgement, so restore/sync cannot replay this cue.
            if (breakEnd > prefs.getLong("lastBreakCue", 0L)) {
                prefs.edit().putLong("lastBreakCue", breakEnd).apply()
                playBeeps(3, generation)
                (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                    .notify(BREAK_NOTIFICATION_ID, notification(true))
            }
            prefs.edit().putLong("breakEndsAt", 0L).apply()
            handler.postDelayed({ stopSelf() }, 2000)
            return
        }
        val running = prefs.getBoolean("running", false)
        val quarter = elapsed() / INTERVAL
        if (running && prefs.getBoolean("enabled", true) && quarter > lastQuarter) {
            lastQuarter = quarter
            prefs.edit().putLong("lastQuarter", quarter).apply()
            playBeeps(quarter.toInt(), generation)
        }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, notification())
        val delays = mutableListOf<Long>()
        if (running && prefs.getBoolean("enabled", true))
            delays.add((elapsed() / INTERVAL + 1) * INTERVAL - elapsed())
        val focusAt = prefs.getLong("focusDeadline", 0L)
        if (running && focusAt > 0) delays.add(focusAt - now)
        if (breakEnd > 0) delays.add(breakEnd - now)
        if (delays.isNotEmpty()) handler.postDelayed({ dispatch() }, delays.minOrNull()!!.coerceAtLeast(1L))
    }

    private fun playBeeps(remaining: Int, token: Int) {
        if (token != generation) return
        if (remaining <= 0) {
            tone?.release(); tone = null
            if (previewOnly) stopSelf()
            return
        }
        try {
            if (tone == null) tone = ToneGenerator(AudioManager.STREAM_MUSIC, 55)
            tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 180)
        } catch (_: RuntimeException) {
            if (previewOnly) stopSelf()
            return
        }
        handler.postDelayed({ playBeeps(remaining - 1, token) }, 500)
    }

    private fun notification(breakFinished: Boolean = false): Notification {
        val language = prefs.getString("language", "system")
        val localized: Context = if (language == "fa" || language == "en") {
            createConfigurationContext(Configuration(resources.configuration).apply {
                setLocale(Locale.forLanguageTag(language))
            })
        } else this
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, localized.getString(R.string.awareness_channel), NotificationManager.IMPORTANCE_LOW
            ).apply { setSound(null, null) })
        }
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1,
            Intent(this, AwarenessService::class.java).setAction("mute"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        val text = when {
            breakFinished -> localized.getString(R.string.focus_break_ready)
            !prefs.getBoolean("running", false) -> localized.getString(R.string.focus_break)
            prefs.getLong("focusDeadline", 0L) > 0 -> localized.getString(R.string.focus_studying)
            else -> localized.getString(R.string.awareness_next, prefs.getString("workspace", ""), elapsed() / INTERVAL + 1)
        }
        if (!breakFinished && prefs.getString("track", "off") != "off")
            builder.addAction(Notification.Action.Builder(
                null, localized.getString(R.string.focus_mute), stop).build())
        return builder.setSmallIcon(R.drawable.ic_awareness)
            .setContentTitle(localized.getString(R.string.awareness_title)).setContentText(text)
            .setContentIntent(open).setOngoing(!breakFinished).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STOPWATCH).build()
    }

    private fun cancelCues() {
        generation++
        handler.removeCallbacksAndMessages(null)
        tone?.release(); tone = null
    }

    override fun onDestroy() {
        cancelCues()
        audio.close()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        const val INTERVAL = 15 * 60 * 1000L
        const val CHANNEL = "study_awareness"
        const val NOTIFICATION_ID = 1500
        const val BREAK_NOTIFICATION_ID = 1501
    }
}
