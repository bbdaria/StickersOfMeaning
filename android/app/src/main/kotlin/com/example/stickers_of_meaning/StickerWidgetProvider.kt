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
                val text = widgetData.getString("sticker_text", "No Sticker Yet")
                val imagePath = widgetData.getString("sticker_image", null)

                setTextViewText(R.id.widget_text, text)

                // --- SAFETY CHECK START ---
                var imageLoaded = false
                if (imagePath != null) {
                    val file = java.io.File(imagePath)
                    if (file.exists()) {
                        try {
                            val bitmap = BitmapFactory.decodeFile(imagePath)
                            if (bitmap != null) {
                                setImageViewBitmap(R.id.widget_image, bitmap)
                                setViewVisibility(R.id.widget_image, View.VISIBLE)
                                imageLoaded = true
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }

                if (!imageLoaded) {
                    setViewVisibility(R.id.widget_image, View.GONE)
                }
                // --- SAFETY CHECK END ---
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}