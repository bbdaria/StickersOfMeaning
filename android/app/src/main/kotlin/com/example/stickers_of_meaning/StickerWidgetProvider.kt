package com.example.stickers_of_meaning

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color // <--- Don't forget this import!
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

                // 1. Click to Open App
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                // 2. Get Data
                val text = widgetData.getString("sticker_text", "No Sticker Yet")
                val imagePath = widgetData.getString("sticker_image", null)
                val showImage = widgetData.getBoolean("show_image", true)

                // 3. Set Text
                setTextViewText(R.id.widget_text, text)

                // 4. LOGIC: Check if we can show the image
                var imageShown = false

                if (showImage && imagePath != null) {
                    val file = java.io.File(imagePath)
                    if (file.exists()) {
                        try {
                            val bitmap = BitmapFactory.decodeFile(imagePath)
                            if (bitmap != null) {
                                setImageViewBitmap(R.id.widget_image, bitmap)
                                imageShown = true
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }

                // 5. APPLY VISIBILITY & BACKGROUND
                if (imageShown) {
                    // --- OPTION A: SHOW IMAGE ---
                    // Hide Text
                    setViewVisibility(R.id.widget_text, View.GONE)
                    // Show Image
                    setViewVisibility(R.id.widget_image, View.VISIBLE)

                    // BONUS: Make background Transparent
                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                } else {
                    // --- OPTION B: SHOW TEXT ---
                    // Hide Image
                    setViewVisibility(R.id.widget_image, View.GONE)
                    // Show Text
                    setViewVisibility(R.id.widget_text, View.VISIBLE)

                    // Restore White Background (so text is readable)
                    setInt(R.id.widget_root, "setBackgroundColor", Color.WHITE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}