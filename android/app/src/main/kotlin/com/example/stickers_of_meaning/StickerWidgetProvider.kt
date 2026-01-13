package com.example.stickers_of_meaning

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.TypedValue
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

                // 1. Setup Click to Open App
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                // 2. Get Data
                val text = widgetData.getString("sticker_text", "No Sticker Yet")
                val imagePath = widgetData.getString("sticker_image", null)
                val showImage = widgetData.getBoolean("show_image", true)

                // --- FIX: ULTRA ROBUST FONT SIZE READING ---
                // We access the raw map (.all) to avoid ClassCastExceptions.
                // This handles String, Float, Int, or Long safely.
                val rawSize = widgetData.all["sticker_font_size"]
                val fontSize = when (rawSize) {
                    is String -> rawSize.toFloatOrNull() ?: 16.0f
                    is Float -> rawSize
                    is Long -> rawSize.toFloat() // <--- This fixes your specific crash!
                    is Int -> rawSize.toFloat()
                    is Double -> rawSize.toFloat()
                    else -> 16.0f // Default if missing or unknown type
                }
                // -------------------------------------------

                // 3. Set Text & Font Size
                setTextViewText(R.id.widget_text, text)
                setTextViewTextSize(R.id.widget_text, TypedValue.COMPLEX_UNIT_SP, fontSize)

                // 4. Visibility Logic
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

                // 5. Apply Visibility & Background Colors
                if (imageShown) {
                    // MODE A: IMAGE ONLY
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                    setViewVisibility(R.id.widget_text, View.GONE)
                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                } else {
                    // MODE B: TEXT ONLY
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.widget_text, View.VISIBLE)

                    // White Background & Black Text
                    setInt(R.id.widget_root, "setBackgroundColor", Color.WHITE)
                    setInt(R.id.widget_text, "setTextColor", Color.BLACK)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}