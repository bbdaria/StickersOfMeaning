package com.example.stickers_of_meaning

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Bundle
import android.text.StaticLayout
import android.text.TextPaint
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

                // 1. Setup Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                // 2. Get Data
                val textToShow = widgetData.getString("sticker_text", "Open App to Load") ?: "No Text"
                val imagePath = widgetData.getString("sticker_image", null)
                val showImage = widgetData.getBoolean("show_image", true)

                // Colors
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

                // User Preferred Font Size (The Max Limit)
                val rawSize = widgetData.all["sticker_font_size"]
                val userFontSize = try {
                    when (rawSize) {
                        is String -> rawSize.toFloatOrNull() ?: 16.0f
                        is Number -> rawSize.toFloat()
                        else -> 16.0f
                    }
                } catch (e: Exception) {
                    16.0f
                }

                // 3. Set Text
                setTextViewText(R.id.widget_text, textToShow)

                // 4. Image Logic
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
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                    setViewVisibility(R.id.text_content_layout, View.GONE)
                    setViewVisibility(R.id.widget_background, View.GONE)
                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                } else {
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.text_content_layout, View.VISIBLE)
                    setViewVisibility(R.id.widget_background, View.VISIBLE)

                    val bgAlpha = Color.alpha(bgColor)
                    val bgRgb = Color.rgb(Color.red(bgColor), Color.green(bgColor), Color.blue(bgColor))

                    setInt(R.id.widget_background, "setImageAlpha", bgAlpha)
                    setInt(R.id.widget_background, "setColorFilter", bgRgb)
                    setTextColor(R.id.widget_text, textColor)

                    // --- DYNAMIC FONT SIZING LOGIC ---
                    val options = appWidgetManager.getAppWidgetOptions(widgetId)

                    // Use MIN_HEIGHT/WIDTH to be safe, but fallback to 0 if missing
                    val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                    val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

                    var optimalSize = userFontSize

                    // Only calculate if we have valid dimensions
                    if (minHeightDp > 0 && minWidthDp > 0) {
                        val density = context.resources.displayMetrics.density

                        // Calculate available space (subtract padding & logo height)
                        // Vertical: Height - 16dp (padding) - 25dp (logo)
                        val availableHeightPx = ((minHeightDp - 16 - 25) * density).toInt()
                        // Horizontal: Width - 16dp (padding)
                        val availableWidthPx = ((minWidthDp - 16) * density).toInt()

                        optimalSize = calculateOptimalTextSize(
                            context,
                            textToShow,
                            userFontSize,
                            availableWidthPx,
                            availableHeightPx
                        )
                    }

                    // Apply the calculated safe size
                    setTextViewTextSize(R.id.widget_text, TypedValue.COMPLEX_UNIT_SP, optimalSize)

                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    // --- ADDED: Detect Resize Events ---
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        // Fetch the data manually since this method doesn't provide it
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        // Trigger a standard update to recalculate font size with new dimensions
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
    }

    private fun calculateOptimalTextSize(
        context: Context,
        text: String,
        maxSizeSp: Float,
        widthPx: Int,
        heightPx: Int
    ): Float {
        var trySize = maxSizeSp
        val minSize = 10f

        // Safety check
        if (widthPx <= 0 || heightPx <= 0) return maxSizeSp

        val paint = TextPaint()
        paint.typeface = android.graphics.Typeface.DEFAULT_BOLD

        while (trySize >= minSize) {
            paint.textSize = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                trySize,
                context.resources.displayMetrics
            )

            // Create a layout to measure exact text height
            val alignment = android.text.Layout.Alignment.ALIGN_CENTER

            val layout = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                StaticLayout.Builder.obtain(text, 0, text.length, paint, widthPx)
                    .setAlignment(alignment)
                    .setLineSpacing(0f, 1f)
                    .setIncludePad(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                StaticLayout(text, paint, widthPx, alignment, 1f, 0f, true)
            }

            if (layout.height <= heightPx) {
                return trySize
            }

            trySize -= 1f
        }

        return minSize
    }
}