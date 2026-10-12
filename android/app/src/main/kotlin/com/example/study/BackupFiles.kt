package com.example.study

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Android document picker lets the user choose storage without file permissions. */
class BackupFiles(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null
    private var content = ""

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A document picker is already open.", null)
            return
        }
        try {
            when (call.method) {
                "save" -> {
                    content = call.argument<String>("content") ?: ""
                    pending = result
                    activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                    }, SAVE)
                }
                "open" -> {
                    pending = result
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }, OPEN)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            pending = null
            content = ""
            result.error("file_failed", error.message, null)
        }
    }

    fun onResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE && requestCode != OPEN) return
        val result = pending ?: return
        pending = null
        val payload = content
        content = ""
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == SAVE) false else null)
            return
        }
        Thread {
            try {
                val response: Any = if (requestCode == SAVE) {
                    activity.contentResolver.openOutputStream(uri, "wt")!!.use {
                        it.write(payload.toByteArray(Charsets.UTF_8))
                    }
                    true
                } else {
                    activity.contentResolver.openInputStream(uri)!!.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            if (output.size() + read > 20 * 1024 * 1024)
                                throw IllegalArgumentException("File exceeds 20 MB.")
                            output.write(buffer, 0, read)
                        }
                        output.toString("UTF-8")
                    }
                }
                Handler(Looper.getMainLooper()).post { result.success(response) }
            } catch (error: Exception) {
                Handler(Looper.getMainLooper()).post {
                    result.error("file_failed", error.message, null)
                }
            }
        }.start()
    }

    companion object {
        const val SAVE = 1501
        const val OPEN = 1502
    }
}
