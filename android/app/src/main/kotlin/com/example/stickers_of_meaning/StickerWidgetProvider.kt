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
                val textToShow = widgetData.getString("sticker_text", "Open App to Load") ?: "No Text"
                val imagePath = widgetData.getString("sticker_image", null)
                val showImage = widgetData.getBoolean("show_image", true)

                // Font Size Logic (Safe parsing)
                val rawSize = widgetData.all["sticker_font_size"]
                val fontSize = try {
                    when (rawSize) {
                        is String -> rawSize.toFloatOrNull() ?: 16.0f
                        is Number -> rawSize.toFloat()
                        else -> 16.0f
                    }
                } catch (e: Exception) {
                    16.0f
                }

                // 3. Set Text & Font Size
                setTextViewText(R.id.widget_text, textToShow)
                setTextViewTextSize(R.id.widget_text, TypedValue.COMPLEX_UNIT_SP, fontSize)

                // 4. Check Image Availability
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

                // 5. Apply Visibility & Colors
                if (imageShown) {
                    // MODE A: BACKGROUND IMAGE ONLY
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                    setViewVisibility(R.id.text_container, View.GONE)

                    // Set transparent background to let image shape show
                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                } else {
                    // MODE B: TEXT + SMALL LOGO
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.text_container, View.VISIBLE)

                    // White Background
                    setInt(R.id.widget_root, "setBackgroundColor", Color.WHITE)
                    setTextColor(R.id.widget_text, Color.parseColor("#1E3A8A"))
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}