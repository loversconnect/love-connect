package com.loversconnectmw.app

import android.app.Activity
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "lerolove/notifications"
    private val ringtonePickerRequestCode = 4021
    private var pendingRingtonePickResult: MethodChannel.Result? = null
    private var activeRingtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickMessageRingtone" -> {
                        if (pendingRingtonePickResult != null) {
                            result.error("busy", "Ringtone picker already open.", null)
                            return@setMethodCallHandler
                        }
                        pendingRingtonePickResult = result

                        val args = call.arguments as? Map<*, *>
                        val currentUriRaw = args?.get("currentUri") as? String
                        val existingUri =
                            if (currentUriRaw.isNullOrBlank()) {
                                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            } else {
                                Uri.parse(currentUriRaw)
                            }

                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(
                                RingtoneManager.EXTRA_RINGTONE_TYPE,
                                RingtoneManager.TYPE_NOTIFICATION
                            )
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose message ringtone")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, existingUri)
                        }
                        startActivityForResult(intent, ringtonePickerRequestCode)
                    }
                    "playMessageRingtone" -> {
                        val args = call.arguments as? Map<*, *>
                        val uriRaw = args?.get("uri") as? String
                        val toneUri =
                            if (uriRaw.isNullOrBlank()) {
                                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            } else {
                                Uri.parse(uriRaw)
                            }

                        activeRingtone?.stop()
                        activeRingtone = RingtoneManager.getRingtone(applicationContext, toneUri)
                        activeRingtone?.play()
                        result.success(null)
                    }
                    "stopMessageRingtone" -> {
                        activeRingtone?.stop()
                        activeRingtone = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ringtonePickerRequestCode) return

        val callback = pendingRingtonePickResult ?: return
        pendingRingtonePickResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            callback.success(null)
            return
        }

        val picked: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (picked == null) {
            callback.success(mapOf("uri" to "", "title" to "Default phone ringtone"))
            return
        }

        val tone = RingtoneManager.getRingtone(this, picked)
        val title = tone?.getTitle(this) ?: "Custom ringtone"
        callback.success(mapOf("uri" to picked.toString(), "title" to title))
    }

    override fun onDestroy() {
        activeRingtone?.stop()
        activeRingtone = null
        super.onDestroy()
    }
}
