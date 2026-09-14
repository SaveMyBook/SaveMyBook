package com.example.savemybook_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

// local_auth 的 BiometricPrompt 必須跑在 FragmentActivity 上，
// 繼承 FlutterActivity 會在叫出生物辨識時直接崩潰。
class MainActivity : FlutterFragmentActivity() {

    private val channelName = "savemybook/deeplink"
    private val shareChannelName = "savemybook/share"

    private var channel: MethodChannel? = null
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        pendingLink = intent?.dataString ?: pendingLink

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(pendingLink)
                    pendingLink = null
                } else {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result -> handleShare(call, result) }

        // Android 的角標由啟動器自行計算，這裡只處理「打開通知設定」。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "savemybook/push")
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    // 通知設定頁是 Android 8 才有的，更舊的版本退回 App 資訊頁。
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    try {
                        startActivity(intent)
                    } catch (e: Exception) {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val link = intent.dataString ?: return
        val active = channel
        if (active == null) {
            pendingLink = link
        } else {
            active.invokeMethod("onLink", link)
        }
    }

    // Android 8 起推播必須屬於某個頻道。id 要與 AndroidManifest 的預設頻道及伺服器送出的 channel_id 一致。
    // 重複建立同一個 id 不會有副作用，只會更新名稱與說明。
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "savemybook_default",
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = getString(R.string.notification_channel_description)
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    private fun handleShare(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shareText" -> {
                val text = call.argument<String>("text").orEmpty()
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(intent, null))
                result.success(true)
            }

            "shareImage" -> {
                val uri = uriFor(call.argument<String>("path"))
                if (uri == null) {
                    result.error("no_image", "找不到圖片", null)
                    return
                }
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    call.argument<String>("text")?.let { putExtra(Intent.EXTRA_TEXT, it) }
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(intent, null))
                result.success(true)
            }

            "shareFile" -> {
                val uri = uriFor(call.argument<String>("path"))
                if (uri == null) {
                    result.error("no_file", "找不到檔案", null)
                    return
                }
                val intent = Intent(Intent.ACTION_SEND).apply {
                    // 讓接收端自己判斷型別；寫死 application/json 會讓
                    // 雲端硬碟以外的 App 在選單裡消失。
                    type = "*/*"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    call.argument<String>("text")?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(intent, null))
                result.success(true)
            }

            "saveImage" -> saveImage(call.argument<String>("path"), result)

            else -> result.notImplemented()
        }
    }

    private fun uriFor(path: String?): Uri? {
        val file = path?.let { File(it) } ?: return null
        if (!file.exists()) return null
        return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
    }

    private fun saveImage(path: String?, result: MethodChannel.Result) {
        val file = path?.let { File(it) }
        if (file == null || !file.exists()) {
            result.error("no_image", "找不到圖片", null)
            return
        }

        // MediaStore 的 RELATIVE_PATH 需要 Android 10 以上；更舊的版本要
        // WRITE_EXTERNAL_STORAGE，這裡不宣告那個權限，直接回報不支援。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("unsupported", "此裝置版本不支援直接儲存", null)
            return
        }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/SaveMyBook")
        }

        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("save_failed", "無法寫入相簿", null)
            return
        }

        try {
            contentResolver.openOutputStream(uri).use { output ->
                if (output == null) throw IllegalStateException("no stream")
                file.inputStream().use { it.copyTo(output) }
            }
            result.success(true)
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            result.error("save_failed", e.message, null)
        }
    }
}
