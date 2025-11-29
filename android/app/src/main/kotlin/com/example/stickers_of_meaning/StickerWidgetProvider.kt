package com.example.stickers_of_meaning

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StickerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Open the app when clicked
                // val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                //     context,
                //     MainActivity::class.java
                // )
                // setOnClickPendingIntent(R.id.widget_image, pendingIntent)

                // 1. Get Data from Flutter
                val text = widgetData.getString("sticker_text", "No Sticker Yet")
                val imagePath = widgetData.getString("sticker_image", null)

                // 2. Update Text
                setTextViewText(R.id.widget_text, text)

                // 3. Update Image
                if (imagePath != null) {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    setImageViewBitmap(R.id.widget_image, bitmap)
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_image, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}