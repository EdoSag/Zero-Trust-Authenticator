package dev.sagron.zerotrustauthenticator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * The home screen widget, in the shared Zero-Trust widget look
 * (Zero-Trust-Core/android-widget-kit): opens the codes, or the QR scanner
 * to add an account. Buttons only. It never shows a code, an account or
 * how many there are, so it needs no privacy switch: codes show in the app,
 * after unlocking.
 */
class CodesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            manager.updateAppWidget(id, build(context, manager.getAppWidgetOptions(id)))
        }
    }

    /** Resized: redraw with what now fits. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        manager.updateAppWidget(id, build(context, newOptions))
    }

    private fun build(context: Context, options: Bundle?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_codes)
        // 0 until the launcher has measured the widget: show everything.
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        val wide = width == 0 || width >= 180
        val scan = width == 0 || width >= 110
        val tall = height == 0 || height >= 110

        views.setViewVisibility(R.id.header, if (tall && wide) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.texts, if (wide) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.scan, if (scan) View.VISIBLE else View.GONE)

        val open = PendingIntent.getActivity(
            context,
            3,
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val scanner = PendingIntent.getActivity(
            context,
            4,
            Intent(context, MainActivity::class.java)
                .setAction(MainActivity.ACTION_SCAN)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, open)
        views.setOnClickPendingIntent(R.id.scan, scanner)
        return views
    }
}
