package com.example.savemybook_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

class SaveMyBookWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val text = localizedContext(context, read(widgetData, "smb_lang"))
        val signedIn = read(widgetData, "smb_signed_in") == "1"
        val pickupCount = read(widgetData, "smb_pickup_count").toIntOrNull() ?: 0
        val depositCount = read(widgetData, "smb_deposit_count").toIntOrNull() ?: 0
        val unreadCount = read(widgetData, "smb_unread_chat").toIntOrNull() ?: 0
        val coins = read(widgetData, "smb_coins").ifEmpty { "0" }
        val pickupCode = read(widgetData, "smb_pickup_code")
        val pickupCabinet = read(widgetData, "smb_pickup_cabinet")
        val updatedAt = read(widgetData, "smb_updated_at")

        val detail = when {
            pickupCount == 0 -> text.getString(R.string.smb_widget_no_pickup)
            pickupCode.isNotEmpty() && pickupCabinet.isNotEmpty() ->
                text.getString(R.string.smb_widget_pickup_code, pickupCode) + " · " + pickupCabinet
            pickupCode.isNotEmpty() -> text.getString(R.string.smb_widget_pickup_code, pickupCode)
            pickupCabinet.isNotEmpty() -> pickupCabinet
            else -> text.getString(R.string.smb_widget_pickup)
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.savemybook_widget)

            views.setTextViewText(R.id.smb_widget_title, text.getString(R.string.smb_widget_app_name))
            views.setTextViewText(R.id.smb_widget_signed_out, text.getString(R.string.smb_widget_signed_out))
            views.setTextViewText(R.id.smb_widget_updated, text.getString(R.string.smb_widget_updated, updatedAt))

            views.setTextViewText(R.id.smb_widget_pickup_count, pickupCount.toString())
            views.setTextViewText(R.id.smb_widget_deposit_count, depositCount.toString())
            views.setTextViewText(R.id.smb_widget_unread_count, unreadCount.toString())
            views.setTextViewText(R.id.smb_widget_coins, coins)
            views.setTextViewText(R.id.smb_widget_pickup_label, text.getString(R.string.smb_widget_pickup))
            views.setTextViewText(R.id.smb_widget_deposit_label, text.getString(R.string.smb_widget_deposit))
            views.setTextViewText(R.id.smb_widget_unread_label, text.getString(R.string.smb_widget_unread))
            views.setTextViewText(R.id.smb_widget_coins_label, text.getString(R.string.smb_widget_coins))
            views.setTextViewText(R.id.smb_widget_pickup_detail, detail)

            views.setViewVisibility(R.id.smb_widget_content, if (signedIn) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.smb_widget_signed_out, if (signedIn) View.GONE else View.VISIBLE)
            views.setViewVisibility(
                R.id.smb_widget_updated,
                if (signedIn && updatedAt.isNotEmpty()) View.VISIBLE else View.GONE
            )

            views.setOnClickPendingIntent(R.id.smb_widget_root, launchIntent(context))
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun read(prefs: SharedPreferences, key: String): String {
        return prefs.all[key]?.toString() ?: ""
    }

    private fun localizedContext(context: Context, tag: String): Context {
        val locale = when (tag) {
            "zh_Hant" -> Locale.TRADITIONAL_CHINESE
            "zh_Hans" -> Locale.SIMPLIFIED_CHINESE
            "en" -> Locale.ENGLISH
            "ja" -> Locale.JAPANESE
            "ko" -> Locale.KOREAN
            else -> return context
        }
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    private fun launchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
