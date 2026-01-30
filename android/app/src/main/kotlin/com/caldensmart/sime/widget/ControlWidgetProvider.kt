package com.caldensmart.sime.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import com.caldensmart.sime.MainActivity
import com.caldensmart.sime.R
import org.json.JSONArray

class ControlWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "ControlWidgetProvider"
        private const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)

        Log.d(TAG, "onDeleted llamado para widgets: ${appWidgetIds.joinToString()}")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()

        var remainingWidgets = 0

        for (widgetId in appWidgetIds) {
            Log.d(TAG, "Limpiando datos del widget $widgetId")

            // Eliminar todos los datos asociados a este widget
            editor.remove("widget_device_$widgetId")
            editor.remove("widget_nickname_$widgetId")
            editor.remove("widget_is_control_$widgetId")
            editor.remove("widget_online_$widgetId")
            editor.remove("widget_status_$widgetId")
            editor.remove("widget_pc_$widgetId")
            editor.remove("widget_sn_$widgetId")
            editor.remove("widget_is_pin_$widgetId")
            editor.remove("widget_pin_index_$widgetId")
            editor.remove("widget_temperature_$widgetId")
            editor.remove("widget_alert_$widgetId")
            editor.remove("widget_ppmCO_$widgetId")
            editor.remove("widget_ppmCH4_$widgetId")
            editor.remove("widget_loading_$widgetId")
            editor.remove("widget_initializing_$widgetId")
            editor.remove("widget_is_display_type_$widgetId")
            editor.remove("widget_display_temp_$widgetId")
            editor.remove("widget_display_alert_$widgetId")

            // Actualizar la lista de widgets activos
            val widgetIdsJson = prefs.getString("active_widget_ids", null)
            if (widgetIdsJson != null) {
                try {
                    val jsonArray = JSONArray(widgetIdsJson)
                    val newArray = JSONArray()

                    for (i in 0 until jsonArray.length()) {
                        val id = jsonArray.getInt(i)
                        if (id != widgetId) {
                            newArray.put(id)
                        }
                    }
                    editor.putString("active_widget_ids", newArray.toString())
                    remainingWidgets = newArray.length()
                    if (newArray.length() == 0) {
                        editor.putBoolean("widgetServiceEnabled", false)
                        editor.putBoolean("widget_service_ready", false)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error actualizando lista de widgets: ${e.message}")
                }
            }
        }
        editor.apply()

        // Notificar al servicio de Flutter para que verifique si debe detenerse
        Log.d(TAG, "Widgets restantes: $remainingWidgets, notificando al servicio Flutter")
        try {
            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("caldensmart://widget/checkAndStop")
            )
            backgroundIntent.send()
        } catch (e: Exception) {
            Log.e(TAG, "Error notificando al servicio Flutter: ${e.message}")
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            // Leer datos
            val nickname = widgetData.getString("widget_nickname_$widgetId", null) ?: ""
            val isControl = widgetData.getBoolean("widget_is_control_$widgetId", true)
            val isOnline = widgetData.getBoolean("widget_online_$widgetId", false)
            val isOn = widgetData.getBoolean("widget_status_$widgetId", false)
            val isLoading = widgetData.getBoolean("widget_loading_$widgetId", false)
            val isInitializing = widgetData.getBoolean("widget_initializing_$widgetId", false)
            val isServiceReady = widgetData.getBoolean("widget_service_ready", false)

            views.setViewVisibility(R.id.widget_loading_background, if (isLoading || isInitializing) android.view.View.VISIBLE else android.view.View.GONE)

            // Datos específicos
            val productCode = widgetData.getString("widget_pc_$widgetId", null)
            val displayTemp = widgetData.getString("widget_display_temp_$widgetId", null)
            val displayAlert = widgetData.getBoolean("widget_display_alert_$widgetId", false)
            val isDisplayType = widgetData.getBoolean("widget_is_display_type_$widgetId", false)

            // 1. Overlay de carga
            if (isLoading) {
                views.setViewVisibility(R.id.widget_loading_background, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_loading_background, android.view.View.GONE)
            }

            // 2. Lógica Principal
            if (nickname.isNotEmpty()) {

                views.setTextViewText(R.id.widget_device_name, nickname)

                if (isOnline) {
                    views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_online)
                } else {
                    views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_offline)
                }

                if (isControl) {
                    views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                    views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)
                    views.setInt(R.id.widget_status_icon, "setColorFilter", 0)

                    if (!isServiceReady && isOnline) {
                        views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                        views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                        views.setTextViewText(R.id.widget_power_indicator, "Iniciando...")
                        views.setTextColor(R.id.widget_power_indicator, 0xFF9E9E9E.toInt())
                        views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                    } else if (isOn) {
                        views.setImageViewResource(R.id.widget_status_icon, R.drawable.ic_switch_on)
                        views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_on)

                        if (isOnline && !isLoading && isServiceReady) {
                            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId")
                            )
                            views.setOnClickPendingIntent(R.id.widget_container, backgroundIntent)
                        } else {
                            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                        }
                    } else {
                        views.setImageViewResource(R.id.widget_status_icon, R.drawable.ic_switch_off)

                        if (isOnline) {
                            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                        } else {
                            views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }

                        if (isOnline && !isLoading && isServiceReady) {
                            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("caldensmart://widget/toggle?widgetId=$widgetId")
                            )
                            views.setOnClickPendingIntent(R.id.widget_container, backgroundIntent)
                        } else {
                            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                        }
                    }
                } else {
                    views.setViewVisibility(R.id.widget_power_indicator, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)

                    when {
                        productCode == "023430_IOT" -> {
                            val tempText = if (displayTemp != null) "${displayTemp}°C" else "--°C"
                            views.setTextViewText(R.id.widget_power_indicator, tempText)
                            views.setTextColor(R.id.widget_power_indicator, 0xFF2196F3.toInt())

                            if (isOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                            else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }

                        productCode == "015773_IOT" -> {
                            views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                            views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)

                            if (displayAlert) {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFFF44336.toInt())
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_alert)
                            } else {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                                if (isOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                                else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                            }
                        }
                        isDisplayType -> {
                            views.setViewVisibility(R.id.widget_power_indicator, android.view.View.GONE)
                            views.setViewVisibility(R.id.widget_status_icon, android.view.View.VISIBLE)

                            if (displayAlert) {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFFF44336.toInt())
                                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_alert)
                            } else {
                                views.setInt(R.id.widget_status_icon, "setColorFilter", 0xFF9E9E9E.toInt())
                                if (isOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                                else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                            }
                        }
                        else -> {
                            views.setTextViewText(R.id.widget_power_indicator, "")
                            if (isOnline) views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_off)
                            else views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_offline)
                        }
                    }
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
            } else {
                views.setTextViewText(R.id.widget_device_name, "CaldenSmart")

                views.setImageViewResource(R.id.widget_connection_icon, R.drawable.ic_widget_settings)

                views.setTextViewText(R.id.widget_power_indicator, "")
                views.setViewVisibility(R.id.widget_status_icon, android.view.View.GONE)
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_configuring)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}