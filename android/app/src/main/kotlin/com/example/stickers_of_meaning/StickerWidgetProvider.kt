package com.technion.stickers_of_meaning

import com.technion.stickers_of_meaning.R
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
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val textToShow = widgetData.getString("sticker_text", "Open App to Load") ?: "No Text"
                val imagePath = widgetData.getString("sticker_image", null)
                val showImage = widgetData.getBoolean("show_image", true)

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

                setTextViewText(R.id.widget_text, textToShow)

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

                    val options = appWidgetManager.getAppWidgetOptions(widgetId)

                    val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                    val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

                    var optimalSize = userFontSize

                    if (minHeightDp > 0 && minWidthDp > 0) {
                        val density = context.resources.displayMetrics.density
                        val availableHeightPx = ((minHeightDp - 4 - 20) * density).toInt()
                        val availableWidthPx = ((minWidthDp - 4) * density).toInt()

                        optimalSize = calculateOptimalTextSize(
                            context,
                            textToShow,
                            userFontSize,
                            availableWidthPx,
                            availableHeightPx
                        )
                    }

                    setTextViewTextSize(R.id.widget_text, TypedValue.COMPLEX_UNIT_SP, optimalSize)

                    setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
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

        if (widthPx <= 0 || heightPx <= 0) return maxSizeSp

        val paint = TextPaint()
        paint.typeface = android.graphics.Typeface.DEFAULT_BOLD

        while (trySize >= minSize) {
            paint.textSize = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                trySize,
                context.resources.displayMetrics
            )

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