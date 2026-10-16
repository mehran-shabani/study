package com.example.study

import android.content.*
import android.media.*
import android.os.Build
import kotlin.math.*
import java.util.Random

/** Original, offline soundscapes generated as loopable PCM; no licensed songs. */
class FocusAudio(private val context: Context) {
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var player: AudioTrack? = null
    private var track = "off"
    private var volume = 0.25f
    private var request: AudioFocusRequest? = null
    private var registered = false
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
    }

    fun sync(selected: String, level: Float, running: Boolean) {
        volume = level.coerceIn(0f, 0.6f)
        if (!running || selected == "off") { stop(); return }
        if (selected == track && player != null) {
            player?.setVolume(volume)
            return
        }
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
            val samples = synthesize(selected)
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
            track = selected
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= 33)
                context.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
            else context.registerReceiver(noisy, filter)
            registered = true
        } catch (error: Exception) {
            interrupt()
            throw error
        }
    }

    fun stop() {
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

    companion object {
        private const val RATE = 22050
        fun synthesize(track: String): ShortArray {
            require(track in listOf("melody", "rain", "brown"))
            val count = RATE * 16
            val random = Random(260101)
            var brown = 0.0
            val notes = doubleArrayOf(220.0, 261.6256, 329.6276, 293.6648,
                220.0, 261.6256, 391.9954, 329.6276)
            val result = ShortArray(count)
            for (i in 0 until count) {
                val t = i.toDouble() / RATE
                val noise = random.nextDouble() * 2 - 1
                brown = (brown + noise * 0.025) * 0.995
                val sample = when (track) {
                    "brown" -> brown * 1.8
                    "rain" -> noise * (0.24 + 0.04 * sin(2 * PI * t / 8)) + brown * 0.3
                    else -> {
                        val beat = t % 0.5
                        val frequency = notes[(t / 0.5).toInt() % notes.size]
                        val envelope = (1 - exp(-beat * 35)) * exp(-beat * 8)
                        (sin(2 * PI * frequency * beat) +
                            0.25 * sin(4 * PI * frequency * beat)) * envelope * 0.35
                    }
                }
                // Smooth the seam; avoid clicks when starting or looping.
                val fade = minOf(1.0, i / (RATE * 0.03), (count - 1 - i) / (RATE * 0.03))
                result[i] = (sample.coerceIn(-0.8, 0.8) * fade * 32767).toInt().toShort()
            }
            return result
        }
    }
}
