package com.example.study

import android.content.*
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.Future
import kotlin.math.*
import java.util.Random

/** Original, offline soundscapes generated as loopable PCM; no licensed songs. */
class FocusAudio(private val context: Context, private val onInterrupted: () -> Unit = {}) {
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var player: AudioTrack? = null
    private var track = "off"
    private var volume = 0.25f
    private var request: AudioFocusRequest? = null
    private var registered = false
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: Future<*>? = null
    private var generation = 0
    private val focus = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) interrupt()
    }
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { interrupt() }
    }

    private fun interrupt() {
        // Never unexpectedly move headphone playback to the loudspeaker or
        // resume after a call. The user explicitly selects a sound again.
        context.getSharedPreferences("awareness", Context.MODE_PRIVATE)
            .edit().putString("track", "off").apply()
        stop()
        onInterrupted()
    }

    fun sync(selected: String, level: Float, running: Boolean) {
        volume = if (level.isFinite()) level.coerceIn(0f, 0.6f) else 0.25f
        if (!running || selected == "off") { stop(); return }
        if (selected == track && (player != null || pending != null)) {
            player?.setVolume(volume)
            return
        }
        require(selected in TRACKS)
        stop()
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focus).build()
            manager.requestAudioFocus(request!!)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(focus, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            interrupt()
            return
        }
        try {
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= 33)
                context.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
            else context.registerReceiver(noisy, filter)
            registered = true
        } catch (error: Exception) {
            interrupt()
            throw error
        }
        track = selected
        val token = generation
        // PCM generation is CPU work. Keep it off the Android UI/service thread.
        pending = worker.submit {
            try {
                val samples = synthesize(selected)
                handler.post {
                    if (token != generation) return@post
                    pending = null
                    try {
                        val audio = AudioTrack.Builder().setAudioAttributes(attributes)
                            .setAudioFormat(AudioFormat.Builder().setSampleRate(RATE)
                                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                                .setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
                            .setTransferMode(AudioTrack.MODE_STATIC)
                            .setBufferSizeInBytes(samples.size * 2).build()
                        player = audio
                        check(audio.write(samples, 0, samples.size) == samples.size)
                        check(audio.setLoopPoints(0, samples.size, -1) == AudioTrack.SUCCESS)
                        audio.setVolume(volume)
                        audio.play()
                    } catch (_: Exception) { interrupt() }
                }
            } catch (_: Exception) {
                handler.post { if (token == generation) interrupt() }
            }
        }
    }

    fun stop() {
        generation++
        pending?.cancel(true)
        pending = null
        player?.release()
        player = null
        track = "off"
        if (registered) { context.unregisterReceiver(noisy); registered = false }
        if (Build.VERSION.SDK_INT >= 26) request?.let { manager.abandonAudioFocusRequest(it) }
        else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(focus)
        }
        request = null
    }

    fun close() {
        stop()
        worker.shutdownNow()
        handler.removeCallbacksAndMessages(null)
    }

    companion object {
        private const val RATE = 22050
        val TRACKS = listOf("melody", "piano", "lofi", "ambient", "strings", "bells",
            "rain", "brown", "ocean", "forest", "stream", "white")

        fun synthesize(track: String): ShortArray {
            require(track in TRACKS)
            val count = RATE * 32
            val random = Random(260101L + TRACKS.indexOf(track))
            var brown = 0.0
            var filtered = 0.0
            val notes = doubleArrayOf(220.0, 261.6256, 329.6276, 293.6648,
                220.0, 261.6256, 391.9954, 329.6276)
            val chords = arrayOf(doubleArrayOf(130.8128, 164.8138, 195.9977),
                doubleArrayOf(110.0, 130.8128, 164.8138),
                doubleArrayOf(87.3071, 110.0, 130.8128),
                doubleArrayOf(97.9989, 123.4708, 146.8324))
            val result = ShortArray(count)
            for (i in 0 until count) {
                if (i % 4096 == 0 && Thread.currentThread().isInterrupted)
                    throw InterruptedException("Sound selection changed")
                val t = i.toDouble() / RATE
                val noise = random.nextDouble() * 2 - 1
                brown = (brown + noise * 0.025) * 0.995
                filtered = filtered * 0.96 + noise * 0.04
                val sample = when (track) {
                    "brown" -> brown * 1.8
                    "white" -> noise * 0.2
                    "rain" -> noise * (0.24 + 0.04 * sin(2 * PI * t / 8)) + brown * 0.3
                    "ocean" -> (filtered * 1.6 + noise * 0.06) *
                        (0.35 + 0.65 * (0.5 + 0.5 * sin(2 * PI * t / 8)))
                    "forest" -> filtered * (0.55 + 0.3 * sin(2 * PI * t / 16)) +
                        sin(2 * PI * (1800 * t + 65 * sin(2 * PI * t * 3))) *
                        exp(-((t % 5.3 - 1.1) / 0.14).pow(2)) * 0.045
                    "stream" -> filtered * 0.9 + noise * 0.05 +
                        sin(2 * PI * (450 * t + 5 * sin(2 * PI * t * 2))) * 0.025
                    "ambient", "strings" -> {
                        val phase = t % 8
                        val chord = chords[(t / 8).toInt() % chords.size]
                        val envelope = sin(PI * phase / 8).pow(2)
                        chord.sumOf { frequency ->
                            sin(2 * PI * frequency * t + 0.02 * sin(2 * PI * t * 0.5)) +
                                (if (track == "strings") 0.22 else 0.08) * sin(4 * PI * frequency * t)
                        } * envelope * 0.09
                    }
                    else -> {
                        val step = when (track) { "piano" -> 1.0; "lofi" -> 0.8;
                            "bells" -> 2.0; else -> 0.5 }
                        val beat = t % step
                        val frequency = notes[(t / step).toInt() % notes.size] *
                            (if (track == "bells") 2 else 1)
                        val attack = 1 - exp(-beat * 35)
                        when (track) {
                            "piano" -> (sin(2 * PI * frequency * beat) +
                                0.32 * sin(4 * PI * frequency * beat) * exp(-beat * 6) +
                                0.12 * sin(6 * PI * frequency * beat) * exp(-beat * 10)) *
                                attack * exp(-beat * 3) * 0.3
                            "lofi" -> (sin(2 * PI * frequency * beat) +
                                0.28 * sin(2 * PI * frequency * 0.5 * beat)) *
                                attack * exp(-beat * 4) * 0.25 + filtered * 0.025
                            "bells" -> (sin(2 * PI * frequency * beat) +
                                0.22 * sin(2 * PI * frequency * 2.76 * beat)) *
                                attack * exp(-beat * 2.5) * 0.25
                            else -> (sin(2 * PI * frequency * beat) +
                                0.25 * sin(4 * PI * frequency * beat)) * attack * exp(-beat * 8) * 0.35
                        }
                    }
                }
                val fade = minOf(1.0, i / (RATE * 0.03), (count - 1 - i) / (RATE * 0.03))
                result[i] = (sample.coerceIn(-0.8, 0.8) * fade * 32767).toInt().toShort()
            }
            return result
        }
    }
}
