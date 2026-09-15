package com.example.savemybook_app

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.ContextHolder
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingStore

// firebase_messaging 的 Dart 端事件（onMessage、背景處理）由外掛的 BroadcastReceiver 送出，
// 不經過這個 Service，因此在此繪製通知不會造成 Flutter 端重複處理；onNewToken 沿用父類別。
class SaveMyBookMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // 含 notification 區塊的訊息在背景時由系統直接顯示，前景時交給 Flutter 的應用程式內橫幅。
        if (remoteMessage.notification != null) return

        val data = remoteMessage.data
        if (data["title"].isNullOrBlank() && data["body"].isNullOrBlank()) return
        if (isAppInForeground()) return

        val messageId = remoteMessage.messageId
        if (messageId != null) {
            if (ContextHolder.getApplicationContext() == null) {
                ContextHolder.setApplicationContext(applicationContext)
            }
            // 外掛只保存含 notification 區塊的訊息；純 data 訊息不存，點擊後 onMessageOpenedApp／getInitialMessage 會找不到。
            runCatching { FlutterFirebaseMessagingStore.getInstance().storeFirebaseMessage(remoteMessage) }
        }

        ChatNotifications.show(applicationContext, messageId, data)
    }

    // 判斷條件須與外掛 FlutterFirebaseMessagingUtils.isApplicationForeground 一致，否則會出現橫幅與系統通知同時顯示或都不顯示。
    private fun isAppInForeground(): Boolean {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (keyguard?.isKeyguardLocked == true) return false
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        return activityManager.runningAppProcesses.orEmpty().any {
            it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                it.processName == packageName
        }
    }
}
