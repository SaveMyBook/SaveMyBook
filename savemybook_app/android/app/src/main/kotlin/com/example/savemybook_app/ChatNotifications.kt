package com.example.savemybook_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.content.LocusIdCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

object ChatNotifications {
    private const val CHANNEL_ID = "savemybook_default"
    private const val NOTIFICATION_ID = 7301
    private const val AVATAR_PX = 192
    private const val MAX_AVATAR_BYTES = 5 * 1024 * 1024

    fun show(context: Context, messageId: String?, payload: Map<String, String>) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return

        ensureChannel(context)

        val isChat = payload["type"] == "message" && !payload["sender_id"].isNullOrBlank()
        val tag = when {
            isChat -> payload["thread_id"].nonBlank() ?: "chat_room-${payload["related_id"].orEmpty()}"
            else -> "notification-${payload["notification_id"] ?: messageId ?: System.currentTimeMillis()}"
        }
        val contentIntent = openAppIntent(context, tag, messageId, payload)

        val notification = try {
            if (isChat) buildChat(context, tag, contentIntent, payload) else buildPlain(context, contentIntent, payload)
        } catch (e: Exception) {
            buildPlain(context, contentIntent, payload)
        }

        try {
            NotificationManagerCompat.from(context).notify(tag, NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
        }
    }

    private fun buildChat(
        context: Context,
        conversationId: String,
        contentIntent: PendingIntent,
        payload: Map<String, String>,
    ): android.app.Notification {
        val title = payload["title"].orEmpty()
        val senderId = payload["sender_id"].orEmpty()
        val senderName = payload["sender_name"].nonBlank() ?: title
        val isGroup = payload["room_type"] == "group"
        val roomTitle = payload["room_title"].nonBlank() ?: title
        val body = payload["body"].orEmpty().let { if (isGroup) it.removePrefix("${senderName}：") else it }

        val source = downloadAvatar(payload["sender_avatar"]) ?: initialAvatar(context, senderName)
        val avatar = circleCrop(source)

        val sender = Person.Builder()
            .setKey("user-$senderId")
            .setName(senderName)
            .setIcon(IconCompat.createWithBitmap(avatar))
            .build()
        val self = Person.Builder()
            .setKey("self")
            .setName(context.getString(R.string.notification_self_name))
            .build()

        publishShortcut(context, conversationId, if (isGroup) roomTitle else senderName, sender, source, isGroup)

        val previous = activeNotification(context, conversationId)
        val style = previous?.let { NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(it) }
            ?: NotificationCompat.MessagingStyle(self)
        style.setConversationTitle(if (isGroup) roomTitle else null)
        style.setGroupConversation(isGroup)
        style.addMessage(NotificationCompat.MessagingStyle.Message(body, System.currentTimeMillis(), sender))

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(ContextCompat.getColor(context, R.color.notification_color))
            .setContentTitle(if (isGroup) roomTitle else senderName)
            .setContentText(body)
            .setStyle(style)
            .setShortcutId(conversationId)
            .setLocusId(LocusIdCompat(conversationId))
            .addPerson(sender)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) builder.setLargeIcon(avatar)
        return builder.build()
    }

    private fun buildPlain(context: Context, contentIntent: PendingIntent, payload: Map<String, String>): android.app.Notification {
        val body = payload["body"].orEmpty()
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(ContextCompat.getColor(context, R.color.notification_color))
            .setContentTitle(payload["title"].orEmpty())
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun openAppIntent(context: Context, tag: String, messageId: String?, payload: Map<String, String>): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            payload.forEach { (key, value) -> putExtra(key, value) }
            // firebase_messaging 以 google.message_id 查回已保存的訊息，才會觸發 onMessageOpenedApp／getInitialMessage。
            if (messageId != null) putExtra("google.message_id", messageId)
        }
        return PendingIntent.getActivity(
            context,
            tag.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun publishShortcut(
        context: Context,
        conversationId: String,
        label: String,
        sender: Person,
        avatar: Bitmap,
        isGroup: Boolean,
    ) {
        try {
            val intent = Intent(context, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
            val builder = ShortcutInfoCompat.Builder(context, conversationId)
                .setShortLabel(label.ifBlank { context.getString(R.string.notification_channel_name) })
                .setLongLived(true)
                .setIcon(IconCompat.createWithAdaptiveBitmap(adaptiveAvatar(avatar)))
                .setIntent(intent)
                .setLocusId(LocusIdCompat(conversationId))
            if (!isGroup) builder.setPerson(sender)
            ShortcutManagerCompat.pushDynamicShortcut(context, builder.build())
        } catch (e: Exception) {
        }
    }

    private fun activeNotification(context: Context, tag: String): android.app.Notification? {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return null
        return try {
            manager.activeNotifications.firstOrNull { it.tag == tag && it.id == NOTIFICATION_ID }?.notification
        } catch (e: Exception) {
            null
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = context.getString(R.string.notification_channel_description) }
        )
    }

    private fun downloadAvatar(url: String?): Bitmap? {
        if (url.isNullOrBlank() || !(url.startsWith("https://") || url.startsWith("http://"))) return null
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 5000
                readTimeout = 5000
                instanceFollowRedirects = true
            }
            if (connection.responseCode !in 200..299) return null
            val bytes = connection.inputStream.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                    if (out.size() > MAX_AVATAR_BYTES) return null
                }
                out.toByteArray()
            }
            decodeSampled(bytes)
        } catch (e: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun decodeSampled(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= AVATAR_PX) sample *= 2
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    private fun circleCrop(source: Bitmap): Bitmap {
        val output = Bitmap.createBitmap(AVATAR_PX, AVATAR_PX, Bitmap.Config.ARGB_8888)
        val scale = AVATAR_PX.toFloat() / minOf(source.width, source.height)
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((AVATAR_PX - source.width * scale) / 2f, (AVATAR_PX - source.height * scale) / 2f)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(matrix) }
        }
        Canvas(output).drawCircle(AVATAR_PX / 2f, AVATAR_PX / 2f, AVATAR_PX / 2f, paint)
        return output
    }

    // 自適應圖示只保證中央 72/108 可見，頭像需縮進安全區，否則會被遮罩裁掉邊緣。
    private fun adaptiveAvatar(source: Bitmap): Bitmap {
        val size = AVATAR_PX * 3 / 2
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawColor(Color.WHITE)
        val inset = (size - AVATAR_PX) / 2f
        val scale = AVATAR_PX.toFloat() / minOf(source.width, source.height)
        val srcW = AVATAR_PX / scale
        val srcH = AVATAR_PX / scale
        val left = (source.width - srcW) / 2f
        val top = (source.height - srcH) / 2f
        canvas.drawBitmap(
            source,
            android.graphics.Rect(left.toInt(), top.toInt(), (left + srcW).toInt(), (top + srcH).toInt()),
            RectF(inset, inset, inset + AVATAR_PX, inset + AVATAR_PX),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
        )
        return output
    }

    private fun initialAvatar(context: Context, name: String): Bitmap {
        val output = Bitmap.createBitmap(AVATAR_PX, AVATAR_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawColor(ContextCompat.getColor(context, R.color.notification_color))
        val initial = name.trim().let { if (it.isEmpty()) "?" else String(Character.toChars(it.codePointAt(0))) }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = AVATAR_PX * 0.45f
            textAlign = Paint.Align.CENTER
        }
        val y = AVATAR_PX / 2f - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(initial, AVATAR_PX / 2f, y, paint)
        return output
    }

    private fun String?.nonBlank(): String? = this?.takeIf { it.isNotBlank() }
}
