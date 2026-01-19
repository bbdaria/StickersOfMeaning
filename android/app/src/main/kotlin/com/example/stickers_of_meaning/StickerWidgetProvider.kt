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

                // --- ROBUST COLOR READING START ---
                // Try reading as Int, if it fails (due to large Long values), read as Long and cast
                val defaultTextColor = Color.parseColor("#1E3A8A")
                val textColor = try {
                    widgetData.getInt("sticker_text_color", defaultTextColor)
                } catch (e: Exception) {
                    widgetData.getLong("sticker_text_color", defaultTextColor.toLong()).toInt()
                }

                val defaultBgColor = Color.WHITE
                val bgColor = try {
                    widgetData.getInt("sticker_bg_color", defaultBgColor)
                } catch (e: Exception) {
                    widgetData.getLong("sticker_bg_color", defaultBgColor.toLong()).toInt()
                }
                // --- ROBUST COLOR READING END ---

                // Font Size Logic
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
                    // --- IMAGE MODE ---
                    // Show photo, hide text, hide rounded background
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                    setViewVisibility(R.id.text_content_layout, View.GONE)
                    setViewVisibility(R.id.widget_background, View.GONE)

                    // Transparent root
                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                } else {
                    // --- TEXT MODE ---
                    // Hide photo, show text
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.text_content_layout, View.VISIBLE)

                    // Show Rounded Background & Apply Color
                    setViewVisibility(R.id.widget_background, View.VISIBLE)
                    setInt(R.id.widget_background, "setColorFilter", bgColor)

                    // Apply Text Color
                    setTextColor(R.id.widget_text, textColor)

                    // Transparent root (so we see the rounded background underneath)
                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}